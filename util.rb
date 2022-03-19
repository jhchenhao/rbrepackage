require 'xcodeproj'
require "chunky_png"
require 'fileutils'
require 'json'

def gitcloneCode(path, barch)
  #替换成自己的代码库地址
  puts "下拉代码"
  targetGitUrl = path
  targetBranch = barch
  flag = system "git clone -b #{targetBranch} #{targetGitUrl}"
  if !flag
    puts "代码下拉失败"
    exit 1
  end
  system "git branch"
  puts "代码下拉完成"
end

def updatePlist(path, key, value)
  puts "修改 infoplist: #{path}, #{key}: #{value}"
  infoPlistHash = Xcodeproj::Plist.read_from_path(path)
  infoPlistHash[key] = value
  Xcodeproj::Plist.write_to_path(infoPlistHash, path)
  puts "修改 infoplist完成"
end

###更新app应用名称 path: plist路径 name: 目标名称
def updateAppName(path, name)
  updatePlist(path, 'CFBundleDisplayName', name)
end

#修改方法
def modifierTxt(line, target)
  #读取@""内容正则
  regex = /(?<=@").*?(?=")/
  source = regex.match(line).to_s
  puts "===修改了：#{line}" + source + ' to：' + target
  res = line.gsub(source, target)
  return res
end

# 自定义修改文件内容 obj(hash)
def updateCustomFileContent(path, obj) 
   #目标文本
   targetTxt = ""
   File.open(path, 'r') do |f|
     targetTxt = f.read()
   end
   File.open(path, 'r') do |f|
    fs = f.readlines
    resf = targetTxt
    fs.each do |line|
      obj.each_key do |key|
        #匹配有对应字段的行 若则匹配有误 请自行修改正则
        regex = /#{key}(.*?)=/
        if regex.match(line)
          #替换文本
          newline = modifierTxt(line, obj[key])
          resf = resf.gsub(line, newline)
        end
      end
    end
    #写入文件
    File.open(path, 'w') do |f|
      f.write(resf)
    end
   end
end

#替换appIcon
def updateAppIcon(iconPath)
  puts iconPath
  #替换icon
  oriIconPath = "images/appIcon"
  iconNames = {
    40 => ["icon_20pt@2x.png"],
    58 => ["icon_29pt@2x.png"],
    60 => ["icon_20pt@3x.png"],
    80 => ["icon_40pt@2x.png"],
    87 => ["icon_29pt@3x.png"],
    120 => ["icon_40pt@3x.png", "icon_60pt@2x.png"],
    180 => ["icon_60pt@3x.png"],
    1024 => ["icon.png"]
  }
  #删除原先文件
  Dir.foreach(iconPath) do |f|
    if File::file?("#{iconPath}/#{f}")
      puts "del----#{iconPath}/#{f}"
      File::delete("#{iconPath}/#{f}")
    end
  end
  images = []
  Dir.foreach(oriIconPath) do |name|
    if name.include?('png')
      img_path = "#{oriIconPath}/#{name}"
      img = ChunkyPNG::Image.from_file(img_path)
      img_wid = img.dimension.width
      targetNames = iconNames[img_wid]
      if targetNames == nil 
        next
      end
      iconNames.delete(img_wid)
      targetNames.each do |targetName|
        puts targetName
        scale = "1x"
        if targetName.include?("x") 
          scale = /(?<=@).*?(?=.png)/.match(targetName).to_s
        end
        target_path = "#{iconPath}/#{targetName}"
        FileUtils.cp(img_path, target_path)
        puts scale.class
        size = img_wid / scale.to_i
        puts size
        puts size.class
        puts size.to_s == "1024"
        idiom = "iphone"
        if size.to_s == "1024"
          idiom = "ios-marketing"
        end
        puts idiom
        obj = {
          "filename" => targetName,
          "idiom" => idiom,
          "scale" => scale,
          "size" => "#{size}x#{size}",
        }
        images.push(obj)
        puts images
      end
    end
  end
  #写入json文件
  img_json = {
    "images" => images,
    "info" => {
      "version" => 1,
      "author" => "xcode"
    }
  }
  json_path = "#{iconPath}/Contents.json"
  File.open(json_path, 'w') do |f|
    f.write(img_json.to_json)
  end
end

#遍历一个文件夹
def browseImageDirectory(route, target_path)
  filepath = "images/other#{route}"
  puts filepath
  Dir.foreach(filepath) do |subPath|
    # puts subPath
    # puts File::directory?(subPath)
    if subPath != ".." && subPath != "."
      if subPath.include?(".imageset")
        puts subPath
         #删除原来的文件
        to_path = "#{target_path}#{route}/#{subPath}"
        puts to_path
        Dir.foreach(to_path) do |f|
          if File::file?("#{to_path}/#{f}")
            File::delete("#{to_path}/#{f}")
          end
        end
        #转移里面的image
        images = []
        Dir.foreach("#{filepath}/#{subPath}") do |file|
          if file.include?("@2x") || file.include?("@3x")
            puts file
            #替换图片
            FileUtils.cp("#{filepath}/#{subPath}/#{file}", "#{to_path}/#{file}")
            #拼凑json文件
            scale = /(?<=@).*?(?=.png)/.match(file)
            puts scale
            obj = {
              "idiom" => "universal",
              "filename" => file,
              "scale" => scale,
            }
            images.push(obj)
            puts images
          end
        end
        img_json = {
          "images" => images,
          "info" => {
            "version" => 1,
            "author" => "xcode"
          }
        }
        puts img_json
        #写入json文件
        json_path = "#{to_path}/Contents.json"
        File.open(json_path, 'w') do |f|
          f.write(img_json.to_json)
        end
      elsif File::directory?("#{filepath}/#{subPath}")
        #如果是文件夹 继续遍历
        browseImageDirectory("#{route}/#{subPath}", target_path)
      end
    end
  end
end

#替换其他图片 1.必须原工程中存在且文件夹名称相同 2.只替换2x 3x文件 
def updateOtherImages(path)
  browseImageDirectory("", path)
end

# icon等资源文件替换
def updateImages(path)
  puts "开始替换图片"
  puts path
  updateAppIcon("#{path}/AppIcon.appiconset")
  updateOtherImages(path)

  puts "替换图片结束"
end

# 判断证书类型 ad-hoc enterprise app-store
def judgeMobileProvisionType(path)
  provisionedDevices = %x(mobileprovision-read -f #{path} -o ProvisionedDevices).strip
  if provisionedDevices != ""
    return 'ad-hoc'
  end
  provisionsAllDevices = %x(mobileprovision-read -f #{path} -o ProvisionsAllDevices).strip
  if provisionsAllDevices != ""
    return 'enterprise'
  end
  return 'app-store'
end


def printInterestingLog()
  puts <<EOF
#                        .::::.
#                      .::::::::.
#                     :::::::::::
#                  ..:::::::::::'
#               '::::::::::::'
#                 .::::::::::
#            '::::::::::::::..
#                 ..::::::::::::.
#               ``::::::::::::::::
#                ::::``:::::::::'        .:::.
#               ::::'   ':::::'       .::::::::.
#             .::::'      ::::     .:::::::'::::.
#            .:::'       :::::  .:::::::::' ':::::.
#           .::'        :::::.:::::::::'      ':::::.
#          .::'         ::::::::::::::'         ``::::.
#      ...:::           ::::::::::::'              ``::.
#     ````':.          ':::::::::'                  ::::..
#                        '.:::::'                    ':'````..
#                     美女保佑 永无BUG
EOF
end