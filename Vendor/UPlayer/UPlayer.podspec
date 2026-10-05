Pod::Spec.new do |s|
  s.name = 'UPlayer'
  s.version = '1.0.69-nm7'
  s.summary = 'NM7 vendored MPEG-DASH to HLS player'
  s.homepage = 'https://github.com/MaximKomlev/UPlayer'
  s.license = { :type => 'MIT' }
  s.author = { 'Maxim Komleu' => 'komlev.maxim@gmail.com' }
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'
  s.source = { :path => '.' }
  s.source_files = 'Sources/UPlayer/**/*.{swift,h,m}'
  s.frameworks = ['UIKit','AVKit','CoreMedia','Foundation','AVFoundation','AudioToolbox']
  s.requires_arc = true
end
