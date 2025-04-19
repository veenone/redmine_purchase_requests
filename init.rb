# redmine_purchase_requests/redmine_purchase_requests/init.rb

Redmine::Plugin.register :redmine_purchase_requests do
  name 'Redmine Purchase Requests plugin'
  author 'Your Name'
  description 'A plugin for managing purchase requests in Redmine'
  version '0.1.0'
  url 'https://github.com/yourusername/redmine_purchase_requests'
  author_url 'https://github.com/yourusername'
  
  # Add permission
  project_module :purchase_requests do
    permission :view_purchase_requests, { purchase_requests: [:index, :show] }
    permission :add_purchase_requests, { purchase_requests: [:new, :create] }
    permission :edit_purchase_requests, { purchase_requests: [:edit, :update] }
    permission :delete_purchase_requests, { purchase_requests: [:destroy] }
    permission :manage_purchase_request_settings, { purchase_request_settings: [:index] }
  end
  
  # Add menu item
  menu :project_menu, :purchase_requests, 
       { controller: 'purchase_requests', action: 'index' },
       caption: :label_purchase_requests, after: :issues, param: :project_id
  
  # Add settings page
  settings default: {
    'default_status_id' => '',
    'enable_notifications' => '1',
    'default_assigned_to_id' => ''
  }, partial: 'settings/purchase_request_settings'
end

# Ensure required directories exist
Rails.application.config.to_prepare do
  # Create lib directory structure if it doesn't exist
  lib_dir = File.join(File.dirname(__FILE__), 'lib')
  hooks_dir = File.join(lib_dir, 'redmine_purchase_requests')
  
  # Create directories if they don't exist
  [lib_dir, hooks_dir].each do |dir|
    Dir.mkdir(dir) unless File.directory?(dir)
  end
  
  # Create empty hooks file if it doesn't exist
  hooks_file = File.join(hooks_dir, 'hooks.rb')
  unless File.exist?(hooks_file)
    File.open(hooks_file, 'w') do |f|
      f.write("module RedminePurchaseRequests\n  class Hooks < Redmine::Hook::ViewListener\n    # Define hooks here\n  end\nend")
    end
  end
  
  # Create empty patches file if it doesn't exist
  patches_dir = File.join(hooks_dir, 'patches')
  Dir.mkdir(patches_dir) unless File.directory?(patches_dir)
  
  models_patch_file = File.join(patches_dir, 'models_patch.rb')
  unless File.exist?(models_patch_file)
    File.open(models_patch_file, 'w') do |f|
      f.write("module RedminePurchaseRequests\n  module Patches\n    # Define model patches here\n  end\nend")
    end
  end
  
  # Now that we've ensured the files exist, require them
  require_dependency 'redmine_purchase_requests/hooks'
  require_dependency 'redmine_purchase_requests/patches/models_patch'
  
  # Add DHL API client if implementing that feature
  dhl_file = File.join(hooks_dir, 'dhl_api_client.rb')
  unless File.exist?(dhl_file)
    File.open(dhl_file, 'w') do |f|
      f.write("module RedminePurchaseRequests\n  class DhlApiClient\n    # DHL API implementation will go here\n  end\nend")
    end
  end
  
  require_dependency 'redmine_purchase_requests/dhl_api_client'
  require_dependency 'settings_controller_patch'
end

