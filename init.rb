# redmine_purchase_requests/redmine_purchase_requests/init.rb

Redmine::Plugin.register :redmine_purchase_requests do
  name 'Redmine Purchase Requests plugin'
  author 'Achmad Fienan Rahardianto'
  description 'A plugin for managing purchase requests in Redmine'
  version '0.0.3'
  url 'https://github.com/veenone/redmine_purchase_requests'
  author_url 'https://github.com/veenone'
  
  # Add permission
  project_module :purchase_requests do
    permission :view_purchase_requests, { purchase_requests: [:index, :show] }
    permission :add_purchase_requests, { purchase_requests: [:new, :create] }
    permission :edit_purchase_requests, { purchase_requests: [:edit, :update] }
    permission :delete_purchase_requests, { purchase_requests: [:destroy] }
    permission :manage_purchase_request_settings, { purchase_request_settings: [:index] }
    # Add permission for dashboard
    permission :view_purchase_request_dashboard, { purchase_requests: [:dashboard] }
  end
  
  # Add menu item
  menu :project_menu, :purchase_requests, 
       { controller: 'purchase_requests', action: 'index' },
       caption: :label_purchase_requests, after: :issues, param: :project_id

  # Add dashboard to top menu
  menu :project_menu, :purchase_requests_dashboard, 
       { controller: 'purchase_requests', action: 'dashboard' },
       caption: :label_purchase_request_dashboard, after: :projects
  
  # Add settings page
  settings default: {
    'default_status_id' => '',
    'enable_notifications' => '1',
    'default_assigned_to_id' => '',
    'default_currency' => 'USD',
    'enabled_currencies' => ['USD', 'EUR', 'GBP', 'IDR'],
    'show_exchange_rates' => '0'
  }, partial: 'settings/purchase_request_settings'
end

# Ensure required directories exist
Rails.application.config.to_prepare do
  # Create lib directory structure if it doesn't exist
  lib_dir = File.join(File.dirname(__FILE__), 'lib')
  hooks_dir = File.join(lib_dir, 'redmine_purchase_requests')
  patches_dir = File.join(hooks_dir, 'patches')
  
  # Create directories if they don't exist
  [lib_dir, hooks_dir, patches_dir].each do |dir|
    Dir.mkdir(dir) unless File.directory?(dir)
  end
  
  # Create empty hooks file if it doesn't exist
  hooks_file = File.join(hooks_dir, 'hooks.rb')
  unless File.exist?(hooks_file)
    File.open(hooks_file, 'w') do |f|
      f.write("module RedminePurchaseRequests\n  class Hooks < Redmine::Hook::ViewListener\n    # Define hooks here\n  end\nend")
    end
  end
  
  # Create User patch file if it doesn't exist
  user_patch_file = File.join(patches_dir, 'user_patch.rb')
  unless File.exist?(user_patch_file)
    File.open(user_patch_file, 'w') do |f|
      f.write("module RedminePurchaseRequests\n  module Patches\n    module UserPatch\n      def self.included(base)\n        base.class_eval do\n          has_many :purchase_requests, foreign_key: 'user_id'\n        end\n      end\n    end\n  end\nend\n\n# Apply the patch\nUser.include RedminePurchaseRequests::Patches::UserPatch unless User.included_modules.include? RedminePurchaseRequests::Patches::UserPatch")
    end
  end
  
  # Create models patch file if it doesn't exist
  models_patch_file = File.join(patches_dir, 'models_patch.rb')
  unless File.exist?(models_patch_file)
    File.open(models_patch_file, 'w') do |f|
      f.write("module RedminePurchaseRequests\n  module Patches\n    # Define model patches here\n  end\nend")
    end
  end
  
  # Now that we've ensured the files exist, require them
  require_dependency 'redmine_purchase_requests/hooks'
  require_dependency 'redmine_purchase_requests/patches/models_patch'
  require_dependency 'redmine_purchase_requests/patches/user_patch'
  
  # Add other dependencies as needed
  require_dependency 'settings_controller_patch'
end

