#!/usr/bin/env ruby

# Simple test script to verify Project model patch is working
require 'bundler/setup'
require 'rails'

# Load Rails environment
require_relative '/opt/redmine/config/environment'

puts "Testing Project model patch..."

# Test if Project model has capex association
project = Project.first
if project
  puts "Project found: #{project.name}"
  
  # Test if capex method exists
  if project.respond_to?(:capex)
    puts "✓ Project model has capex association"
    
    # Test capex_entries method
    if project.respond_to?(:capex_entries)
      puts "✓ Project model has capex_entries method"
      
      begin
        capex_count = project.capex.count
        puts "✓ CAPEX count for project: #{capex_count}"
      rescue => e
        puts "✗ Error accessing capex: #{e.message}"
      end
    else
      puts "✗ Project model missing capex_entries method"
    end
  else
    puts "✗ Project model missing capex association"
  end
else
  puts "✗ No projects found in database"
end

puts "Test completed."
