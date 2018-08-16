Pod::Spec.new do |s|

s.name         = "YGIAPHelper"
s.version      = "1.0.5"
s.summary      = "iOS 内购/恢复购买"
s.homepage     = "https://github.com/Starryxu/YGIAPHelper.git"
s.license      = { :type => "MIT", :file => "LICENSE" }
s.author       = { "xuyaguang" => "xu_yaguang@163.com" }
s.platform     = :ios, "8.0"
s.source       = { :git => "https://github.com/Starryxu/YGIAPHelper.git", :tag => s.version.to_s }
s.source_files = "YGIAPHelper/YGIAPHelper/*.{h,m}"
s.requires_arc = true
s.frameworks   = 'StoreKit'

end
