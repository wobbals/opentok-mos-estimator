#
# Be sure to run `pod lib lint OpenTokMOS.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'OpenTokMOS'
  s.version          = '0.1.0'
  s.summary          = 'MOS estimator for OpenTok subscribers'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Subscriber media quality scores can be estimated in real-time throughout the
life of the subscriber, or accumulated once at the end of the subscriber.
By using the network stats callbacks, this project aims to produce a simple
module that can extend the functionality of the subscriber with a simple
quality score.
                       DESC

  s.homepage         = 'https://github.com/wobbals/opentok-mos-estimator'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'Charley Robinson' => 'charley@tokbox.com' }
  s.source           = { :git => 'https://github.com/wobbals/opentok-mos-estimator', :branch => 'master' }

  s.ios.deployment_target = '10.0'

  s.source_files = 'OpenTokMOS/OpenTokMOS/Classes/**/*'
  
  # s.resource_bundles = {
  #   'OpenTokMOS' => ['OpenTokMOS/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'OpenTok', '>= 2.9'
end
