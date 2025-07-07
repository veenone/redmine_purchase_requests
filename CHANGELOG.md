# Changelog

All notable changes to the Redmine Purchase Requests Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-07-07

### Added
- **TPC Code Index Enhancement**: TPC code numbers are now clickable links that serve as shortcuts to view TPC code details
- **Modern UI/UX Consistency**: Unified modern styling across all purchase request templates (new, edit, view)
- **Professional Navigation**: Consistent contextual navigation buttons across all forms
- **Enhanced User Experience**: Improved visual hierarchy and responsive design patterns

### Enhanced
- **Purchase Request Templates**: Modernized edit and view templates to match the new template's professional styling
- **Form Consistency**: Applied modern container layouts, tab navigation, and visual styling across all forms
- **Tab Navigation**: Updated JavaScript for modern tab functionality with smooth transitions
- **Visual Design**: Professional color schemes, spacing, and typography throughout the interface
- **Accessibility**: Improved keyboard navigation and screen reader compatibility

### Fixed
- **Critical TPC Code Update Error**: Resolved `ActiveRecord::NotNullViolation` error when updating CAPEX entries with TPC code selection
- **Database Constraint Issue**: Fixed NULL constraint violation in `tpc_code` column during TPC code assignment
- **Form Validation**: Enhanced TPC code validation to handle both legacy and association-based TPC codes
- **JavaScript Handling**: Improved form field management when switching between TPC code selection methods
- **Data Integrity**: Ensured proper value assignment when using TPC code dropdowns vs legacy fields

### Technical Improvements
- **Model Logic**: Updated `handle_tpc_code_assignment` method to populate instead of nullify TPC code field
- **Form JavaScript**: Enhanced TPC code field management with readonly states and proper value preservation
- **Validation Logic**: Strengthened validation to prevent blank TPC codes while maintaining flexibility
- **Template Structure**: Modernized HTML structure with proper container hierarchy and CSS classes
- **CSS Architecture**: Implemented consistent design system with reusable styling patterns

### User Interface
- **Modern Design Language**: Applied contemporary web UI patterns throughout the plugin
- **Responsive Layout**: Improved mobile and tablet compatibility across all views
- **Visual Feedback**: Enhanced hover effects, transitions, and interactive elements
- **Information Architecture**: Better organization of content with clear visual hierarchy
- **Navigation Flow**: Streamlined user journeys with intuitive button placement and labeling

### Developer Experience
- **Code Organization**: Cleaner separation of concerns in templates and styling
- **Maintainability**: Consistent naming conventions and reusable CSS classes
- **Documentation**: Comprehensive status reports and implementation guides
- **Error Handling**: Robust validation and error messaging throughout the system

## [1.1.0] - 2025-07-01

### Added
- **OPEX Management System**: Complete Operational Expenditure tracking and management
- OPEX entry creation with categories, quarterly distribution, and multi-currency support
- **OPEX Categories Configuration**: Admin interface in plugin settings to manage OPEX categories
- OPEX category management (add/delete) directly from plugin configuration page
- OPEX dashboard with analytics, category breakdowns, and utilization tracking
- Database migrations for OPEX tables and category relationships
- OPEX model with proper validations and quarterly amount calculations
- OPEX controller with full CRUD operations and dashboard functionality
- OPEX views (index, new, dashboard) with professional styling
- **Enhanced Vendor Management**: CSV/JSON import/export functionality for vendors
- Vendor import/export UI with template download and data validation
- **Improved Purchase Request Forms**: Enhanced validation and field management
- **CAPEX Integration**: OPEX category requirement for new CAPEX creation
- Comprehensive translations for all OPEX and vendor management features
- Foreign key relationships between OPEX entries and categories
- Enhanced error handling and user feedback for all new features

### Enhanced
- Purchase request model with stronger validations and enhanced field handling
- CAPEX and OPEX forms now require OPEX category selection from configured categories
- Plugin settings now include dedicated OPEX category management tab
- Improved settings controller patch to handle OPEX category operations
- Enhanced database structure with proper foreign key constraints
- Updated routing for OPEX and vendor management features
- Improved localization with missing translation labels added

### Fixed
- Resolved route helper issues in plugin settings context
- Fixed OPEX category dropdown population from database
- Corrected collection_select validation requirements
- Fixed template errors in vendor management pages
- Resolved database column conflicts in OPEX model
- Fixed redirect issues after OPEX creation
- Proper handling of required fields in forms

