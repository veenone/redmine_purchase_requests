# Redmine Purchase Requests Plugin

A comprehensive plugin for managing purchase requests within Redmine. This plugin allows users to create, track, and manage purchase requests through a user-friendly interface with customizable statuses and workflows.

![Purchase Requests List](docs/images/purchase-requests-list.png)

## Features

- **Complete Purchase Request Management**: Create, view, edit, and delete purchase requests
- **Customizable Statuses**: Define your own purchase request statuses with custom colors and workflows
- **Database-backed Vendor Management**: Store and manage vendor information in a dedicated database
- **Vendor Details Storage**: Track vendor information including name, ID, address, contact person, phone, and email
- **Detailed Request Information**: Track product details, estimated prices, vendors, and due dates
- **File Attachments**: Attach supporting documents to purchase requests
- **Priority Levels**: Assign priority levels (Low, Normal, High, Urgent) to requests
- **Multi-currency Support**: Handle different currencies with exchange rate calculations
- **Notification System**: Optional notifications for managers when new requests are created
- **Search & Filter**: Find requests by status or keyword
- **Dashboard**: View purchase request statistics and trends with visual charts
- **Responsive Design**: User-friendly interface that works on different screen sizes

## Installation

1. Clone or download this repository into your Redmine plugins directory:
   ```
   git clone https://github.com/veenone/redmine_purchase_requests.git redmine_purchase_requests
   ```

2. Navigate to the Redmine root directory and run the following command to migrate the database:
   ```
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

3. Restart your Redmine application.

## Usage

- Navigate to the Purchase Requests section in the Redmine interface to start managing your requests.
- Use the dashboard to view the status of all purchase requests at a glance.
- Create new requests or edit existing ones using the provided forms.

## Vendor Management

The plugin now includes a comprehensive vendor management system with the following features:

- **Database-backed Vendor Storage**: Vendors are stored in a dedicated database table
- **Vendor Details**: Track vendor name, ID, address, contact information, and more
- **Vendor Selection**: Select vendors from a dropdown in purchase request forms
- **Custom Vendors**: Option to enter custom vendors if needed
- **Vendor Management UI**: CRUD interface for administrators to manage vendors
- **Migration Tool**: One-click migration from settings-based vendors to database records

To migrate existing vendors from the plugin settings to the database:

1. Go to Administration > Plugin Settings > Purchase Requests
2. Navigate to the "Vendors" tab
3. Click the "Migrate Vendors" button to transfer existing vendors to the database

Once migrated, you can manage vendors through the dedicated vendor management interface.

## Upgrade Notes

### From 0.0.6 to 0.0.7

When upgrading to version 0.0.7, you'll need to migrate your database to create the vendors table:

```
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

After upgrading, you'll need to migrate your existing vendor data from settings to the database:

1. Go to Administration > Plugin Settings > Purchase Requests
2. Navigate to the "Vendors" tab
3. Click the "Migrate Vendors" button

This will transfer all your existing vendor entries to the new database-backed vendor management system.

## Contributing

Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## License

This plugin is licensed under the MIT License. See the LICENSE file for more details.