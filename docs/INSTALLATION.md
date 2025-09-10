# Installation Guide for Redmine Purchase Requests Plugin

## Prerequisites

- Redmine 6.0.5
- Ruby 2.7+
- Supported Databases: MySQL or PostgreSQL
- Administrator access to Redmine server

## Installation Steps

### 1. Download the Plugin

1. Navigate to your Redmine plugins directory:
   ```bash
   cd /opt/redmine-6.0.5/plugins
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/your-organization/redmine_purchase_requests.git
   ```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Database Migration

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests RAILS_ENV=production
```

### 4. Restart Redmine

- Passenger: `touch tmp/restart.txt`
- Puma/Unicorn: Restart the application server

## Configuration

1. Go to Administration > Plugins
2. Click "Configure" next to Redmine Purchase Requests Plugin
3. Set up initial configuration parameters

## Permissions

Navigate to Administration > Roles and Permissions:
- Assign appropriate roles and permissions for purchase request management

## Initial Setup Checklist

- [ ] Install plugin
- [ ] Run database migrations
- [ ] Configure plugin settings
- [ ] Set up user roles and permissions
- [ ] Verify plugin functionality

## Troubleshooting

- Ensure all dependencies are installed
- Check Redmine log files for any migration or initialization errors
- Verify database compatibility and connection

## Upgrade Process

1. Backup your Redmine installation and database
2. Remove the existing plugin
3. Download the new version
4. Run database migrations
5. Restart Redmine

## Uninstallation

1. Remove database migrations:
   ```bash
   bundle exec rake redmine:plugins:migrate NAME=redmine_purchase_requests VERSION=0 RAILS_ENV=production
   ```

2. Remove plugin directory:
   ```bash
   rm -rf /opt/redmine-6.0.5/plugins/redmine_purchase_requests
   ```

3. Restart Redmine