#!/usr/bin/env ruby

# Load Rails environment
ENV['RAILS_ENV'] ||= 'development'
require '/opt/redmine/config/environment'

begin
  puts "Testing vendor association fix..."
  
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
  
  # Get an OPEX entry
  opex = Opex.first
  if opex.nil?
    puts "WARNING: No OPEX entries found. Creating one..."
    opex_category = OpexCategory.first
    if opex_category.nil?
      puts "ERROR: No OPEX categories found. Please create at least one OPEX category."
      exit 1
    end
    
    opex = Opex.create!(
      name: 'Test OPEX Entry',
      amount: 1000.0,
      category_id: opex_category.id,
      description: 'Test OPEX for vendor error testing'
    )
  end
  
  puts "Creating purchase request with OPEX and empty vendor..."
  
  # Test 1: Purchase request with empty vendor string (should fail validation)
  pr1 = PurchaseRequest.new(
    title: 'Test Purchase Request with OPEX and Empty Vendor',
    description: 'Testing vendor association with empty vendor string',
    project: project,
    user: user,
    status: status,
    opex_id: opex.id,
    priority: 'normal'
  )
  
  # Manually set vendor to empty string using write_attribute (like controller does)
  pr1.write_attribute(:vendor, '')
  pr1.vendor_id = nil
  
  puts "Test 1 - Empty vendor:"
  puts "  Valid: #{pr1.valid?}"
  if !pr1.valid?
    puts "  Validation errors: #{pr1.errors.full_messages.join(', ')}"
  end
  
  # Test 2: Purchase request with custom vendor name (should succeed)
  pr2 = PurchaseRequest.new(
    title: 'Test Purchase Request with OPEX and Custom Vendor',
    description: 'Testing vendor association with custom vendor name',
    project: project,
    user: user,
    status: status,
    opex_id: opex.id,
    priority: 'normal'
  )
  
  # Manually set vendor name using write_attribute (like controller does)
  pr2.write_attribute(:vendor, 'Custom Vendor Name')
  pr2.vendor_id = nil
  
  puts "\nTest 2 - Custom vendor name:"
  puts "  Valid: #{pr2.valid?}"
  if !pr2.valid?
    puts "  Validation errors: #{pr2.errors.full_messages.join(', ')}"
  else
    puts "  Saving..."
    if pr2.save
      puts "  Saved successfully! ID: #{pr2.id}"
    else
      puts "  Save failed: #{pr2.errors.full_messages.join(', ')}"
    end
  end
  
  # Test 3: Purchase request with vendor_id (should succeed)  
  vendor = Vendor.first
  if vendor
    pr3 = PurchaseRequest.new(
      title: 'Test Purchase Request with OPEX and Vendor ID',
      description: 'Testing vendor association with vendor ID',
      project: project,
      user: user,
      status: status,
      opex_id: opex.id,
      priority: 'normal'
    )
    
    # Set vendor_id (like controller does)
    pr3.vendor_id = vendor.id
    pr3.write_attribute(:vendor, nil)
    
    puts "\nTest 3 - Vendor ID:"
    puts "  Valid: #{pr3.valid?}"
    if !pr3.valid?
      puts "  Validation errors: #{pr3.errors.full_messages.join(', ')}"
    else
      puts "  Saving..."
      if pr3.save
        puts "  Saved successfully! ID: #{pr3.id}"
      else
        puts "  Save failed: #{pr3.errors.full_messages.join(', ')}"
      end
    end
  else
    puts "\nTest 3 - Skipped (no vendors found)"
  end
  
  puts "\nTest completed successfully!"
  
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end
