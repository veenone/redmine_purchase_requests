#!/usr/bin/env ruby

# Load Rails environment
ENV['RAILS_ENV'] ||= 'development'
require '/opt/redmine/config/environment'

begin
  # Create a test project if one doesn't exist
  project = Project.find_by(identifier: 'test-project') || Project.create!(
    name: 'Test Project',
    identifier: 'test-project',
    description: 'Test project for purchase requests'
  )
  
  # Get user
  user = User.find_by(login: 'admin') || User.first
  
  # Get a status
  status = PurchaseRequestStatus.first
  if status.nil?
    puts "ERROR: No purchase request statuses found. Please create at least one status."
    exit 1
  end
  
  # Create an OPEX category if needed
  opex_category = OpexCategory.first
  if opex_category.nil?
    puts "ERROR: No OPEX categories found. Please create at least one OPEX category."
    exit 1
  end
  
  # Create an OPEX entry
  opex = Opex.create!(
    name: 'Test OPEX Entry',
    amount: 1000.0,
    category_id: opex_category.id,
    description: 'Test OPEX for vendor error testing'
  )
  
  puts "Creating purchase request with OPEX..."
  
  # Try to create a purchase request with OPEX and empty vendor
  pr = PurchaseRequest.new(
    title: 'Test Purchase Request with OPEX',
    description: 'Testing vendor association error with OPEX budget source',
    project: project,
    user: user,
    status: status,
    opex_id: opex.id,
    vendor: '',  # This might be causing the issue
    vendor_id: nil,
    priority: 'normal'
  )
  
  puts "Validating purchase request..."
  if pr.valid?
    puts "Purchase request is valid"
    if pr.save
      puts "Purchase request saved successfully!"
    else
      puts "Failed to save purchase request:"
      pr.errors.full_messages.each { |msg| puts "  - #{msg}" }
    end
  else
    puts "Purchase request validation failed:"
    pr.errors.full_messages.each { |msg| puts "  - #{msg}" }
  end
  
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end
