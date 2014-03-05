Pod::Spec.new do |s|
  s.name          = "Unrar4iOS"
  s.version       = "1.0.0"
  s.summary       = "Provides a port of Unrar library to iOS platform"
  s.license       = "BSD"
  s.homepage      = "https://github.com/ararog/Unrar4iOS"
  s.author        = { "Vicent Scott" => "vkan388@gmail.com" }
  s.source        = { :git => "https://github.com/ararog/Unrar4iOS", :commit => "2723b8ab51" }
  s.source_files  = "Unrar4iOS/*.{mm,m,h}",
                    "Unrar4iOS/unrar/*.{cpp,hpp}"
  s.exclude_files = "Unrar4iOS/unrar/beosea.cpp",
                    "Unrar4iOS/unrar/coder.cpp",
                    "Unrar4iOS/unrar/log.cpp",
                    "Unrar4iOS/unrar/model.cpp",
                    "Unrar4iOS/unrar/os2ea.cpp",
                    "Unrar4iOS/unrar/rarpch.cpp",
                    "Unrar4iOS/unrar/rarvmtbl.cpp",
                    "Unrar4iOS/unrar/suballoc.cpp",
                    "Unrar4iOS/unrar/unios2.cpp",
                    "Unrar4iOS/unrar/unpack{15,20}.cpp",
                    "Unrar4iOS/unrar/uowners.cpp",
                    "Unrar4iOS/unrar/win32acl.cpp",
                    "Unrar4iOS/unrar/win32stm.cpp"
  s.xcconfig     =  { "OTHER_CFLAGS" => "$(inherited) -Wno-return-type -Wno-logical-op-parentheses -Wno-conversion -Wno-parentheses -Wno-unused-function -Wno-unused-variable -Wno-switch",
                      "OTHER_CPLUSPLUSFLAGS" => "$(inherited) -DSILENT -DRARDLL $(OTHER_CFLAGS)" }
  s.ios.deployment_target = "3.0"
  s.osx.deployment_target = "10.6"
end
