module CapexHelper
  # Convert CAPEX amount from one currency to another using year-specific exchange rates
  def convert_capex_currency(amount, from_currency, to_currency = nil, year = nil)
    return amount if amount.nil? || from_currency.nil?
    
    # Get default currency if to_currency is not specified
    to_currency ||= Setting.plugin_redmine_purchase_requests['default_capex_currency'] || 
                   Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
    
    # If currencies are the same, no conversion needed
    return amount if from_currency == to_currency
    
    # Get current year if not specified
    year ||= Date.current.year
    
    # Get year-specific CAPEX exchange rates from settings, fallback to general rates
    year_specific_rates = Setting.plugin_redmine_purchase_requests["capex_exchange_rates_#{year}"] || {}
    capex_exchange_rates = Setting.plugin_redmine_purchase_requests['capex_exchange_rates'] || {}
    general_exchange_rates = Setting.plugin_redmine_purchase_requests['exchange_rates'] || {}
    
    # Convert from source currency to target currency
    if from_currency != to_currency
      # Get exchange rate (year-specific first, then CAPEX-specific, then general)
      rate = year_specific_rates[from_currency].to_f
      rate = capex_exchange_rates[from_currency].to_f if rate <= 0
      rate = general_exchange_rates[from_currency].to_f if rate <= 0
      rate = 1.0 if rate <= 0  # Safety check
      
      # Convert price using exchange rate
      # The rate is defined as: 1 from_currency = rate to_currency
      # So we divide by the rate to convert
      converted_amount = amount / rate
      return converted_amount.round(2)
    end
    
    # If we got here, just return the original amount
    amount
  end
  
  # Get currency symbol for CAPEX amounts
  def capex_currency_symbol(currency_code)
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
      'IDR' => 'Rp',
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
  
  # Format CAPEX price with currency symbol
  def format_capex_price(amount, currency = nil)
    return "-" if amount.nil?
    
    # Default currency if not specified
    currency ||= Setting.plugin_redmine_purchase_requests['default_capex_currency'] || 'USD'
    
    # Get the currency symbol
    symbol = capex_currency_symbol(currency)
    
    # Format the amount with the currency symbol
    "#{symbol}#{number_with_precision(amount, precision: 2, delimiter: ',')}"
  end
  
  # Check if CAPEX should use exchange rates
  def capex_use_exchange_rates?
    Setting.plugin_redmine_purchase_requests['capex_use_exchange_rates'] == '1'
  end
  
  # Get default CAPEX currency
  def default_capex_currency
    Setting.plugin_redmine_purchase_requests['default_capex_currency'] || 
    Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'
  end
end
