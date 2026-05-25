# redmine_purchase_requests/init.rb

# Register DOCX MIME type at plugin load time so format.docx is recognized
# by the time controllers are loaded. Doing this inside to_prepare can be
# too late under some boot orders, producing
# "To respond to a custom format, register it as a MIME type first".
_docx_registered = (Mime::Type.lookup_by_extension(:docx) rescue nil)
unless _docx_registered
  Mime::Type.register 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', :docx
end

Redmine::Plugin.register :redmine_purchase_requests do
  name 'Redmine Purchase Requests plugin'
  author 'Achmad Fienan Rahardianto'
  description 'A comprehensive plugin for managing purchase requests, CAPEX budgets, OPEX management, and vendor operations in Redmine'
  version '1.8.1'
  url 'https://github.com/veenone/redmine_purchase_requests'
  author_url 'https://github.com/veenone'
  
  # Add permissions - explicitly specify project context
  project_module :purchase_requests do
    permission :view_purchase_requests, { purchase_requests: [:index, :show] }
    permission :add_purchase_requests, { purchase_requests: [:new, :create] }
    permission :edit_purchase_requests, { purchase_requests: [:edit, :update, :create_workflow_issue] }
    permission :delete_purchase_requests, { purchase_requests: [:destroy] }
    permission :manage_purchase_request_settings, { purchase_request_settings: [:index] }
    permission :view_purchase_request_dashboard, { purchase_requests: [:dashboard] }
    permission :view_project_vendors, { project_vendors: [:index, :show] }
    permission :manage_project_vendors, { project_vendors: [:manage, :new, :create, :edit, :update, :destroy] }
    permission :view_capex, { capex: [:index, :show] }
    permission :manage_capex, { capex: [:new, :create, :edit, :update, :destroy] }
    permission :view_capex_dashboard, { capex: [:dashboard] }
    permission :view_opex, { opex: [:index, :show] }
    permission :manage_opex, { opex: [:new, :create, :edit, :update, :destroy] }
    permission :view_opex_dashboard, { opex: [:dashboard] }
    permission :view_tpc_codes, { tpc_codes: [:index, :show] }
    permission :manage_tpc_codes, { tpc_codes: [:new, :create, :edit, :update, :destroy, :import, :export, :import_export] }
    permission :view_tpc_dashboard, { tpc_codes: [:dashboard] }
    permission :view_purchase_request_reports, { reports: [:index, :purchase_requests, :vendors, :tpc_codes, :capex, :opex, :overview] }
    
    # Global permissions (outside project context but grouped under purchase_requests module)
    permission :view_global_vendors, { vendors: [:index, :show, :autocomplete] }, global: true
    permission :manage_global_vendors, { vendors: [:new, :create, :edit, :update, :destroy, :import, :export, :import_export, :import_template, :migrate_from_settings] }, global: true
    permission :view_global_tpc_codes, { tpc_codes: [:global_index, :show] }, global: true
    permission :manage_global_tpc_codes, { tpc_codes: [:global_new, :global_create, :global_edit, :global_update, :global_destroy, :global_import, :global_export, :global_import_export] }, global: true
    permission :view_purchase_request_reports, { reports: [:index, :purchase_requests, :vendors, :tpc_codes, :capex, :opex, :overview] }, global: true
  end
  
  # Procurement menu (virtual parent) - only visible when purchase_requests module is enabled
  menu :project_menu, :procurement, '#',
       caption: :label_procurement,
       after: :issues,
       param: :project_id,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) }

  menu :project_menu, :purchase_requests,
       { controller: 'purchase_requests', action: 'index' },
       caption: :label_purchase_requests,
       param: :project_id,
       parent: :procurement,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) }

  menu :project_menu, :purchase_requests_dashboard,
       { controller: 'purchase_requests', action: 'dashboard' },
       caption: :label_purchase_request_dashboard,
       param: :project_id,
       parent: :procurement,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) }

  menu :project_menu, :purchase_requests_vendors,
       { controller: 'project_vendors', action: 'index' },
       caption: :label_vendors,
       param: :project_id,
       parent: :procurement,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) }

  menu :project_menu, :purchase_request_reports,
       { controller: 'reports', action: 'index' },
       caption: :label_reports,
       param: :project_id,
       parent: :procurement,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) }

  # Budget Management menu (virtual parent - groups CAPEX, OPEX, TPC)
  # Only visible when purchase_requests module is enabled and user has relevant permissions
  menu :project_menu, :budget_management, '#',
       caption: :label_budget_management,
       after: :procurement,
       param: :project_id,
       if: Proc.new { |project|
         project.module_enabled?(:purchase_requests) &&
         (User.current.allowed_to?(:view_capex, project) ||
          User.current.allowed_to?(:view_opex, project) ||
          User.current.allowed_to?(:view_tpc_codes, project))
       }

  menu :project_menu, :capex,
       { controller: 'capex', action: 'index' },
       caption: 'CAPEX List',
       param: :project_id,
       parent: :budget_management,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) && User.current.allowed_to?(:view_capex, project) }

  menu :project_menu, :capex_dashboard,
       { controller: 'capex', action: 'dashboard' },
       caption: 'CAPEX Dashboard',
       param: :project_id,
       parent: :budget_management,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) && User.current.allowed_to?(:view_capex_dashboard, project) }

  menu :project_menu, :opex,
       { controller: 'opex', action: 'index' },
       caption: 'OPEX List',
       param: :project_id,
       parent: :budget_management,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) && User.current.allowed_to?(:view_opex, project) }

  menu :project_menu, :opex_dashboard,
       { controller: 'opex', action: 'dashboard' },
       caption: 'OPEX Dashboard',
       param: :project_id,
       parent: :budget_management,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) && User.current.allowed_to?(:view_opex_dashboard, project) }

  menu :project_menu, :tpc_codes,
       { controller: 'tpc_codes', action: 'index' },
       caption: 'TPC Codes',
       param: :project_id,
       parent: :budget_management,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) && User.current.allowed_to?(:view_tpc_codes, project) }

  menu :project_menu, :tpc_dashboard,
       { controller: 'tpc_codes', action: 'dashboard' },
       caption: 'TPC Dashboard',
       param: :project_id,
       parent: :budget_management,
       if: Proc.new { |project| project.module_enabled?(:purchase_requests) && User.current.allowed_to?(:view_tpc_dashboard, project) }
  
  # Add global TPC codes menu to top navigation (configurable via plugin settings)
  menu :top_menu, :global_tpc_codes,
       { controller: 'tpc_codes', action: 'global_index' },
       caption: 'TPC Codes',
       if: Proc.new {
         User.current.logged? &&
         Setting.plugin_redmine_purchase_requests['global_tpc_menu_enabled'] == '1' &&
         (User.current.admin? || User.current.allowed_to?(:view_global_tpc_codes, nil, global: true))
       }

  # Add TPC dashboard menu to top navigation (configurable via plugin settings)
  menu :top_menu, :global_tpc_dashboard,
       { controller: 'tpc_codes', action: 'dashboard' },
       caption: 'TPC Dashboard',
       if: Proc.new {
         User.current.logged? &&
         Setting.plugin_redmine_purchase_requests['global_tpc_dashboard_menu_enabled'] == '1' &&
         (User.current.admin? || User.current.allowed_to?(:view_global_tpc_codes, nil, global: true))
       }

  # Add global vendor management menu to top navigation (configurable via plugin settings)
  menu :top_menu, :global_vendors,
       { controller: 'vendors', action: 'index' },
       caption: 'Vendor Management',
       if: Proc.new {
         User.current.logged? &&
         Setting.plugin_redmine_purchase_requests['global_vendor_menu_enabled'] == '1' &&
         (User.current.admin? || User.current.allowed_to?(:manage_global_vendors, nil, global: true))
       }

  # Add global reports menu to top navigation (configurable via plugin settings)
  menu :top_menu, :global_reports,
       { controller: 'reports', action: 'index' },
       caption: 'Purchase Request Reports',
       if: Proc.new {
         User.current.logged? &&
         Setting.plugin_redmine_purchase_requests['global_reports_menu_enabled'] == '1' &&
         (User.current.admin? || User.current.allowed_to?(:view_purchase_request_reports, nil, global: true))
       }
  
  # Add settings page with empty exchange_rates hash
  settings default: {
    'default_status_id' => '',
    'enable_notifications' => '1',
    'default_assigned_to_id' => '',
    'default_currency' => 'USD',
    'enabled_currencies' => ['USD', 'EUR', 'GBP', 'IDR'],
    'show_exchange_rates' => '0',
    'exchange_rates' => {},  # Initialize exchange_rates as an empty hash
    'allow_custom_vendors' => '1',
    'vendors' => [],  # Initialize vendors as an empty array
    'capex_enabled' => '1',
    'capex_auto_link' => '0',
    'capex_currency_validation' => '1',
    'capex_quarterly_validation' => '1',
    'tpc_global_enabled' => '1',
    'tpc_auto_link' => '0',
    'tpc_require_for_capex' => '0',
    'tpc_require_for_opex' => '0',
    # Issue workflow settings
    'workflow_enabled' => '0',
    'workflow_tracker_id' => '',
    'workflow_subtask_tracker_id' => '',
    'workflow_auto_create' => '0',
    'workflow_sync_status' => '0',
    'workflow_templates' => [],
    # Global menu visibility settings
    'global_tpc_menu_enabled' => '1',
    'global_tpc_dashboard_menu_enabled' => '1',
    'global_vendor_menu_enabled' => '1',
    'global_reports_menu_enabled' => '1'
  }, partial: 'settings/purchase_request_settings'
end

# Register plugin assets
require 'redmine'

# Register assets to be included
# Rails.application.config.assets.precompile += %w(purchase_requests.js apexcharts.js purchase_requests.css purchase_request_buttons.css purchase_request_vendors.css)

# Load plugin components
Rails.application.config.to_prepare do
  # Load helpers
  require_dependency 'purchase_request_settings_helper'
  require_dependency 'purchase_requests_helper'
  
  # Load PDF chart helper
  require File.join(File.dirname(__FILE__), 'lib', 'pdf_chart_helper')

  # Load branded report PDF subclass
  require File.join(File.dirname(__FILE__), 'lib', 'branded_report_pdf')

  # Load DOCX report helper (uses Redmine's bundled rubyzip/Nokogiri)
  require File.join(File.dirname(__FILE__), 'lib', 'docx_report_helper')


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
  require_dependency 'redmine_purchase_requests/issue_hooks'
  require_dependency 'redmine_purchase_requests/patches/project_patch'
  require_dependency 'redmine_purchase_requests/patches/user_patch'
end
