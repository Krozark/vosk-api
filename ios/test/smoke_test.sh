#!/usr/bin/env bash
# Functional check of the iOS simulator libvosk: transcribe python/example/test.wav
# with the small English model inside an iOS Simulator and check the start of the transcription.
# Needs macOS + Xcode. No Mac or iPhone needed by the developer: runs on the GitHub runner.
#
# Usage: ios/test/smoke_test.sh <libvosk.xcframework>
set -euo pipefail

XCFRAMEWORK="$(cd "${1:?usage: $0 path/to/libvosk.xcframework}" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
WORK="$(mktemp -d)"
MODEL_NAME=vosk-model-small-en-us-0.15
# Start of the transcription obtained on Linux with vosk 0.3.45 and the same model/audio; the
# tail can vary slightly between versions, so only the prefix is compared.
EXPECTED_PREFIX="one zero zero zero one nine oh two"
SLICE="$XCFRAMEWORK/ios-arm64-simulator"

echo "== libvosk.dylib dependencies and exported API"
otool -L "$SLICE/libvosk.dylib"
nm -gU "$SLICE/libvosk.dylib" | grep -c ' _vosk_' | xargs echo "exported vosk_* symbols:"

curl -fsSL "https://alphacephei.com/vosk/models/$MODEL_NAME.zip" -o "$WORK/model.zip"
unzip -q "$WORK/model.zip" -d "$WORK"

sysroot="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator clang -target arm64-apple-ios13.0-simulator -isysroot "$sysroot" \
    -I "$SLICE/Headers" -o "$WORK/vosk_smoke" "$HERE/vosk_smoke.c" \
    "$SLICE/libvosk.dylib" -Wl,-rpath,"$SLICE"

runtime="$(xcrun simctl list runtimes -j | python3 -c \
  "import json,sys; print([r['identifier'] for r in json.load(sys.stdin)['runtimes'] if r['platform']=='iOS' and r['isAvailable']][-1])")"
udid="$(xcrun simctl create vosk-smoke "iPhone 15" "$runtime")"
trap 'xcrun simctl shutdown "$udid" 2>/dev/null || true; xcrun simctl delete "$udid"' EXIT
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b

output="$(xcrun simctl spawn "$udid" "$WORK/vosk_smoke" "$WORK/$MODEL_NAME" "$ROOT/python/example/test.wav")"
echo "$output"
text="$(echo "$output" | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['text'])")"

if [[ "$text" != "$EXPECTED_PREFIX"* ]]; then
    echo "::error::unexpected transcription: '$text' (expected to start with '$EXPECTED_PREFIX')"
    exit 1
fi
echo "OK: libvosk transcribes correctly inside the iOS Simulator"
