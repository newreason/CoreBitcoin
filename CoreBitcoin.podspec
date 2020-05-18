Pod::Spec.new do |s|
  s.name         = "CoreLitecoin"
  s.version      = "0.0.1"
  s.summary      = "CoreLitecoin is an implementation of Bitcoin protocol in Objective-C."
  s.description  = <<-DESC
                   CoreLitecoin is a complete toolkit to work with Litecoin data structures.
                   DESC
  s.homepage     = "https://github.com/newreason/CoreLitecoin"
  s.license      = 'WTFPL'
  s.author       = { "Alexander Yeskin" => "a.eskin@pixelplex.io" }
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.9'
  s.source       = { :git => "https://github.com/newreason/CoreLitecoin.git", :tag => s.version.to_s }
  s.source_files = 'CoreLitecoin'
  s.exclude_files = ['CoreLitecoin/**/*+Tests.{h,m}', 'CoreLitecoin/LTCScriptTestData.h']
  s.requires_arc = true
  s.framework    = 'Foundation'
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  s.dependency 'OpenSSL-Universal', '1.0.1.16'
  s.dependency 'ISO8601DateFormatter'
end
