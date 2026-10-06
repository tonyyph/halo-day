#!/bin/bash
# Renders every widget kind × family and the Live Activity (WidgetGalleryTests) and exports the PNGs for review.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANGUAGE="${1:-en}"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/halo-day-widgets.XXXXXX")"
OUTPUT_DIR="$ROOT/docs/screenshots/v2/widgets/$LANGUAGE"
mkdir -p "$OUTPUT_DIR"
xcodebuild -project "$ROOT/HaloDay.xcodeproj" -scheme HaloDay \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:HaloDayTests/WidgetGalleryTests \
  -testLanguage "$LANGUAGE" -testRegion "$( [ "$LANGUAGE" = vi ] && echo VN || echo US )" \
  -resultBundlePath "$TEMP_DIR/Gallery.xcresult" CODE_SIGNING_ALLOWED=NO test >/dev/null
xcrun xcresulttool export attachments --path "$TEMP_DIR/Gallery.xcresult" --output-path "$TEMP_DIR/attachments" >/dev/null
ruby -rjson -rfileutils -e '
  attachments, output = ARGV
  manifest = JSON.parse(File.read(File.join(attachments, "manifest.json")))
  rows = (manifest.is_a?(Array) ? manifest : [manifest]).flat_map { |suite| suite.fetch("attachments", []) }
  rows.each do |row|
    name = row.fetch("suggestedHumanReadableName", "").sub(/_0_.*\z/, "")
    next unless name.match?(/\A(widget|lock|activity)-/)
    FileUtils.cp(File.join(attachments, row.fetch("exportedFileName")), File.join(output, "#{name}.png"))
  end
  puts "Exported #{Dir[File.join(output, "*.png")].size} images to #{output}"
' "$TEMP_DIR/attachments" "$OUTPUT_DIR"
