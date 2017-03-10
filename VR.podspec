
Pod::Spec.new do |s|

  s.name         = "VR"
  s.version      = "0.0.1"
  s.summary      = "VR全景图片浏览."

  s.homepage     = "https://github.com/cleven1/VRPanorama.git"

  s.license      = "MIT"

  s.author             = { "yongqiang.zhao@camdora.me" => "yongqiang.zhao@camdora.me" }

  s.source       = { :git => "https://github.com/cleven1/VRPanorama.git", :tag => "#{s.version}" }
  s.platform     = :ios, '8.0'

  s.source_files  = "VR全景图片浏览/*"

  s.requires_arc = true



end
