# File: lib/application_helper_patch.rb

require_dependency 'application_helper'

module ApplicationHelperPatch
  def self.included(base)
    base.send(:include, PurchaseRequestSettingsHelper)
  end
end

# Apply the patch
ApplicationHelper.include ApplicationHelperPatch unless ApplicationHelper.included_modules.include? ApplicationHelperPatch