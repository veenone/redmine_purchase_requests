module RedminePurchaseRequests
  module Patches
    module ApplicationHelperPatch
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        # Add any class methods here if needed
      end
      
      # Add instance methods here if needed
      # Example: currency conversion helpers, formatting methods, etc.
    end
  end
end

# Apply the patch
unless ApplicationHelper.included_modules.include?(RedminePurchaseRequests::Patches::ApplicationHelperPatch)
  ApplicationHelper.include RedminePurchaseRequests::Patches::ApplicationHelperPatch
end
