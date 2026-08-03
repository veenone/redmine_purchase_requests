module PurchaseRequestsHelper
  # Helper methods for purchase requests

  # Single source-of-truth for currency code → symbol mapping.
  # Both the Ruby helpers and the JS form preview read from here.
  CURRENCY_SYMBOLS = {
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
  }.freeze

  def format_request_date(date)
    date.strftime("%B %d, %Y") if date
  end

  def request_status_label(status)
    case status
    when 'pending'
      content_tag(:span, status.humanize, class: 'label label-warning')
    when 'approved'
      content_tag(:span, status.humanize, class: 'label label-success')
    when 'rejected'
      content_tag(:span, status.humanize, class: 'label label-danger')
    else
      content_tag(:span, status.humanize, class: 'label label-default')
    end
  end

  def purchase_request_link(request)
    link_to(request.title, purchase_request_path(request))
  end

  def currency_symbol(currency_code)
    CURRENCY_SYMBOLS[currency_code] || currency_code
  end

  # Class method version for use in models / outside view context
  def self.currency_symbol(currency_code)
    CURRENCY_SYMBOLS[currency_code] || currency_code
  end

  def enabled_currencies_for_select
    enabled_currencies = Setting.plugin_redmine_purchase_requests['enabled_currencies']

    # Handle different formats of the enabled_currencies setting
    if enabled_currencies.blank?
      # Default to USD if no currencies are enabled
      return [["US Dollar ($)", "USD"]]
    end

    # Convert to array if it's a string
    enabled_currencies = enabled_currencies.split(',') if enabled_currencies.is_a?(String)

    # Map currency codes to display names with symbols
    currency_map = {
      'USD' => 'US Dollar ($)',
      'EUR' => 'Euro (€)',
      'GBP' => 'British Pound (£)',
      'JPY' => 'Japanese Yen (¥)',
      'CAD' => 'Canadian Dollar (C$)',
      'AUD' => 'Australian Dollar (A$)',
      'CHF' => 'Swiss Franc (CHF)',
      'CNY' => 'Chinese Yuan (¥)',
      'SEK' => 'Swedish Krona (kr)',
      'NZD' => 'New Zealand Dollar (NZ$)',
      'MXN' => 'Mexican Peso (Mex$)',
      'SGD' => 'Singapore Dollar (S$)',
      'HKD' => 'Hong Kong Dollar (HK$)',
      'IDR' => 'Indonesian Rupiah (Rp)',
      'NOK' => 'Norwegian Krone (kr)',
      'KRW' => 'South Korean Won (₩)',
      'TRY' => 'Turkish Lira (₺)',
      'RUB' => 'Russian Ruble (₽)',
      'INR' => 'Indian Rupee (₹)',
      'BRL' => 'Brazilian Real (R$)',
      'ZAR' => 'South African Rand (R)'
    }

    # Create options array for select dropdown
    enabled_currencies.map do |code|
      [currency_map[code] || code, code]
    end
  end

  # Convert an amount from one currency to another using exchange rates
  def convert_currency(amount, from_currency, to_currency = nil)
    return amount if amount.nil? || from_currency.nil?

    # Get default currency if to_currency is not specified
    to_currency ||= Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'

    # If currencies are the same, no conversion needed
    return amount if from_currency == to_currency

    # Get exchange rates from settings
    exchange_rates = Setting.plugin_redmine_purchase_requests['exchange_rates'] || {}

    # Convert from source currency to default currency
    if from_currency != to_currency
      # Get exchange rate from settings (default to 1.0 if not found)
      rate = exchange_rates[from_currency].to_f
      rate = 1.0 if rate <= 0  # Safety check

      # Convert price using exchange rate
      # The rate is defined as: 1 from_currency = X to_currency
      # So we divide by the rate to convert
      converted_amount = amount / rate
      return converted_amount.round(2)
    end

    # If we got here, just return the original amount
    amount
  end

  # Format a price with currency symbol
  def format_price(amount, currency = nil)
    return "-" if amount.nil?

    # Default currency if not specified
    currency ||= Setting.plugin_redmine_purchase_requests['default_currency'] || 'USD'

    # Format the amount with the currency symbol
    "#{currency_symbol(currency)}#{number_with_precision(amount, precision: 2, delimiter: ',')}"
  end

  # Get all available currencies for select field
  def available_currencies
    [
      ['US Dollar ($)', 'USD'],
      ['Euro (€)', 'EUR'],
      ['British Pound (£)', 'GBP'],
      ['Japanese Yen (¥)', 'JPY'],
      ['Canadian Dollar (C$)', 'CAD'],
      ['Australian Dollar (A$)', 'AUD'],
      ['Swiss Franc (CHF)', 'CHF'],
      ['Chinese Yuan (¥)', 'CNY'],
      ['Swedish Krona (kr)', 'SEK'],
      ['New Zealand Dollar (NZ$)', 'NZD'],
      ['Mexican Peso (Mex$)', 'MXN'],
      ['Singapore Dollar (S$)', 'SGD'],
      ['Hong Kong Dollar (HK$)', 'HKD'],
      ['Indonesian Rupiah (Rp)', 'IDR'],
      ['Norwegian Krone (kr)', 'NOK'],
      ['South Korean Won (₩)', 'KRW'],
      ['Turkish Lira (₺)', 'TRY'],
      ['Russian Ruble (₽)', 'RUB'],
      ['Indian Rupee (₹)', 'INR'],
      ['Brazilian Real (R$)', 'BRL'],
      ['South African Rand (R)', 'ZAR']
    ]
  end

  # Get enabled currencies for select fields in forms
  def enabled_currencies_for_select
    # Get enabled currencies from settings
    enabled_list = Setting.plugin_redmine_purchase_requests['enabled_currencies']

    # If no currencies are enabled, default to USD
    return [['US Dollar ($)', 'USD']] if enabled_list.blank?

    # Convert to array if it's a string
    if enabled_list.is_a?(String)
      enabled_list = enabled_list.split(',')
    end

    # Filter available currencies to only include enabled ones
    available_currencies.select { |currency| enabled_list.include?(currency[1]) }
  end

  # Alias for backward compatibility — delegates to currency_symbol
  def get_currency_symbol(currency_code)
    currency_symbol(currency_code)
  end

  # Returns a legible foreground color ('#111827' or '#ffffff') for any hex
  # background using the WCAG relative-luminance formula.
  # Handles 3-digit hex (#rgb → #rrggbb), 6-digit hex, nil/blank input.
  # Returns dark text when luminance > 0.5 (light background), white otherwise.
  def readable_text_color(hex)
    return '#111827' if hex.blank?

    hex = hex.to_s.strip.delete_prefix('#')

    # Expand 3-digit shorthand to 6 digits
    hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3

    return '#111827' unless hex.length == 6

    r_int = hex[0, 2].to_i(16)
    g_int = hex[2, 2].to_i(16)
    b_int = hex[4, 2].to_i(16)

    # sRGB linearisation per WCAG 2.1 §1.4.3
    linearize = lambda do |c|
      s = c / 255.0
      s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055)**2.4
    end

    r = linearize.call(r_int)
    g = linearize.call(g_int)
    b = linearize.call(b_int)

    luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b

    luminance > 0.5 ? '#111827' : '#ffffff'
  end
end
