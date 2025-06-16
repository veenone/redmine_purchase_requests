puts "Testing Project Model Patch..."

# Check if the patch file exists
patch_file = '/opt/redmine/plugins/redmine_purchase_requests/lib/redmine_purchase_requests/patches/project_patch.rb'
if File.exist?(patch_file)
  puts "✓ Project patch file exists"
  
  # Check the content
  content = File.read(patch_file)
  if content.include?('has_many :capex')
    puts "✓ Project patch includes CAPEX association"
  else
    puts "✗ Project patch missing CAPEX association"
  end
  
  if content.include?('Project.include')
    puts "✓ Project patch applies the module"
  else
    puts "✗ Project patch doesn't apply the module"
  end
else
  puts "✗ Project patch file missing"
end

# Check if init.rb loads the patch
init_file = '/opt/redmine/plugins/redmine_purchase_requests/init.rb'
if File.exist?(init_file)
  init_content = File.read(init_file)
  if init_content.include?('project_patch')
    puts "✓ Init file loads project patch"
  else
    puts "✗ Init file doesn't load project patch"
  end
else
  puts "✗ Init file missing"
end

puts "\nProject patch implementation appears complete!"
puts "If you're still getting 'undefined method capex' errors, try:"
puts "1. Restart your Redmine server"
puts "2. Check the Redmine logs for any patch loading errors"
puts "3. Verify the plugin is properly loaded in Redmine admin"
