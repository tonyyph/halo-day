#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'
require 'digest'

class HaloProject < Xcodeproj::Project
  def generate_uuid
    @halo_object_counter = (@halo_object_counter || 0) + 1
    Digest::SHA256.hexdigest("HaloDay-object-#{@halo_object_counter}")[0, 24].upcase
  end
end
root = File.expand_path('..', __dir__)
project_path = File.join(root, 'HaloDay.xcodeproj')
preserved_teams = {}
if File.exist?(File.join(project_path, 'project.pbxproj'))
  existing = Xcodeproj::Project.open(project_path)
  existing.targets.each do |target|
    target.build_configurations.each do |configuration|
      team = configuration.build_settings['DEVELOPMENT_TEAM']
      preserved_teams[[target.name, configuration.name]] = team if team
    end
  end
end
project = HaloProject.new(project_path)
project.root_object.development_region = 'vi'
app = project.new_target(:application, 'HaloDay', :ios, '18.0')
widgets = project.new_target(:app_extension, 'HaloDayWidgets', :ios, '18.0')
tests = project.new_target(:unit_test_bundle, 'HaloDayTests', :ios, '18.0')
ui_tests = project.new_target(:ui_test_bundle, 'HaloDayUITests', :ios, '18.0')
app.add_dependency(widgets)
tests.add_dependency(app)
ui_tests.add_dependency(app)
[[app, 'HaloDayApp'], [widgets, 'HaloDayWidgets'], [tests, 'HaloDayTests'], [ui_tests, 'HaloDayUITests']].each do |target, folder|
  group = project.main_group.new_group(folder, folder)
  Dir.glob(File.join(root, folder, '**', '*')).select { |f| File.file?(f) }.sort.each do |file|
    relative = file.delete_prefix(File.join(root, folder) + '/')
    ref = group.new_file(relative)
    if file.end_with?('.swift')
      target.source_build_phase.add_file_reference(ref)
    elsif file.end_with?('.xcstrings', '.storekit', '.xcprivacy')
      target.resources_build_phase.add_file_reference(ref) unless file.end_with?('.storekit')
    end
  end
end
assets = project.main_group.new_file('HaloDayApp/Resources/Assets.xcassets')
app.resources_build_phase.add_file_reference(assets)
shared = project.main_group.new_group('Shared', 'Shared')
catalog = project.main_group.new_file('HaloDayApp/Resources/Localizable.xcstrings')
widgets.resources_build_phase.add_file_reference(catalog)
storekit_file = project.main_group.new_file('HaloDayApp/Resources/HaloDay.storekit')
ui_tests.resources_build_phase.add_file_reference(storekit_file)
tests.resources_build_phase.add_file_reference(storekit_file)
Dir.glob(File.join(root, 'Shared', '**', '*.swift')).sort.each do |file|
  ref = shared.new_file(file.delete_prefix(File.join(root, 'Shared') + '/'))
  [app, widgets].each { |target| target.source_build_phase.add_file_reference(ref) }
end
embed = app.new_copy_files_build_phase('Embed App Extensions')
embed.dst_subfolder_spec = '13'
embedded = embed.add_file_reference(widgets.product_reference)
embedded.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
project.targets.each do |target|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings['SWIFT_VERSION'] = '6.0'
    settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
    settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
    settings['TARGETED_DEVICE_FAMILY'] = '1'
    settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    settings['MARKETING_VERSION'] = '1.0'
    settings['CURRENT_PROJECT_VERSION'] = '3'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    # Preserve Xcode's account selection; the fallback is the pre-polish project team.
    team = preserved_teams[[target.name, config.name]]
    team ||= 'YC5GD8U2GQ' if target == app || target == widgets
    settings['DEVELOPMENT_TEAM'] = team if team
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = target == app ? 'co.haloday.app' : target == widgets ? 'co.haloday.app.widgets' : 'co.haloday.app.tests'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    if target == app
      settings['INFOPLIST_FILE'] = 'HaloDayApp/Resources/Info.plist'
      settings['CODE_SIGN_ENTITLEMENTS'] = 'HaloDayApp/HaloDay.entitlements'
      settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
    elsif target == widgets
      settings['INFOPLIST_FILE'] = 'HaloDayWidgets/Info.plist'
      settings['CODE_SIGN_ENTITLEMENTS'] = 'HaloDayWidgets/HaloDayWidgets.entitlements'
      settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      settings['SKIP_INSTALL'] = 'YES'
    elsif target == tests
      settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/HaloDay.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/HaloDay'
      settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    else
      settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'co.haloday.app.uitests'
      settings['TEST_TARGET_NAME'] = 'HaloDay'
    end
  end
end
project.predictabilize_uuids
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.add_test_target(ui_tests)
scheme.set_launch_target(app)
storekit = scheme.launch_action.xml_element.add_element('StoreKitConfigurationFileReference')
storekit.add_attribute('identifier', '../HaloDayApp/Resources/HaloDay.storekit')
scheme.save_as(File.join(root, 'HaloDay.xcodeproj'), 'HaloDay', true)
puts 'Generated HaloDay.xcodeproj'
