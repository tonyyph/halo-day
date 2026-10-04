#!/usr/bin/env ruby
require 'json'
root = File.expand_path('..', __dir__)
# Mechanical extraction supplements Xcode's String Catalog extraction. Includes
# dynamic English keys (screen titles, enum labels and onboarding arrays).
keys = []
Dir.glob(File.join(root, '{HaloDayApp,HaloDayWidgets,Shared}', '**', '*.swift')).each do |path|
  source = File.read(path)
  source.scan(/"((?:[^"\\]|\\.)*)"/).flatten.each do |value|
    next if value.include?('\\(') || value.include?('\\n') || value.empty?
    next if value.match?(/\A[0-9A-F]{6}\z/) || value.match?(/\A[a-z0-9_.:\/-]+\z/)
    keys << value if value.match?(/[A-Z]/) || value.include?(' ')
  end
end
strings = keys.uniq.sort.to_h { |key| [key, { 'localizations' => { 'en' => { 'stringUnit' => { 'state' => 'translated', 'value' => key } } } }] }
path = File.join(root, 'HaloDayApp', 'Resources', 'Localizable.xcstrings')
File.write(path, JSON.pretty_generate({ 'sourceLanguage' => 'en', 'strings' => strings, 'version' => '1.0' }) + "\n")
puts "Generated #{strings.length} English entries"
