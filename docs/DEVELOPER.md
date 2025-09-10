# Developer Guide: Redmine Purchase Requests Plugin

## Technical Overview

### Architecture
- **Framework**: Ruby on Rails
- **ORM**: ActiveRecord
- **Database Compatibility**: MySQL, PostgreSQL
- **Tested Ruby Versions**: 2.7 - 3.1

## Project Structure

```
redmine_purchase_requests/
├── app/
│   ├── controllers/
│   │   ├── purchase_requests_controller.rb
│   │   ├── vendors_controller.rb
│   │   └── budgets_controller.rb
│   ├── models/
│   │   ├── purchase_request.rb
│   │   ├── vendor.rb
│   │   ├── budget_allocation.rb
│   │   └── concerns/
│   └── views/
│       ├── purchase_requests/
│       └── vendors/
├── config/
│   ├── routes.rb
│   └── workflows.yml
├── db/
│   └── migrate/
│       └── XXX_create_purchase_requests.rb
└── lib/
    ├── tasks/
    └── redmine_purchase_requests/
        ├── version.rb
        └── engine.rb
```

## Development Setup

### Prerequisites
- Ruby 2.7+
- Redmine 6.0.5
- Bundler
- Git

### Local Development

1. Clone the repository
```bash
git clone https://github.com/your-org/redmine_purchase_requests.git
cd redmine_purchase_requests
```

2. Install Dependencies
```bash
bundle install
```

3. Setup Database
```bash
bundle exec rake db:migrate
bundle exec rake redmine:plugins:migrate
```

## Model Relationships

### Purchase Request Model
```ruby
class PurchaseRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :project
  belongs_to :vendor, optional: true

  has_many :budget_allocations
  has_many :attachments, as: :container

  enum status: {
    draft: 0,
    pending_approval: 1,
    approved: 2,
    rejected: 3,
    in_progress: 4,
    completed: 5
  }

  validates :title, presence: true
  validates :estimated_cost, numericality: { greater_than: 0 }
end
```

## Workflow Engine

### Status Transitions
```ruby
# Implement in config/workflows.yml
workflow:
  draft:
    transitions:
      - to: pending_approval
      - to: cancelled
  
  pending_approval:
    transitions:
      - to: approved
      - to: rejected
```

## Background Jobs

### Sidekiq Configuration
```ruby
class ExchangeRateUpdateJob
  include Sidekiq::Job

  def perform
    CurrencyService.update_exchange_rates
  end
end
```

## Testing

### Running Tests
```bash
bundle exec rake test:plugins NAME=redmine_purchase_requests
```

### Test Coverage
- Unit Tests
- Integration Tests
- API Tests
- Workflow Tests

### Test Factories
```ruby
# test/factories/purchase_requests.rb
FactoryBot.define do
  factory :purchase_request do
    title { "New Laptop" }
    description { "Developer workstation" }
    estimated_cost { 2000.00 }
    currency { "USD" }
    status { :draft }
    association :user
    association :project
  end
end
```

## Extending the Plugin

### Custom Fields
- Add custom fields via migrations
- Use `acts_as_customizable` concern

### Hooks and Callbacks
```ruby
class PurchaseRequest < ActiveRecord::Base
  after_create :send_notifications
  after_update :check_budget_thresholds

  private

  def send_notifications
    # Notification logic
  end

  def check_budget_thresholds
    # Budget alert logic
  end
end
```

## Performance Optimization

### Database Indexing
```ruby
add_index :purchase_requests, :status
add_index :purchase_requests, :user_id
add_index :purchase_requests, [:project_id, :status]
```

### Caching Strategies
- Fragment caching
- Russian Doll caching
- Redis cache store

## Internationalization (i18n)

### Locale Files
- Support multiple languages
- Comprehensive translation coverage
- Use Rails I18n framework

## Security Considerations

- Strong parameter filtering
- CSRF protection
- Authorization checks
- Secure file uploads

## Contribution Guidelines

1. Fork the repository
2. Create feature branch
3. Write tests
4. Implement feature
5. Run test suite
6. Submit pull request

## Troubleshooting

- Check Redmine logs
- Verify plugin compatibility
- Validate database migrations
- Review permission settings

## Continuous Integration

- GitHub Actions
- TravisCI
- CodeClimate integration

## Release Process

1. Update version in `lib/redmine_purchase_requests/version.rb`
2. Update `CHANGELOG.md`
3. Create Git tag
4. Publish to RubyGems

## Documentation

- Keep inline code comments
- Update developer documentation
- Maintain clear README
- Generate API documentation