#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint thermalprinter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'thermalprinter'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC A new Flutter plugin project. DESC
  s.homepage         = 'https://noel-s.com/porfolio/flutter/thermalprinter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Noel Silva' => 'hola@noel-s.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
