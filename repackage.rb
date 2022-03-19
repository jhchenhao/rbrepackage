require 'fileutils'
require 'xcodeproj'
require 'json'
require_relative 'util.rb'

#workpath
workpath = 'workspace'
projpath = "#{workpath}/repackage"

#是否存在文件夹
flag = File::exists?(workpath)
if !flag
  #不存在 新建目录
  system "mkdir #{workpath}"
end

#是否存在项目
ifProjExit = File::exists?(projpath)
if !ifProjExit 
  #进入工作目录 执行完后回到原来路径
  FileUtils.cd(workpath) do
    targetGitUrl = 'git@github.com:jhchenhao/repackage.git'
    targetBranch = 'main'
    gitcloneCode(targetGitUrl, targetBranch)
  end
end

#========================================读取配置信息
jsonPath = 'config.json'
json = File.read(jsonPath)
configObj = JSON.parse(json)
puts "解析json数据#{configObj}"
#bundleid
bundleid = configObj['bundleid']
#appname
appname = configObj['appname']
#version
version = configObj['version']
#build
build = configObj['build']
#CODE_SIGN_IDENTITY
certificate_name = configObj['team']

#删除多余key 防止干扰
configObj.delete('bundleid')
configObj.delete('todaybundleid')
configObj.delete('appname')
configObj.delete('version')
configObj.delete('build')
configObj.delete('team')

#获取mobiileprovision uuid
mobileprovision_name = %x(ls mobileprovision).split(' ')[0].split('.')[0]
mobileprovision_path = "mobileprovision/" + %x(ls mobileprovision).split(' ')[0]
mobileprovision_uuid = %x(mobileprovision-read -f #{mobileprovision_path} -o UUID)
teamId = %x(mobileprovision-read -f #{mobileprovision_path} -o TeamIdentifier).strip

#=======================================更改proj信息
projName = 'repackage.xcodeproj'
targetName = 'repackage'
proj_path = projpath + '/' + projName
puts '解析完成'
#修改app名称
#infolist 路径
infoPlistPath = projpath + '/repackage/info.plist'
updateAppName(infoPlistPath, appname)

#打开proj
proj = Xcodeproj::Project.open(proj_path)
puts "打开了项目#{proj}"
proj.targets.each do |target|
  # puts target.copy_files_build_phases
  if target.to_s == targetName
    target.build_configurations.each do |b|
      puts b.build_settings
      puts '=========='
      #不能设置为Automatic
      b.build_settings['CODE_SIGN_STYLE'] = "Manual"
      #修改版本号
      b.build_settings['MARKETING_VERSION'] = version
      #修改build
      b.build_settings['CURRENT_PROJECT_VERSION'] = build
      #修改bundleid
      b.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundleid
      #修改CODE_SIGN_IDENTITY
      b.build_settings['CODE_SIGN_IDENTITY'] = certificate_name
      #PROVISIONING_PROFILE_SPECIFIER
      b.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = mobileprovision_name
      #PROVISIONING_PROFILE
      b.build_settings['PROVISIONING_PROFILE'] = mobileprovision_uuid
    end
  end 
end
proj.save()
puts "修改基本信息完成"

puts "修改内部文件"
puts configObj
commonFilePaths = [
  "#{projpath}/repackage/Config.h"
]
commonFilePaths.each do |path|
  updateCustomFileContent(path, configObj)
end
puts "内部文件内容修改完成"

#修改icon
#====================
updateImages("#{projpath}/repackage/Assets.xcassets")

#如果用cocoapods管理项目 执行一下podinstall
# puts "update pods"
# podfilePath = "#{projpath}/Podfile"
# if !File::exists?("#{projpath}/Pods") && File::exists?(podfilePath)
#   system "pod install --project-directory=#{projpath}"
# end
# puts "pod完成"

#==================打包===================
puts "开始打包"
build_path = "#{workpath}/build"
archive_path = "#{build_path}/app.xcarchive"
if File::exists?(build_path)
  system "rm -rf #{build_path}"
end
FileUtils.makedirs(build_path)
#1.archive
archive_flag = system "xcodebuild archive -project #{proj_path} -scheme #{targetName} -configuration Release -archivePath #{archive_path}"
if !archive_flag
  puts "archive 失败"
  exit 1
end
puts "archive完成 开始导出ipa "
method = judgeMobileProvisionType(mobileprovision_path)
#生成plist
plistTxt = ""
File.open('exportplist/ExportOptions.plist','r') do |f|
  plistTxt = f.read()
end
plistTxt = plistTxt.gsub("$method", method)
plistTxt = plistTxt.gsub("$boundid", bundleid)
plistTxt = plistTxt.gsub("$mobileprofilename", mobileprovision_name)
plistTxt = plistTxt.gsub("$teamID", teamId)
plist_path = "#{build_path}/ExportOptions.plist"
File.open(plist_path,'w') do |f|
  f.write(plistTxt)
end
# 导出ipa
ipa_path = "#{build_path}/app"
result = system "xcodebuild -exportArchive -archivePath #{archive_path} -exportPath #{ipa_path} -exportOptionsPlist #{plist_path}"
if result
  puts "导出成功"
else 
  puts "导出失败"
  exit 0
end
#删除archive
FileUtils.cp("#{ipa_path}/#{targetName}.ipa", "#{build_path}/app.ipa")
system("rm -rf #{ipa_path}")
system("rm -rf #{plist_path}")
system("rm -rf #{archive_path}")
system("open #{build_path}")

printInterestingLog()