module RedminePurchaseRequests
  module Patches
    module SettingsControllerPatch
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        # Add any class methods here if needed
      end
      
      # Add instance methods here if needed
    end
  end
end

# Apply the patch
unless SettingsController.included_modules.include?(RedminePurchaseRequests::Patches::SettingsControllerPatch)
  SettingsController.include RedminePurchaseRequests::Patches::SettingsControllerPatch
end