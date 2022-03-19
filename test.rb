require 'xcodeproj'
require_relative 'util.rb'

# def updatePlist(path, key, value)
#   puts "修改 infoplist: #{path}, #{key}: #{value}"
#   infoPlistHash = Xcodeproj::Plist.read_from_path(path)
#   infoPlistHash[key] = value
#   Xcodeproj::Plist.write_to_path(infoPlistHash, path)
#   puts "修改 infoplist完成"
# end

proj = Xcodeproj::Project.open("/Users/1234/Desktop/repackage_demo/ios/repackage/repackage.xcodeproj")

# updatePlist('/Users/1234/Desktop/repackage_demo/ios/repackage/repackage/Info.plist', 'CFBundleDisplayName', 'hahah')

updateImages("/Users/1234/Desktop/repackage_demo/ios/repackage/repackage/Assets.xcassets")

proj.save() 

# Dir.foreach("/Users/1234/Desktop/repackage_demo/ios/repackage/repackage/Assets.xcassets/AppIcon.appiconset") do |f|
#   puts f
# end

# puts "2x".to_i

