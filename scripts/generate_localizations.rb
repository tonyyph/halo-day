#!/usr/bin/env ruby
require 'json'
root = File.expand_path('..', __dir__)
path = File.join(root, 'HaloDayApp', 'Resources', 'Localizable.xcstrings')
existing = File.exist?(path) ? JSON.parse(File.read(path)) : { 'strings' => {} }
# Recover translations if a previous extraction produced an English-only catalog.
if existing.fetch('strings', {}).values.none? { |entry| entry.fetch('localizations', {}).key?('vi') }
  baseline = IO.popen(['git', 'show', 'HEAD:HaloDayApp/Resources/Localizable.xcstrings'], chdir: root, &:read)
  existing = JSON.parse(baseline) unless baseline.empty?
end
# Mechanical extraction supplements Xcode's String Catalog extraction. Includes
# dynamic English keys (screen titles, enum labels and onboarding arrays).
keys = []
# The manifest preserves explicit dynamic keys (including printf placeholders)
# that the mechanical Swift scanner cannot infer without type information.
manifest = File.join(__dir__, 'vi_translations.json')
keys.concat(JSON.parse(File.read(manifest)).keys) if File.exist?(manifest)
Dir.glob(File.join(root, '{HaloDayApp,HaloDayWidgets,Shared}', '**', '*.swift')).each do |path|
  source = File.read(path)
  source.scan(/"((?:[^"\\]|\\.)*)"/).flatten.each do |value|
    next if value.include?('\\(') || value.include?('\\n') || value.empty?
    next if value.match?(/\A[0-9A-F]{6}\z/) || value.match?(/\A[a-z0-9_.:\/-]+\z/)
    keys << value if value.match?(/[A-Z]/) || value.include?(' ')
  end
end
strings = existing.fetch('strings', {})
keys.uniq.each do |key|
  strings[key] ||= { 'localizations' => {} }
  strings[key]['localizations'] ||= {}
  strings[key]['localizations']['en'] = {
    'stringUnit' => { 'state' => 'translated', 'value' => key }
  }
end
File.write(path, JSON.pretty_generate({ 'sourceLanguage' => 'vi', 'strings' => strings.sort.to_h, 'version' => '1.0' }) + "\n")
puts "Generated #{strings.length} English entries"
