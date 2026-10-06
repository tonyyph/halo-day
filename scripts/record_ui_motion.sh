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

OUTPUT_DIR="$ROOT/docs/screenshots"
mkdir -p "$OUTPUT_DIR"

record_case() {
  local test_name="$1"
  local output_name="$2"
  local result_bundle="$3"
  local recorder_pid

  xcrun simctl io "$SIMULATOR_ID" recordVideo "$OUTPUT_DIR/$output_name" &
  recorder_pid=$!
  set +e
  xcodebuild -project "$ROOT/HaloDay.xcodeproj" -scheme HaloDay \
    -destination "id=$SIMULATOR_ID" \
    -only-testing:"HaloDayUITests/HaloDayUITests/$test_name" \
    -resultBundlePath "$result_bundle" CODE_SIGNING_ALLOWED=NO test
  local test_status=$?
  set -e
  kill -INT "$recorder_pid" 2>/dev/null || true
  wait "$recorder_pid" 2>/dev/null || true
  return "$test_status"
}

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/halo-day-recordings.XXXXXX")"
record_case testRecordOnboardingMotion onboarding.mp4 "$TEMP_DIR/Onboarding.xcresult"
record_case testRecordStudioThemeAndTypeSwitching studio-theme-type.mp4 "$TEMP_DIR/Studio.xcresult"
record_case testRecordFinalRitualCompletion ritual-complete.mp4 "$TEMP_DIR/Rituals.xcresult"

echo "Saved onboarding, Studio, and Rituals recordings to $OUTPUT_DIR"
