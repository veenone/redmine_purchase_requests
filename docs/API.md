# API Documentation: Redmine Purchase Requests Plugin

## Overview
The Redmine Purchase Requests Plugin provides a comprehensive RESTful API for programmatic interaction with purchase requests, vendors, and budget management.

## Authentication
- API Key Authentication
- OAuth 2.0 Support
- IP Whitelisting

## Base URL
`/redmine/purchase_requests/api/v1`

## Endpoints

### Purchase Requests

#### 1. List Purchase Requests
- **GET** `/purchase_requests`
- Parameters:
  - `status`: Filter by request status
  - `user_id`: Filter by requester
  - `project_id`: Filter by project
  - `start_date`: Filter by date range
  - `page`: Pagination
  - `per_page`: Results per page

#### 2. Create Purchase Request
- **POST** `/purchase_requests`
- Request Body:
```json
{
  "title": "Laptop Procurement",
  "description": "New developer workstations",
  "estimated_cost": 5000.00,
  "currency": "USD",
  "budget_category": "CAPEX",
  "project_id": 123,
  "vendor_id": 45
}
```

#### 3. Get Purchase Request
- **GET** `/purchase_requests/{id}`
- Returns full request details

#### 4. Update Purchase Request
- **PUT** `/purchase_requests/{id}`
- Similar request body to creation endpoint

#### 5. Delete Purchase Request
- **DELETE** `/purchase_requests/{id}`

### Vendors

#### 1. List Vendors
- **GET** `/vendors`
- Parameters:
  - `name`: Search by vendor name
  - `category`: Vendor category

#### 2. Create Vendor
- **POST** `/vendors`
- Request Body:
```json
{
  "name": "Tech Suppliers Inc.",
  "contact_email": "sales@techsuppliers.com",
  "tax_id": "12-3456789",
  "description": "IT hardware supplier"
}
```

### Budget Management

#### 1. Get Budget Summary
- **GET** `/budgets/summary`
- Returns:
  - Total budget
  - Spent amount
  - Remaining budget
  - CAPEX/OPEX breakdown

#### 2. Create Budget Allocation
- **POST** `/budgets/allocate`
- Request Body:
```json
{
  "fiscal_year": 2024,
  "quarter": 2,
  "budget_type": "CAPEX",
  "amount": 100000.00,
  "currency": "USD"
}
```

## Response Formats
- JSON
- XML (configurable)

## Error Handling
```json
{
  "error": {
    "code": 400,
    "message": "Invalid request parameters",
    "details": []
  }
}
```

## Rate Limiting
- 100 requests/minute
- 1000 requests/day per API key

## Webhooks
Configure webhooks for:
- Purchase request status changes
- Budget threshold alerts
- Vendor updates

## SDK and Client Libraries
- Python
- Ruby
- JavaScript
- PHP

## Security
- HTTPS only
- API key rotation
- Detailed access logs

## Versioning
- Current Version: v1
- Deprecation policy: 6-month notice

## Example Client Code

### Python
```python
from redmine_purchase_requests import PurchaseRequestsClient

client = PurchaseRequestsClient(api_key='your_api_key')
requests = client.get_purchase_requests(status='pending_approval')
```

### Ruby
```ruby
require 'redmine_purchase_requests'

client = RedminePurchaseRequests::Client.new(api_key: 'your_api_key')
budget_summary = client.get_budget_summary
```

## Best Practices
1. Use API key rotation
2. Implement robust error handling
3. Cache API responses
4. Monitor API usage
5. Keep API key confidential