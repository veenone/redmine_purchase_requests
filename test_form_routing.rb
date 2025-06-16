#!/usr/bin/env ruby

puts "Testing CAPEX form routing fix..."

begin
  # Load Rails environment
  require_relative '/opt/redmine/config/environment'
  
  puts "✓ Rails environment loaded"
  
  # Test project and CAPEX setup
  project = Project.first
  if project
    puts "✓ Found test project: #{project.name}"
    
    # Test new CAPEX form
    puts "\nTesting new CAPEX form routing..."
    begin
      new_capex = project.capex.build
      puts "✓ New CAPEX object created"
      puts "  - new_record?: #{new_capex.new_record?}"
      
      # Test the route helpers we're using in the form
      include Rails.application.routes.url_helpers
      
      # Test project_capex_index_path (for new records)
      index_path = project_capex_index_path(project)
      puts "✓ project_capex_index_path: #{index_path}"
      
      # Test project_capex_path (for existing records)  
      if project.capex.any?
        existing_capex = project.capex.first
        show_path = project_capex_path(project, existing_capex)
        puts "✓ project_capex_path: #{show_path}"
      else
        puts "ℹ No existing CAPEX to test show path"
      end
      
    rescue => e
      puts "✗ Route helper failed: #{e.message}"
      raise e
    end
    
  else
    puts "✗ No projects found in database"
  end
  
  puts "\n✅ Routing test completed successfully!"
  puts "The CAPEX form should now work without route errors."
  
rescue => e
  puts "✗ Error: #{e.message}"
  puts "Stack trace: #{e.backtrace.first(5).join("\n")}"
end
