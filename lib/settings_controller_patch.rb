require_dependency 'settings_controller'

module SettingsControllerPatch
  def self.included(base)
    base.class_eval do
      helper :purchase_request_settings
    end
  end
end

SettingsController.include SettingsControllerPatch