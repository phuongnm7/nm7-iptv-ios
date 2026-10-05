Pod::Spec.new do |s|
  s.name = 'UPlayer'
  s.version = '1.0.69-nm7'
  s.summary = 'NM7 vendored MPEG-DASH to HLS player'
  s.homepage = 'https://github.com/MaximKomlev/UPlayer'
  s.license = { :type => 'MIT' }
  s.author = { 'Maxim Komleu' => 'Maxim Komleu' }
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'
  s.source = { :git => 'https://github.com/MaximKomlev/UPlayer.git', :commit => 'ba490354f8bf3e60d95d564e4f488e676d4ce227' }
  s.source_files = 'Sources/UPlayer/**/*.{swift,h,m}'
  s.frameworks = ['UIKit','AVKit','CoreMedia','Foundation','AVFoundation','AudioToolbox']
  s.requires_arc = true
end
