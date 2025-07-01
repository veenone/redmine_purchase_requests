# File: app/helpers/purchase_request_settings_helper.rb

module PurchaseRequestSettingsHelper
  def purchase_request_settings_tabs
    [
      {name: 'general', partial: 'settings/purchase_request_general', label: :label_general},
      {name: 'statuses', partial: 'settings/purchase_request_statuses', label: :label_purchase_request_statuses},
      {name: 'currency', partial: 'settings/purchase_request_currency', label: :label_currency_settings},
      {name: 'vendors', partial: 'settings/purchase_request_vendors', label: :label_vendor_settings},
      {name: 'capex', partial: 'settings/purchase_request_capex', label: :label_capex_settings},
      {name: 'opex_categories', partial: 'settings/purchase_request_opex_categories', label: :label_opex_category_settings}
    ]
  end
  
  def currency_options
    enabled_currencies = Setting.plugin_redmine_purchase_requests['enabled_currencies']
    return [] if enabled_currencies.blank?
    
    # Convert to array if it's a string
    enabled_currencies = enabled_currencies.split(',') if enabled_currencies.is_a?(String)
    
    # Map currency codes to display names with symbols
    currency_map = {
      'USD' => ['US Dollar ($)', '$'],
      'EUR' => ['Euro (€)', '€'],
      'GBP' => ['British Pound (£)', '£'],
      'JPY' => ['Japanese Yen (¥)', '¥'],
      'CAD' => ['Canadian Dollar (C$)', 'C$'],
      'AUD' => ['Australian Dollar (A$)', 'A$'],
      'CHF' => ['Swiss Franc (CHF)', 'CHF'],
      'CNY' => ['Chinese Yuan (¥)', '¥'],
      'SEK' => ['Swedish Krona (kr)', 'kr'],
      'NZD' => ['New Zealand Dollar (NZ$)', 'NZ$'],
      'MXN' => ['Mexican Peso (Mex$)', 'Mex$'],
      'SGD' => ['Singapore Dollar (S$)', 'S$'],
      'HKD' => ['Hong Kong Dollar (HK$)', 'HK$'],
      'IDR' => ['Indonesian Rupiah (Rp)', 'Rp'],
      'NOK' => ['Norwegian Krone (kr)', 'kr'],
      'KRW' => ['South Korean Won (₩)', '₩'],
      'TRY' => ['Turkish Lira (₺)', '₺'],
      'RUB' => ['Russian Ruble (₽)', '₽'],
      'INR' => ['Indian Rupee (₹)', '₹'],
      'BRL' => ['Brazilian Real (R$)', 'R$'],
      'ZAR' => ['South African Rand (R)', 'R']
    }
    
    # Create options array for select dropdown
    enabled_currencies.map do |code|
      currency_info = currency_map[code] || [code, code]
      [currency_info[0], code, {'data-symbol' => currency_info[1]}]
    end
  end
  
  def currency_symbol(currency_code)
    symbol_map = {
      'USD' => '$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      'CAD' => 'C$',
      'AUD' => 'A$',
      'CHF' => 'CHF',
      'CNY' => '¥',
      'SEK' => 'kr',
      'NZD' => 'NZ$',
      'MXN' => 'Mex$',
      'SGD' => 'S$',
      'HKD' => 'HK$',
      'NOK' => 'kr',
      'KRW' => '₩',
      'TRY' => '₺',
      'RUB' => '₽',
      'INR' => '₹',
      'BRL' => 'R$',
      'ZAR' => 'R'
    }
    
    symbol_map[currency_code] || currency_code
  end
end