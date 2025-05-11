# File: lib/settings_controller_patch.rb

require_dependency 'settings_controller'

module SettingsControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method :plugin_without_purchase_requests, :plugin
      alias_method :plugin, :plugin_with_purchase_requests
      
      # Include helper
      helper :purchase_request_settings
    end
  end

  module InstanceMethods
    def plugin_with_purchase_requests
      # Set the tab if this is our plugin
      if params[:id] == 'redmine_purchase_requests' 
        @tab = params[:tab] || 'general'
        
        # Handle saving exchange rates
        if request.post? && params[:settings]
          # Process the flat exchange rate parameters and convert to a hash
          exchange_rates = {}
          
          # Extract exchange rates from individual parameters
          params[:settings].each do |key, value|
            if key.to_s.start_with?('exchange_rate_')
              # Extract currency code from parameter name
              currency = key.to_s.sub('exchange_rate_', '')
              exchange_rates[currency] = value if !value.blank?
            end
          end
          
          # Add the exchange_rates hash to the settings
          params[:settings][:exchange_rates] = exchange_rates
          
          # Remove the individual exchange_rate_XXX parameters to avoid confusion
          params[:settings].each do |key, value|
            params[:settings].delete(key) if key.to_s.start_with?('exchange_rate_')
          end
        end
      end
      
      # Call the original method
      plugin_without_purchase_requests
    end
  end
end

# Apply the patch
SettingsController.include SettingsControllerPatch unless SettingsController.included_modules.include? SettingsControllerPatch