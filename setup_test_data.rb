require_relative '../config/environment'

puts "Creating test OPEX categories..."

categories = [
  'Office Supplies',
  'Software Licenses', 
  'Hardware Maintenance',
  'Training & Development',
  'Travel & Accommodation',
  'Consulting Services'
]

categories.each do |name|
  unless OpexCategory.exists?(name: name)
    category = OpexCategory.create!(name: name)
    puts "Created category: #{category.name}"
  else
    puts "Category already exists: #{name}"
  end
end

puts "Creating purchase request statuses..."

statuses = [
  {name: 'Draft', is_closed: false, position: 1, color: '#6c757d'},
  {name: 'Submitted', is_closed: false, position: 2, color: '#007bff'},
  {name: 'Under Review', is_closed: false, position: 3, color: '#fd7e14'},
  {name: 'Approved', is_closed: false, position: 4, color: '#28a745'},
  {name: 'Rejected', is_closed: true, position: 5, color: '#dc3545'},
  {name: 'Completed', is_closed: true, position: 6, color: '#28a745'}
]

statuses.each do |attrs|
  unless PurchaseRequestStatus.exists?(name: attrs[:name])
    status = PurchaseRequestStatus.create!(attrs)
    puts "Created status: #{status.name}"
  else
    puts "Status already exists: #{attrs[:name]}"
  end
end

# Set the first status as default if no default exists
unless PurchaseRequestStatus.exists?(is_default: true)
  first_status = PurchaseRequestStatus.first
  if first_status
    first_status.update!(is_default: true)
    puts "Set #{first_status.name} as default status"
  end
end

puts "Test data setup completed!"
puts "OPEX Categories: #{OpexCategory.count}"
puts "Purchase Request Statuses: #{PurchaseRequestStatus.count}"
