module PurchaseRequestSettingsHelper
  def purchase_request_settings_tabs
    [
      {name: 'general', partial: 'settings/purchase_request_general', label: :label_general},
      {name: 'statuses', partial: 'settings/purchase_request_statuses', label: :label_purchase_request_statuses}
    ]
  end
end