## [1.0.0] - 2025-06-15

### Added
- **CAPEX Management System**: Comprehensive Capital Expenditure tracking and budget management
- CAPEX entry creation with year, TPC codes, and total amounts
- Quarterly budget distribution (Q1-Q4) with automatic validation
- Multi-currency support for CAPEX budgets  
- Purchase request linking to CAPEX entries for budget tracking
- CAPEX dashboard with visual analytics and utilization charts
- Budget utilization tracking with remaining amount calculations
- CAPEX alerts system for budget thresholds and over-budget situations
- CAPEX-specific permissions and project-level access control
- CAPEX settings configuration in plugin administration
- Database migrations for CAPEX tables and purchase request integration
- Comprehensive CAPEX translations and localization
- CAPEX-specific CSS styling and JavaScript validation
- CAPEX form validation for quarterly amounts and TPC code uniqueness
- Auto-distribution functionality for quarterly budget amounts

### Enhanced
- Purchase request forms now include CAPEX entry selection
- Purchase request views display linked CAPEX information and budget details
- Project navigation includes CAPEX management menu items
- Dashboard analytics extended with CAPEX budget tracking
- Search and filtering capabilities for CAPEX entries
- Responsive design improvements for CAPEX interfaces

### Technical
- Added Capex model with comprehensive validations and business logic
- Created CapexController with full CRUD operations and dashboard
- Database schema additions for CAPEX management
- Enhanced purchase request model with CAPEX associations
- Added CAPEX-specific helper methods and view partials
- JavaScript enhancements for CAPEX form validation and charts

## [0.0.8] - 2025-05-20

### Added
- Moved vendor management from plugin settings to project level
- Added project-specific vendor management UI
- Created new vendor listing partial to standardize display
- Added improved vendor search capabilities
- Added project-level permissions for vendor management
- Enhanced vendor display with formatting improvements
- Added project menu entry for vendor management

### Changed
- Maintained global vendor data while providing project-level access
- Improved vendor selection UI in purchase request forms
- Enhanced vendor autocomplete with better search results
- Reorganized vendor management interface for better usability

## [0.0.7] - 2025-05-16

### Added
- Database-backed vendor management system
- Vendor details storage with name, ID, address, phone, contact person, and email
- Vendor selection dropdown in purchase request forms
- Vendor management UI with CRUD operations
- Migration tool to convert settings-based vendors to database records
- Improved tab navigation with proper content separation

### Fixed
- Fixed tab content display in purchase request forms
- Resolved vendor details display and selection issues
- Fixed JavaScript loading and execution for dynamic forms
- Improved form validation for vendor selection
- Fixed asset loading with proper view hooks

### Technical Details
- Added vendors database table migration
- Created full Vendor model with validations
- Added VendorsController with CRUD and API methods
- Updated purchase request views to use the new vendor model
- Implemented proper hook-based asset loading
- Added JavaScript improvements for form interactivity
- Enhanced form styling for better usability

## [0.0.6] - 2025-05-12

### Added
- Project-level scoping for purchase requests
- Multi-currency support with exchange rates
- Support for Indonesian Rupiah (IDR) currency
- Dashboard with currency conversion statistics

### Fixed
- Fixed parameter handling for exchange rates in settings
- Fixed currency selection in new/edit forms
- Updated top vendors and top requesters calculations to consider currency conversion
- Corrected path helpers throughout the plugin for project-level scoping
- Fixed dashboard menu visibility in project context

### Technical Details
- Added migration to include project_id in purchase requests table
- Updated controllers to handle project-scoped routes properly
- Implemented proper exchange rate conversion for financial calculations
- Enhanced dashboard view with multi-currency support

## [0.0.5] - 2025-04-19

### Added
- Initial release of the Purchase Requests plugin
- CRUD operations for purchase requests
- Custom status management system with color coding
- File attachment support for purchase requests
- Priority levels (Low, Normal, High, Urgent)
- Ability to set due dates for requests
- Manager notification system
- Search and filtering capabilities
- Responsive user interface
- Plugin settings page with general and status configuration tabs
- Comprehensive permission system

### Technical Details
- Created database migrations for purchase requests and statuses
- Added support for file attachments
- Implemented URL validation for product links
- Added pagination compatible with different Redmine versions
- Created responsive styling for all plugin views
- Added translation support through localization files