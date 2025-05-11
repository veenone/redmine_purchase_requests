require_dependency 'settings_controller'

module SettingsControllerPatch
  def self.included(base)
    base.class_eval do
      helper :purchase_request_settings
      
      # Add a before_action to process plugin settings before saving
      before_action :process_purchase_requests_settings, only: [:plugin], if: -> { params[:id] == 'redmine_purchase_requests' && request.post? }
      
      # Process purchase requests plugin settings to handle exchange_rates properly
      def process_purchase_requests_settings
        if params[:settings] && params[:settings][:exchange_rates].is_a?(Hash)
          # Convert exchange_rates from a nested hash to a flat hash
          # This prevents the "expected Array (got Rack::QueryParser::Params)" error
          rates = params[:settings][:exchange_rates].to_h
          params[:settings][:exchange_rates] = rates
        end
      end
    end
  end
end

SettingsController.include SettingsControllerPatch