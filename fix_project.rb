require 'xcodeproj'

begin
  project = Xcodeproj::Project.open('PassportReader.xcodeproj')
  puts "✅ Project loaded successfully"
  
  # Remove CocoaPods build phases
  project.targets.each do |target|
    target.build_phases.delete_if do |phase|
      phase.display_name.to_s.include?('[CP]') || 
      phase.display_name.to_s.include?('Pods')
    end
  end
  
  # Save
  project.save
  puts "✅ Project saved!"
rescue => e
  puts "❌ Error: #{e.message}"
  puts "Creating new project..."
  
  # Create minimal project
  project = Xcodeproj::Project.new('PassportReader.xcodeproj')
  
  # Add main target
  target = project.new_target(:application, 'PassportReader', :ios, '13.0')
  
  # Create main group
  main_group = project.main_group.find_subpath('PassportReader', true)
  main_group.set_source_tree('<group>')
  
  # Save
  project.save
  puts "✅ New project created!"
end
