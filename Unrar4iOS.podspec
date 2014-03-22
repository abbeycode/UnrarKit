Pod::Spec.new do |s|
  s.name          = "Unrar4iOS"
  s.version       = "1.1.0"
  s.summary       = "Provides a port of Unrar library to iOS and Mac platforms"
  s.license       = "BSD"
  s.homepage      = "https://github.com/abbeycode/Unrar4iOS"
  s.author        = { "Dov Frankel" => "dov@abbey-code.com" }
  s.source        = { :git => "https://github.com/abbeycode/Unrar4iOS.git", :tag => "2.0.0" }
  s.source_files  = "Classes/*.{mm,m,h}",
                    "Libraries/unrar/*.{cpp,hpp}",
                    "Resources/ExcludedBuildFiles.txt"
  s.exclude_files = "Libraries/unrar/beosea.cpp",
                    "Libraries/unrar/os2ea.cpp",
                    "Libraries/unrar/rarpch.cpp",
                    "Libraries/unrar/unios2.cpp",
                    "Libraries/unrar/win32acl.cpp",
                    "Libraries/unrar/win32stm.cpp"
  s.xcconfig     =  { "OTHER_CFLAGS" => "$(inherited) -Wno-return-type -Wno-logical-op-parentheses -Wno-conversion -Wno-parentheses -Wno-unused-function -Wno-unused-variable -Wno-switch",
                      "OTHER_CPLUSPLUSFLAGS" => "$(inherited) -DSILENT -DRARDLL $(OTHER_CFLAGS)" }
  s.ios.deployment_target = "3.0"
  s.osx.deployment_target = "10.6"
end
