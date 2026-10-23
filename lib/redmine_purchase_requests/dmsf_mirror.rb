module RedminePurchaseRequests
  # Copies purchase request attachments into DMSF, when DMSF is installed and
  # enabled on the request's project, under
  #
  #   Purchase Requests / PR-<id> <title> / <file>
  #
  # The Redmine attachment stays where it is: the request page and the Files
  # tab keep serving it, and DMSF gets a copy so the documents also live in
  # the DMS. A file already present in the request's folder (same name) is
  # skipped, so running this after every save also backfills attachments
  # added before DMSF was enabled. Deleting an attachment leaves its DMSF copy.
  #
  # File and revision are built the way DMSF's own dmsf_convert_documents
  # task builds them from an Attachment.
  module DmsfMirror
    ROOT_TITLE = 'Purchase Requests'.freeze

    def self.enabled_for?(project)
      Redmine::Plugin.installed?(:redmine_dmsf) && project.present? && project.module_enabled?(:dmsf)
    end

    def self.sync(purchase_request)
      project = purchase_request.project
      return unless enabled_for?(project)

      attachments = purchase_request.attachments.to_a
      return if attachments.empty?

      folder = folder_for(purchase_request)
      existing = DmsfFile.visible.where(project_id: project.id, dmsf_folder_id: folder.id).pluck(:name)
      attachments.each do |attachment|
        name = DmsfFolder.get_valid_title(attachment.filename)
        next if existing.include?(name) || !File.exist?(attachment.diskfile)

        copy(attachment, name, purchase_request, folder)
        existing << name
      end
    rescue StandardError => e
      # The request and its Redmine attachments are already saved. A failed
      # DMS copy must not turn that into an error page.
      Rails.logger.error "[purchase_requests] DMSF copy for request ##{purchase_request.id} failed: #{e.class}: #{e.message}"
    end

    # The request's folder is found by its "PR-<id> " prefix, so renaming the
    # request keeps using the folder it already has.
    def self.folder_for(purchase_request)
      project = purchase_request.project
      root = active_folders(project, nil).find_by(title: ROOT_TITLE) ||
             DmsfFolder.create!(project: project, title: ROOT_TITLE, user: purchase_request.user)
      prefix = "PR-#{purchase_request.id} "
      active_folders(project, root).where('title LIKE ?', "#{prefix}%").first ||
        DmsfFolder.create!(project: project, dmsf_folder: root, user: purchase_request.user,
                           title: DmsfFolder.get_valid_title("#{prefix}#{purchase_request.title}".truncate(255)))
    end

    def self.active_folders(project, parent)
      DmsfFolder.where(project_id: project.id, dmsf_folder_id: parent&.id, deleted: DmsfFolder::STATUS_ACTIVE)
    end

    def self.copy(attachment, name, purchase_request, folder)
      DmsfFile.transaction do
        file = DmsfFile.create!(project_id: folder.project_id, dmsf_folder: folder, name: name)
        revision = DmsfFileRevision.new(
          dmsf_file: file,
          name: name,
          title: DmsfFileRevision.filename_to_title(name),
          description: attachment.description.to_s.truncate(1024),
          user: attachment.author || purchase_request.user,
          major_version: 0,
          minor_version: 1,
          comment: "Attached to purchase request ##{purchase_request.id}",
          mime_type: attachment.content_type
        )
        revision.disk_filename = revision.new_storage_filename
        target = revision.disk_file(search_if_not_exists: false)
        FileUtils.cp(attachment.diskfile, target)
        revision.size = File.size(target)
        revision.save!
      end
    end
  end
end
