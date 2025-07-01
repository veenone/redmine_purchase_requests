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
      # Handle OPEX category management
      if params[:opex_category]
        category = OpexCategory.new(name: params[:opex_category][:name])
        if category.save
          flash[:notice] = l(:notice_successful_create)
        else
          flash[:error] = category.errors.full_messages.join(', ')
        end
        redirect_to plugin_settings_path('redmine_purchase_requests', tab: 'opex_categories')
        return
      end
      
      # Handle OPEX category deletion
      if params[:delete_category]
        category = OpexCategory.find(params[:delete_category])
        if category.destroy
          flash[:notice] = l(:notice_successful_delete)
        else
          flash[:error] = category.errors.full_messages.join(', ')
        end
        redirect_to plugin_settings_path('redmine_purchase_requests', tab: 'opex_categories')
        return
      end
      
      # Process exchange rates from individual fields to a hash
      exchange_rates = {}
      capex_exchange_rates = {}
      year_specific_rates = {}
      keys_to_delete = []
      
      # Extract exchange rates from individual parameters
      params[:settings].each do |key, value|
        if key.to_s.start_with?('exchange_rate_')
          currency = key.to_s.sub('exchange_rate_', '')
          exchange_rates[currency] = value.to_s.presence
          keys_to_delete << key
        elsif key.to_s.start_with?('capex_exchange_rate_')
          # Handle both regular and year-specific CAPEX rates
          if key.to_s.match(/^capex_exchange_rate_(\d{4})_(.+)$/)
            # Year-specific rate: capex_exchange_rate_2024_USD
            year = $1
            currency = $2
            year_key = "capex_exchange_rates_#{year}"
            year_specific_rates[year_key] ||= {}
            year_specific_rates[year_key][currency] = value.to_s.presence
          else
            # Regular CAPEX rate: capex_exchange_rate_USD
            currency = key.to_s.sub('capex_exchange_rate_', '')
            capex_exchange_rates[currency] = value.to_s.presence
          end
          keys_to_delete << key
        end
      end
      
      # Add the processed rates to settings
      params[:settings][:exchange_rates] = exchange_rates
      params[:settings][:capex_exchange_rates] = capex_exchange_rates
      year_specific_rates.each do |year_key, rates|
        params[:settings][year_key] = rates
      end
      
      # Clean up the individual exchange rate parameters after iteration
      keys_to_delete.each do |key|
        params[:settings].delete(key)
      end
    end
    
    plugin_without_purchase_requests
  end
end

# Include the patch in the SettingsController
unless SettingsController.included_modules.include?(SettingsControllerPatch)
  SettingsController.include(SettingsControllerPatch)
end