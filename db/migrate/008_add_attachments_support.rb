class AddAttachmentsSupport < ActiveRecord::Migration[6.0]
  def change
    # Make sure the attachments table has the right columns for our container type
    unless column_exists?(:attachments, :container_type)
      add_column :attachments, :container_type, :string, limit: 30
      add_index :attachments, [:container_id, :container_type]
    end
    
    # Make sure the appropriate indexes exist for performance
    unless index_exists?(:attachments, [:container_id, :container_type])
      add_index :attachments, [:container_id, :container_type]
    end
  end
end