module RedminePurchaseRequests
  module Patches
    module UserPatch
      def self.included(base)
        base.class_eval do
          has_many :purchase_requests, foreign_key: 'user_id'
        end
      end
    end
  end
end

# Apply the patch
User.include RedminePurchaseRequests::Patches::UserPatch unless User.included_modules.include? RedminePurchaseRequests::Patches::UserPatch