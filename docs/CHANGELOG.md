# Changelog: Redmine Purchase Requests Plugin

## [Unreleased]

### Added
- Comprehensive documentation suite
- Detailed installation and configuration guides
- Expanded API documentation

## [1.2.0] - 2024-09-10

### Added
- Multi-currency support with dynamic exchange rates
- Advanced vendor management features
- Quarterly budget allocation tracking
- Improved dashboard reporting
- Email notification system

### Changed
- Refactored workflow engine for more flexible status transitions
- Enhanced permission and access control
- Optimized database queries for better performance

### Fixed
- Resolved minor bugs in budget calculation
- Improved error handling in API endpoints
- Fixed permission-related issues in workflow management

## [1.1.0] - 2024-06-15

### Added
- CAPEX and OPEX budget tracking
- Import/export functionality for purchase requests
- Enhanced reporting capabilities
- More granular permission settings

### Changed
- Improved user interface
- Optimized background job processing
- Updated dependency versions

### Fixed
- Currency conversion accuracy
- Vendor performance tracking
- Notification delivery reliability

## [1.0.0] - 2024-03-01

### Initial Release
- Purchase request creation and management
- Basic workflow with draft, approval, and completion stages
- Vendor tracking
- Simple budget monitoring
- Role-based access control

## Upgrade Notes

### Upgrading from 1.1.0 to 1.2.0
1. Backup your database
2. Run database migrations
3. Update plugin dependencies
4. Restart Redmine application server

### Known Issues
- Potential performance impact with large datasets
- Some edge cases in multi-currency calculations

## Contribution

We welcome contributions! Please see our [Developer Guide](DEVELOPER.md) for more information on how to contribute to the project.

## Compatibility

- Redmine: 6.0.5
- Ruby: 2.7 - 3.1
- Databases: MySQL, PostgreSQL

## Future Roadmap
- Machine learning-based budget predictions
- Enhanced mobile support
- More granular reporting tools
- Improved third-party integrations