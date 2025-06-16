module RedminePurchaseRequests
  module Patches
    module ProjectPatch
      def self.included(base)
        base.class_eval do
          has_many :purchase_requests, dependent: :destroy
          has_many :capex, dependent: :destroy
          
          # Add safe navigation method for CAPEX
          def capex_entries
            capex
          end
        end
      end
    end
  end
end

# Apply the patches with logging
begin
  unless Project.included_modules.include?(RedminePurchaseRequests::Patches::ProjectPatch)
    Project.include RedminePurchaseRequests::Patches::ProjectPatch
    Rails.logger.info "Successfully applied RedminePurchaseRequests::Patches::ProjectPatch" if defined?(Rails) && Rails.logger
  end
rescue => e
  Rails.logger.error "Failed to apply ProjectPatch: #{e.message}" if defined?(Rails) && Rails.logger
  puts "Failed to apply ProjectPatch: #{e.message}"
end