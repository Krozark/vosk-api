#!/bin/bash
# Installs a vosk wheel in a fresh virtualenv and transcribes python/example/test.wav with the
# small English model, then checks the start of the transcription.
# Needs a machine that can run the wheel (native platform).
#
# Usage: travis/smoke_test_wheel.sh <vosk wheel>
set -euo pipefail

WHEEL="$(realpath "${1:?usage: $0 <vosk wheel>}")"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
MODEL=vosk-model-small-en-us-0.15
# Same prefix as ios/test/smoke_test.sh: the tail varies slightly between versions
EXPECTED_PREFIX="one zero zero zero one nine oh two"

python3 -m venv "$WORK/venv"
"$WORK/venv/bin/python" -m pip install --quiet "$WHEEL"

curl -fsSL "https://alphacephei.com/vosk/models/$MODEL.zip" -o "$WORK/model.zip"
unzip -q "$WORK/model.zip" -d "$WORK"

# Run from a neutral folder so that the installed wheel is the one imported, not python/vosk
cd "$WORK"
text="$("$WORK/venv/bin/python" - "$WORK/$MODEL" "$ROOT/python/example/test.wav" <<'PY'
import json, sys, wave
from vosk import KaldiRecognizer, Model

model_dir, wav_path = sys.argv[1:]
with wave.open(wav_path, "rb") as wav:
    recognizer = KaldiRecognizer(Model(model_dir), wav.getframerate())
    while data := wav.readframes(4000):
        recognizer.AcceptWaveform(data)
print(json.loads(recognizer.FinalResult())["text"])
PY
)"
echo "transcription: $text"
case "$text" in
    "$EXPECTED_PREFIX"*) echo "OK" ;;
    *) echo "unexpected transcription (expected to start with: $EXPECTED_PREFIX)" >&2; exit 1 ;;
esac
