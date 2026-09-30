#!/bin/bash
# Turns the artifacts of a build (one folder per artifact) into GitHub release assets:
# every wheel as is, and one zip per artifact with its libvosk binaries (and vosk_api.h).
#
# Usage: package-release.sh <artifacts_dir> <assets_dir>
set -euo pipefail

ARTIFACTS="${1:?usage: $0 <artifacts_dir> <assets_dir>}"
ASSETS="$(realpath -m "${2:?usage: $0 <artifacts_dir> <assets_dir>}")"

mkdir -p "$ASSETS"
find "$ARTIFACTS" -name '*.whl' -exec cp -t "$ASSETS" {} +

for dir in "$ARTIFACTS"/*/; do
    name="$(basename "$dir")"
    (cd "$dir" && zip -qr "$ASSETS/$name.zip" . -x '*.whl')
done

ls -lh "$ASSETS"
