# File: lib/settings_controller_patch.rb

require_dependency 'settings_controller'

module SettingsControllerPatch
  def self.included(base)
    base.class_eval do
      alias_method :plugin_without_purchase_requests, :plugin
      alias_method :plugin, :plugin_with_purchase_requests
    end
  end

  def plugin_with_purchase_requests
    if params[:id] == 'redmine_purchase_requests' && request.post? && params[:settings]
      # Process exchange rates from individual fields to a hash
      exchange_rates = {}
      
      # Extract exchange rates from individual parameters
      params[:settings].each do |key, value|
        if key.to_s.start_with?('exchange_rate_')
          currency = key.to_s.sub('exchange_rate_', '')
          exchange_rates[currency] = value.to_s.presence
        end
      end
      
      # Replace the exchange_rates param with our properly formatted hash
      params[:settings][:exchange_rates] = exchange_rates
      
      # Clean up the individual exchange rate parameters
      params[:settings].keys.each do |key|
        params[:settings].delete(key) if key.to_s.start_with?('exchange_rate_')
      end
    end
    
    plugin_without_purchase_requests
  end
end

# Include the patch in the SettingsController
unless SettingsController.included_modules.include?(SettingsControllerPatch)
  SettingsController.include(SettingsControllerPatch)
end