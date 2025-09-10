# Administrator Guide: Redmine Purchase Requests Plugin

## System Configuration

### Plugin Settings

Navigate to: Administration > Plugins > Redmine Purchase Requests > Configure

Key Configuration Options:
- Currency settings
- Default budget thresholds
- Approval workflow configuration
- Notification preferences
- Integration settings

## Permission Management

### Role-Based Access Control

1. Navigate to Administration > Roles and Permissions
2. Create/Modify roles with specific purchase request permissions:
   - View all requests
   - Create requests
   - Approve requests
   - Modify budget allocations
   - Manage vendors

### Permission Levels
- **Requestor**: Create and view own requests
- **Approver**: Review and approve requests
- **Finance Manager**: Full budget and vendor management
- **Administrator**: Complete system configuration

## Workflow Configuration

### Approval Workflows
- Define multi-stage approval processes
- Set approval thresholds by cost
- Configure automatic/manual approval routes

### Status Management
Customize request statuses:
- Define status transitions
- Set automatic status changes
- Configure status-based notifications

## Budget Management

### Budget Configuration
- Set annual/quarterly budget limits
- Configure CAPEX and OPEX budget categories
- Define budget warning thresholds

### Currency and Exchange Rates
- Configure base currency
- Set up multi-currency support
- Configure automatic exchange rate updates

## Vendor Management

### Vendor Setup
- Add vendor profiles
- Set vendor performance metrics
- Configure vendor evaluation criteria

## Reporting and Analytics

### Dashboard Configuration
- Customize dashboard widgets
- Configure default report views
- Set up automated report generation

## Integration and Extensions

### Email Notifications
- Configure SMTP settings
- Design email templates
- Set notification triggers

### External System Integration
- API configuration
- Export/import settings
- Third-party tool integrations

## Security Considerations

- Implement strong authentication
- Use role-based access control
- Enable audit logging
- Regular security reviews

## Performance Optimization

- Database indexing
- Caching strategies
- Background job configuration

## Maintenance

### Regular Tasks
- Backup configuration
- Review permissions
- Update exchange rates
- Audit vendor list

## Troubleshooting

### Common Admin Challenges
- Permission conflicts
- Workflow bottlenecks
- Integration issues

Refer to [Troubleshooting Guide](TROUBLESHOOTING.md) for detailed resolution steps.