# Redmine Purchase Requests Plugin

A comprehensive plugin for managing purchase requests within Redmine. This plugin allows users to create, track, and manage purchase requests through a user-friendly interface with customizable statuses and workflows.

![Purchase Requests List](docs/images/purchase-requests-list.png)

## Features

- **Complete Purchase Request Management**: Create, view, edit, and delete purchase requests
- **Customizable Statuses**: Define your own purchase request statuses with custom colors and workflows
- **Detailed Request Information**: Track product details, estimated prices, vendors, and due dates
- **File Attachments**: Attach supporting documents to purchase requests
- **Priority Levels**: Assign priority levels (Low, Normal, High, Urgent) to requests
- **Notification System**: Optional notifications for managers when new requests are created
- **Search & Filter**: Find requests by status or keyword
- **Responsive Design**: User-friendly interface that works on different screen sizes

## Installation

1. Clone or download this repository into your Redmine plugins directory:
   ```
   git clone <repository-url> redmine_purchase_requests
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

## Contributing

Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## License

This plugin is licensed under the MIT License. See the LICENSE file for more details.