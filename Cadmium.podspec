Pod::Spec.new do |s|

  s.name         = "Cadmium"
  s.version      = "0.13.2"
  s.summary      = "Core Data framework for Swift that uses concise syntax to ensure best practices and protect you from common Core Data pitfalls"

  s.description  = <<-DESC
                   Core Data framework for Swift that uses concise syntax to ensure best practices and protect you from common Core Data pitfalls.
                   DESC

  s.homepage     = "https://github.com/jmfieldman/Cadmium"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Jason Fieldman" => "jason@fieldman.org" }
  s.social_media_url = 'http://fieldman.org'

  s.ios.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"
  #s.osx.deployment_target = "10.10"
  #s.tvos.deployment_target = "9.0"

  s.source = { :git => "https://github.com/jmfieldman/Cadmium.git", :tag => "#{s.version}" }
  s.source_files = "Cadmium/*.swift"

  s.requires_arc = true

  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.source_files = "Cadmium/*.swift"
    ss.frameworks = 'CoreData'
    ss.xcconfig = { 'SWIFT_VERSION' => '2.3' }
  end

  # -------------------------------------------------------------------------
  # 0.13.x targets swift 2.3, so all versions of promisekit must point to 3.5
  # -------------------------------------------------------------------------

  s.subspec 'PromiseKit' do |ss|
    ss.source_files = "Extensions/PromiseKit/*.swift"
    ss.weak_framework = 'PromiseKit'
    ss.dependency 'Cadmium/Core'
    ss.dependency 'PromiseKit', '~> 3.5'
  end

  s.subspec 'PromiseKit3' do |ss|
    ss.source_files = "Extensions/PromiseKit/*.swift"
    ss.weak_framework = 'PromiseKit'
    ss.dependency 'Cadmium/Core'
    ss.dependency 'PromiseKit', '~> 3.5'
  end

end
