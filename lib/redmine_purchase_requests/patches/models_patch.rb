module RedminePurchaseRequests
  module Patches
    module ModelsPatch
      # Add purchase_requests association to the Project model
      module ProjectPatch
        def self.included(base)
          base.class_eval do
            has_many :purchase_requests, dependent: :destroy
          end
        end
      end
    end
  end
end

# Apply the patch to Project model
unless Project.included_modules.include?(RedminePurchaseRequests::Patches::ModelsPatch::ProjectPatch)
  Project.send(:include, RedminePurchaseRequests::Patches::ModelsPatch::ProjectPatch)
end