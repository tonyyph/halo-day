#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_NAME="Halo Day Screenshots"
RUNTIME_ID="$(xcrun simctl list runtimes | awk -F' - ' '/iOS 26\.4/ { print $NF; exit }')"
DEVICE_TYPE_ID="$(xcrun simctl list devicetypes | awk -F'[()]' '/iPhone 17 Pro \(/ { print $2; exit }')"

SIMULATOR_ID="$(xcrun simctl list devices available --json | ruby -rjson -e '
  devices = JSON.parse(STDIN.read).fetch("devices").values.flatten
  puts devices.find { |device| device["name"] == ARGV[0] && device["isAvailable"] }&.fetch("udid", "")
' "$DEVICE_NAME")"

if [[ -z "$SIMULATOR_ID" ]]; then
  [[ -n "$RUNTIME_ID" && -n "$DEVICE_TYPE_ID" ]] || {
    echo "iOS 26.4 iPhone 17 Pro simulator runtime is not installed." >&2
    exit 1
  }
  SIMULATOR_ID="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE_ID" "$RUNTIME_ID")"
fi

xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl status_bar "$SIMULATOR_ID" override \
  --time "10:05" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/halo-day-screenshots.XXXXXX")"
RESULT_BUNDLE="$TEMP_DIR/HaloDay-Screenshots.xcresult"
ATTACHMENTS="$TEMP_DIR/attachments"
OUTPUT_DIR="$ROOT/docs/screenshots"
mkdir -p "$OUTPUT_DIR"

xcodebuild -project "$ROOT/HaloDay.xcodeproj" -scheme HaloDay \
  -destination "id=$SIMULATOR_ID" \
  -only-testing:HaloDayUITests/HaloDayUITests/testScreenshotMatrix \
  -resultBundlePath "$RESULT_BUNDLE" CODE_SIGNING_ALLOWED=NO test

xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$ATTACHMENTS"
ruby -rjson -rfileutils -e '
  root, attachments, output = ARGV
  manifest = JSON.parse(File.read(File.join(attachments, "manifest.json")))
  suites = manifest.is_a?(Array) ? manifest : [manifest]
  rows = suites.flat_map { |suite| suite.fetch("attachments", []) }
  count = 0
  rows.each do |row|
    name = row.fetch("suggestedHumanReadableName", "")
    match = name.match(/\A(en|vi)-(Pearl|Ruby|MidnightGold)-(Today|Calendar|Studio|Rituals|Focus|Settings|Themes|Paywall|Onboarding)_0_.*\.png\z/)
    next unless match
    source = File.join(attachments, row.fetch("exportedFileName"))
    destination = File.join(output, "#{match[1]}-#{match[2]}-#{match[3]}.png")
    FileUtils.cp(source, destination)
    count += 1
  end
  abort "Expected 54 screenshots, exported #{count}." unless count == 54
  puts "Exported #{count} screenshots to #{output}"
' "$ROOT" "$ATTACHMENTS" "$OUTPUT_DIR"
