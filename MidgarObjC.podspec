Pod::Spec.new do |s|
  s.name             = 'MidgarObjC'
  s.version          = '0.1.4'
  s.summary          = 'Midgar Objective-C SDK for Lazy Lantern.'
  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC
  s.homepage         = 'https://github.com/lazylantern/midgar-objc'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = { 'bastienbeurier' => 'bastienbeurier@gmail.com' }
  s.source           = { :git => 'https://github.com/lazylantern/midgar-objc.git', :tag => s.version.to_s }
  s.ios.deployment_target = '10.0'
  s.source_files = 'MidgarObjC/Classes/**/*'
end
