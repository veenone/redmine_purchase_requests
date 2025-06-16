#!/usr/bin/env ruby
# Test script to verify Project model patch

puts "Loading Rails environment..."

# Simple test to check if Project model has capex association
project = Project.first
if project
  puts "Project found: #{project.name}"
  
  if project.respond_to?(:capex)
    puts "✓ Project model has capex association"
    
    begin
      capex_count = project.capex.count
      puts "✓ CAPEX count for project: #{capex_count}"
      puts "✓ Project patch is working correctly!"
    rescue => e
      puts "✗ Error accessing capex: #{e.message}"
    end
  else
    puts "✗ Project model missing capex association"
  end
else
  puts "✗ No projects found"
end
