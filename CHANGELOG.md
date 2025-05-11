# Changelog

All notable changes to the Redmine Purchase Requests Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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