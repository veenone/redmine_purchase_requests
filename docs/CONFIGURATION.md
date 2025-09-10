# Configuration Guide: Redmine Purchase Requests Plugin

## Table of Contents
1. [Plugin Settings](#plugin-settings)
2. [Database Configuration](#database-configuration)
3. [Workflow Configuration](#workflow-configuration)
4. [Currency and Exchange Rates](#currency-and-exchange-rates)
5. [Email Notifications](#email-notifications)
6. [Performance Tuning](#performance-tuning)

## Plugin Settings

### Configuration Location
`Administration > Plugins > Redmine Purchase Requests > Configure`

### Key Configuration Parameters

#### General Settings
- **Default Currency**: Base currency for all transactions
- **Fiscal Year Start**: Define fiscal year beginning
- **Default Timezone**: System-wide time zone

#### Budget Configuration
- **Annual Budget Limit**: Global budget ceiling
- **CAPEX Budget Percentage**: Capital expenditure allocation
- **OPEX Budget Percentage**: Operational expenditure allocation
- **Budget Warning Threshold**: Percentage for budget alerts

## Database Configuration

### Supported Databases
- MySQL 5.7+
- PostgreSQL 10+

### Database Migrations
```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests RAILS_ENV=production
```

### Schema Overview
```ruby
# purchase_requests table
create_table :purchase_requests do |t|
  t.string :title
  t.text :description
  t.decimal :estimated_cost, precision: 10, scale: 2
  t.string :currency
  t.string :status
  t.references :project
  t.references :user
  t.date :requested_date
  t.timestamps
end

# vendors table
create_table :vendors do |t|
  t.string :name
  t.string :contact_email
  t.string :tax_id
  t.text :description
  t.timestamps
end
```

## Workflow Configuration

### Status Workflow
Customize request status transitions in `config/workflows.yml`:

```yaml
draft:
  transitions:
    - to: pending_approval
    - to: cancelled

pending_approval:
  transitions:
    - to: approved
    - to: rejected
```

### Approval Rules
- Configure multi-level approvals
- Set cost-based approval thresholds
- Define role-specific approval permissions

## Currency and Exchange Rates

### Exchange Rate Configuration
- Automatic rate updates from external APIs
- Manual rate entry
- Rate history tracking

#### Configuration Example
```ruby
# config/currency.yml
default_currency: USD
exchange_rate_source: ecb  # European Central Bank
update_frequency: daily
```

## Email Notifications

### SMTP Configuration
- Configure in `config/email.yml`
- Support for multiple SMTP providers
- Template customization

#### Notification Triggers
- Request creation
- Status changes
- Budget threshold alerts
- Approval requests

## Performance Tuning

### Caching Strategies
- Redis cache configuration
- Fragment caching for dashboards
- Query optimization

### Background Jobs
- Sidekiq configuration for async tasks
- Exchange rate updates
- Reporting generation

### Indexing
```sql
-- Recommended database indexes
CREATE INDEX idx_purchase_requests_status ON purchase_requests(status);
CREATE INDEX idx_purchase_requests_user ON purchase_requests(user_id);
```

## Environment-Specific Configuration

### Development
- Enable verbose logging
- Mock external service integrations

### Production
- Disable debug mode
- Configure robust caching
- Set up monitoring

## Security Configuration

### Recommended Settings
- Enable SSL
- Use strong password policies
- Implement two-factor authentication
- Regular security audits

## Troubleshooting Configuration

- Check `log/production.log` for issues
- Verify database connectivity
- Validate external service configurations

## Best Practices

1. Use environment variables for sensitive configurations
2. Regularly backup configuration files
3. Version control configuration changes
4. Test configuration in staging before production