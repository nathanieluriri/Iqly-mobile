# Adds the IqlySurfaces widget extension to ios/Runner.xcodeproj, as
# ios/SURFACES_SETUP.md describes, so the project needs no hand edits in
# Xcode. Safe to run again: it stops when the target is already there.
#
#   gem install xcodeproj
#   ruby tool/ios_surfaces_target.rb

require 'xcodeproj'

IOS = File.expand_path('../ios', __dir__)
project = Xcodeproj::Project.open(File.join(IOS, 'Runner.xcodeproj'))
if project.targets.any? { |t| t.name == 'IqlySurfaces' }
  puts 'IqlySurfaces is already in the project.'
  exit
end

runner = project.targets.find { |t| t.name == 'Runner' }
# Flutter's xcconfig per configuration, as Runner uses them, so the
# extension carries the app's version and build number.
xcconfig = runner.build_configurations.to_h { |c| [c.name, c.base_configuration_reference] }

ext = project.new_target(:app_extension, 'IqlySurfaces', :ios, '16.1', nil, :swift)
unless ext.build_configurations.any? { |c| c.name == 'Profile' }
  release = ext.build_configurations.find { |c| c.name == 'Release' }
  profile = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  profile.name = 'Profile'
  profile.build_settings = Marshal.load(Marshal.dump(release.build_settings))
  ext.build_configuration_list.build_configurations << profile
end

ext.build_configurations.each do |config|
  config.base_configuration_reference = xcconfig.fetch(config.name)
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => 'net.iqly.app.IqlySurfaces',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'IqlySurfaces/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'CODE_SIGN_ENTITLEMENTS' => 'IqlySurfaces/IqlySurfaces.entitlements',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.1',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'SKIP_INSTALL' => 'YES',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => '',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks',
    ],
  )
end

group = project.main_group.new_group('IqlySurfaces', 'IqlySurfaces')
shared = group.new_group('Shared', 'Shared')
swift = Dir.children(File.join(IOS, 'IqlySurfaces')).select { |f| f.end_with?('.swift') }.sort
ext.add_file_references(swift.map { |f| group.new_reference(f) })
shared_ref = shared.new_reference('SurfaceShared.swift')
ext.add_file_references([shared_ref])
ext.add_resources([group.new_reference('Assets.xcassets')])
group.new_reference('Info.plist')
group.new_reference('IqlySurfaces.entitlements')

fonts = project.main_group.new_group('Fonts', '../assets/fonts')
ext.add_resources(
  %w[PlusJakartaSans-Regular.ttf PlusJakartaSans-SemiBold.ttf BricolageGrotesque-30pt.ttf]
    .map { |f| fonts.new_reference(f) },
)

surfaces = project.main_group.new_group('RunnerSurfaces', 'RunnerSurfaces')
runner.add_file_references([surfaces.new_reference('SurfacesChannel.swift'), shared_ref])

runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference, true)
  .settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# Before Thin Binary, or Xcode reports a dependency cycle.
thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
runner.build_phases.delete(embed)
runner.build_phases.insert(thin, embed)

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

project.save
puts 'Added IqlySurfaces.'
