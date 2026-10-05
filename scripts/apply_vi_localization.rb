#!/usr/bin/env ruby
require 'json'

root = File.expand_path('..', __dir__)
catalog_path = File.join(root, 'HaloDayApp/Resources/Localizable.xcstrings')
translations_path = File.join(__dir__, 'vi_translations.json')
catalog = JSON.parse(File.read(catalog_path))
translations = JSON.parse(File.read(translations_path))

unknown = translations.keys - catalog.fetch('strings').keys
abort "Unknown localization keys: #{unknown.join(', ')}" unless unknown.empty?

translations.each do |key, value|
  source_formats = key.scan(/%(?:\d+\$)?(?:lld|@)/).map { |item| item.sub(/\A%\d+\$/, '%') }.sort
  target_formats = value.scan(/%(?:\d+\$)?(?:lld|@)/).map { |item| item.sub(/\A%\d+\$/, '%') }.sort
  abort "Placeholder mismatch: #{key}" unless source_formats == target_formats
  catalog['strings'].fetch(key)['localizations'] ||= {}
  catalog['strings'].fetch(key)['localizations']['vi'] = {
    'stringUnit' => { 'state' => 'translated', 'value' => value }
  }
end

catalog['sourceLanguage'] = 'vi'
output = JSON.pretty_generate(catalog)
output = output.gsub(/"(?=:)/, '" ')
output = output.gsub(/^(\s*)("[^"]+" : )\{\}(,?)$/) do
  "#{$1}#{$2}{\n\n#{$1}}#{$3}"
end
File.write(catalog_path, output + "\n")
puts "Applied #{translations.length} Vietnamese translations."
