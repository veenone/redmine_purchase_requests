# redmine_purchase_requests/init.rb

Redmine::Plugin.register :redmine_purchase_requests do
  name 'Redmine Purchase Requests plugin'
  author 'Achmad Fienan Rahardianto'
  description 'A plugin for managing purchase requests in Redmine'
  version '0.0.6' # Increment version number
  url 'https://github.com/veenone/redmine_purchase_requests'
  author_url 'https://github.com/veenone'
  
  # Add permissions
  project_module :purchase_requests do
    permission :view_purchase_requests, { purchase_requests: [:index, :show] }
    permission :add_purchase_requests, { purchase_requests: [:new, :create] }
    permission :edit_purchase_requests, { purchase_requests: [:edit, :update] }
    permission :delete_purchase_requests, { purchase_requests: [:destroy] }
    permission :manage_purchase_request_settings, { purchase_request_settings: [:index] }
    permission :view_purchase_request_dashboard, { purchase_requests: [:dashboard] }
  end
  
  # Add menu items
  menu :project_menu, :purchase_requests, 
       { controller: 'purchase_requests', action: 'index' },
       caption: :label_purchase_requests, after: :issues, param: :project_id

  menu :project_menu, :purchase_requests_dashboard, 
       { controller: 'purchase_requests', action: 'dashboard' },
       caption: :label_purchase_request_dashboard, after: :purchase_requests
  
  # Add settings page with empty exchange_rates hash
  settings default: {
    'default_status_id' => '',
    'enable_notifications' => '1',
    'default_assigned_to_id' => '',
    'default_currency' => 'USD',
    'enabled_currencies' => ['USD', 'EUR', 'GBP', 'IDR'],
    'show_exchange_rates' => '0',
    'exchange_rates' => {}  # Initialize exchange_rates as an empty hash
  }, partial: 'settings/purchase_request_settings'
end

# Load plugin components
Rails.application.config.to_prepare do
  # Load helpers
  require_dependency 'purchase_request_settings_helper'
  require_dependency 'purchase_requests_helper'
  
  # Create directory structure if needed
  lib_dir = File.join(File.dirname(__FILE__), 'lib')
  hooks_dir = File.join(lib_dir, 'redmine_purchase_requests')
  patches_dir = File.join(hooks_dir, 'patches')
  
  [lib_dir, hooks_dir, patches_dir].each do |dir|
    Dir.mkdir(dir) unless File.directory?(dir)
  end
  
  # Load patches
  require_dependency 'application_helper_patch'
  require_dependency 'settings_controller_patch'
  
  # Load other dependencies
  require_dependency 'redmine_purchase_requests/hooks'
  require_dependency 'redmine_purchase_requests/patches/models_patch'
  require_dependency 'redmine_purchase_requests/patches/user_patch'
end