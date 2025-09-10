# Troubleshooting Guide: Redmine Purchase Requests Plugin

## Common Issues and Solutions

### Installation Problems

#### 1. Dependency Installation Failures
- **Symptom**: Errors during `bundle install`
- **Solutions**:
  - Ensure Ruby version compatibility
  - Update Bundler: `gem install bundler`
  - Check system dependencies
  - Verify network connectivity

#### 2. Database Migration Errors
- **Symptom**: Migration fails during setup
- **Troubleshooting**:
  ```bash
  # Reset migrations
  bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests VERSION=0
  
  # Re-run migrations
  bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests
  
  # Check database permissions
  ```

### Configuration Issues

#### 3. Plugin Not Showing in Redmine
- **Possible Causes**:
  - Incorrect plugin installation
  - Permissions issues
  - Redmine restart required
- **Solutions**:
  - Verify plugin directory location
  - Check Redmine log files
  - Restart Redmine application server

#### 4. Currency and Exchange Rate Problems
- **Symptoms**: 
  - Incorrect currency conversions
  - Missing exchange rates
- **Troubleshooting**:
  - Verify external API configurations
  - Check network connectivity
  - Manually update exchange rates
  - Review currency configuration

### Workflow and Permissions

#### 5. Approval Workflow Not Working
- **Debugging Steps**:
  ```ruby
  # Check workflow configuration
  Rails.logger.debug PurchaseRequest.workflow_config
  
  # Verify user permissions
  current_user.roles.each do |role|
    puts role.permissions
  end
  ```
- **Common Fixes**:
  - Review role-based permissions
  - Validate workflow configuration
  - Check user assignments

### Performance and Scaling

#### 6. Slow Performance with Large Datasets
- **Performance Optimization**:
  ```ruby
  # Add database indexes
  add_index :purchase_requests, :created_at
  add_index :purchase_requests, [:user_id, :status]
  
  # Use eager loading
  PurchaseRequest.includes(:user, :project).limit(100)
  ```
- **Recommendations**:
  - Implement pagination
  - Use caching strategies
  - Optimize database queries

### API and Integration

#### 7. API Authentication Failures
- **Troubleshooting Checklist**:
  - Verify API key
  - Check IP whitelisting
  - Validate token expiration
  - Review API endpoint configurations

### Notification Issues

#### 8. Email Notifications Not Sending
- **Diagnostic Commands**:
  ```bash
  # Check mail configuration
  rails runner "puts ActionMailer::Base.smtp_settings"
  
  # Test email delivery
  rails runner "UserMailer.test_email.deliver_now"
  ```
- **Potential Fixes**:
  - Verify SMTP settings
  - Check email service configurations
  - Review firewall rules

### Security and Access Control

#### 9. Unexpected Access to Sensitive Information
- **Security Audit Steps**:
  ```ruby
  # Review user permissions
  User.with_role(:admin).each do |admin|
    puts "Admin User: #{admin.login}"
  end
  ```
- **Recommendations**:
  - Regularly audit user roles
  - Implement principle of least privilege
  - Use strong password policies

## Log Analysis

### Redmine Log Locations
- **Production**: `/log/production.log`
- **Development**: `/log/development.log`

### Log Parsing Example
```bash
# Filter purchase request related logs
grep "PurchaseRequest" log/production.log | tail -n 50
```

## Advanced Debugging

### Enable Verbose Logging
```ruby
# config/environments/development.rb
config.log_level = :debug

# Specific plugin logging
Redmine::Plugin.register :redmine_purchase_requests do
  # Configure logging
end
```

## Community Support

- GitHub Issues
- Redmine Community Forums
- Professional Support Channels

## Emergency Recovery

### Rollback Plugin
```bash
# Complete plugin removal
bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests VERSION=0
```

## Best Practices

1. Regular backups
2. Staged environment testing
3. Careful permission management
4. Continuous monitoring
5. Keep dependencies updated

## Version Compatibility

- Check plugin compatibility matrix
- Test in staging before production upgrade

## Contact and Support

For unresolved issues, contact:
- Plugin Maintainers
- Redmine Community Support
- Professional Support Services