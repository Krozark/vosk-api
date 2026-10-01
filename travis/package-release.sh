#!/bin/bash
# Turns the artifacts of a build (one folder per artifact) into GitHub release assets:
# the wheels, and one zip per artifact with its libvosk binaries (and vosk_api.h).
#
# Wheels that must not be published:
#  - those of the MKL build: same name as the OpenBLAS wheel of the same platform (only its
#    libvosk, in the zip, is published);
#  - the plain linux_<arch> wheel when auditwheel produced a manylinux one next to it.
#
# Usage: package-release.sh <artifacts_dir> <assets_dir>
set -euo pipefail

ARTIFACTS="${1:?usage: $0 <artifacts_dir> <assets_dir>}"
ASSETS="$(realpath -m "${2:?usage: $0 <artifacts_dir> <assets_dir>}")"

mkdir -p "$ASSETS"

for dir in "$ARTIFACTS"/*/; do
    name="$(basename "$dir")"
    (cd "$dir" && zip -qr "$ASSETS/$name.zip" . -x '*.whl')

    case $name in *-mkl) continue ;; esac
    wheels=("$dir"*.whl)
    [ -e "${wheels[0]}" ] || continue
    for wheel in "${wheels[@]}"; do
        case $wheel in *-linux_*.whl) ls "$dir"*manylinux*.whl >/dev/null 2>&1 && continue ;; esac
        if [ -e "$ASSETS/$(basename "$wheel")" ]; then
            echo "two wheels are named $(basename "$wheel")" >&2
            exit 1
        fi
        cp "$wheel" "$ASSETS/"
    done
done

ls -lh "$ASSETS"
