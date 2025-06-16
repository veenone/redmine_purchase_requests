# CAPEX Management Implementation Guide

## Overview
This document provides a comprehensive guide to the CAPEX (Capital Expenditure) management feature implemented in the Redmine Purchase Requests plugin.

## Architecture

### Database Schema
- **capex** table: Stores CAPEX entries with project association
- **purchase_requests.capex_id**: Foreign key linking PRs to CAPEX entries

### Key Components

#### 1. Models
- `Capex` model with comprehensive validations and business logic
- Enhanced `PurchaseRequest` model with CAPEX association
- Automatic budget utilization calculations

#### 2. Controllers
- `CapexController`: Full CRUD operations and dashboard functionality
- Enhanced `PurchaseRequestsController` with CAPEX integration

#### 3. Views
- Complete CAPEX interface (index, show, new, edit, dashboard)
- Enhanced purchase request forms with CAPEX selection
- Responsive dashboard with charts and analytics

#### 4. JavaScript & CSS
- Form validation for quarterly amounts
- Auto-distribution functionality
- Dashboard charts with ApexCharts
- Responsive styling

## Features

### Core CAPEX Management
- Create CAPEX entries with year, TPC code, description
- Multi-currency support
- Quarterly budget distribution (Q1-Q4)
- Automatic validation ensuring quarterly sum equals total

### Budget Tracking
- Link purchase requests to CAPEX entries
- Real-time utilization calculations
- Remaining budget tracking
- Over-budget alerts

### Dashboard Analytics
- Budget utilization charts
- Currency breakdown visualization
- Quarterly distribution analysis
- Recent activity tracking

### Administrative Features
- CAPEX settings in plugin configuration
- Enable/disable CAPEX functionality
- Budget alert thresholds
- Approval workflow settings

## Configuration

### Plugin Settings
Navigate to Administration → Plugins → Purchase Requests → Configure → CAPEX tab:

- **Enable CAPEX**: Toggle CAPEX functionality
- **Require CAPEX for PR**: Make CAPEX linking mandatory
- **Budget Alert Threshold**: Set percentage for budget warnings
- **Default Currency**: Set default CAPEX currency
- **Auto-distribute Quarters**: Enable automatic quarterly distribution
- **Approval Workflow**: Configure approval requirements

### Permissions
Project-level permissions for CAPEX access:
- `view_capex`: View CAPEX entries and dashboard
- `add_capex`: Create new CAPEX entries
- `edit_capex`: Edit existing CAPEX entries
- `delete_capex`: Delete CAPEX entries
- `manage_capex`: Full CAPEX management access

## Usage Workflow

### 1. Create CAPEX Entry
1. Navigate to Project → CAPEX → New CAPEX Entry
2. Fill in required fields:
   - Year (e.g., 2025)
   - TPC Code (unique identifier)
   - Description
   - Total Amount
   - Currency
   - Quarterly Distribution (Q1-Q4)
3. Use auto-distribute button for equal quarterly split
4. Save entry

### 2. Link Purchase Requests
1. Create or edit a purchase request
2. Select CAPEX entry from dropdown
3. View CAPEX details and remaining budget
4. Submit request

### 3. Monitor Budget Utilization
1. Access CAPEX Dashboard for overview
2. View individual CAPEX entries for details
3. Monitor utilization percentages
4. Track remaining budgets

## Technical Implementation

### Database Migrations
- `012_create_capex.rb`: Creates CAPEX table
- `013_add_capex_to_purchase_requests.rb`: Adds CAPEX foreign key

### Model Validations
- Year range validation (2000-2100)
- TPC code uniqueness per project/year
- Quarterly amounts sum validation
- Currency inclusion validation

### Business Logic Methods
- `utilized_amount`: Sum of linked purchase request costs
- `remaining_amount`: Total minus utilized amount
- `utilization_percentage`: Usage percentage calculation
- `display_name`: Formatted name for dropdowns

### Form Validation
- JavaScript validation for quarterly amounts
- Real-time total calculation
- Auto-distribution functionality
- Error messaging and highlighting

## Internationalization
Complete translation support in English with labels for:
- CAPEX management interfaces
- Field labels and help text
- Validation messages
- Dashboard elements

## Styling
Custom CSS classes for:
- CAPEX dashboard components
- Form layouts and validation states
- Progress bars and charts
- Responsive design elements

## Future Enhancements
Potential areas for expansion:
- CAPEX approval workflows
- Multi-year budget planning
- Advanced reporting features
- Integration with external budget systems
- CAPEX templates and cloning
- Bulk operations support

## Troubleshooting

### Common Issues
1. **Migration Errors**: Ensure database permissions are correct
2. **Permission Issues**: Verify CAPEX permissions are enabled for roles
3. **JavaScript Errors**: Check browser console for script loading issues
4. **Chart Issues**: Ensure ApexCharts library is loaded

### Debugging
- Check Rails logs for controller errors
- Use browser developer tools for JavaScript issues
- Verify database constraints and foreign keys
- Test CAPEX model methods in Rails console

## Testing
The implementation includes:
- Model validations testing
- Controller action testing
- JavaScript functionality testing
- Database migration testing

This comprehensive CAPEX management system provides a complete solution for tracking capital expenditures within Redmine projects, with tight integration to purchase request workflows and comprehensive budget monitoring capabilities.
