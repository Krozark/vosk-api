#!/usr/bin/env bash
# Build libvosk.xcframework (static, Accelerate) for iOS device + simulator (arm64).
#
# Mirrors vosk-api/android/lib/build-vosk.sh, but uses the `--ios` mode of Alpha
# Cephei's Kaldi fork (static libs, Apple Accelerate instead of OpenBLAS/CLAPACK).
# Needs macOS + Xcode + `brew install autoconf automake libtool`.
#
# Usage: [SLICES="device simulator"] ios/build_libvosk.sh [output_dir]
#        (default output: build/ios-libvosk, relative to the current directory; SLICES=simulator halves the build time)
set -euo pipefail

KALDI_REF="${KALDI_REF:-vosk-android}" # TODO: pin to a commit once a build is known good
OPENFST_VERSION=1.8.0
IOS_MIN=13.0

HERE="$(cd "$(dirname "$0")" && pwd)"
VOSK_SRC="$HERE/../src" # this repository's libvosk sources
OUT="$(mkdir -p "${1:-build/ios-libvosk}" && cd "${1:-build/ios-libvosk}" && pwd)"
JOBS="$(sysctl -n hw.ncpu)"
HOST=aarch64-apple-darwin

build_slice() {
    local name=$1 sdk=$2 target=$3
    local sysroot cc cxx w="$OUT/$name"
    sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
    cc="$(xcrun --sdk "$sdk" -f clang) -target $target -isysroot $sysroot"
    cxx="$(xcrun --sdk "$sdk" -f clang++) -target $target -isysroot $sysroot"
    mkdir -p "$w/local" "$w/vosk"

    # OpenFst (static only)
    git clone --depth 1 https://github.com/alphacep/openfst "$w/openfst"
    (cd "$w/openfst" && LIBTOOLIZE=glibtoolize autoreconf -i &&
        CC="$cc" CXX="$cxx" CXXFLAGS="-O3 -DFST_NO_DYNAMIC_LINKING" ./configure \
            --prefix="$w/local" --enable-static --disable-shared --with-pic --disable-bin \
            --enable-lookahead-fsts --enable-ngram-fsts \
            --host="$HOST" --build="$(uname -m)-apple-darwin" &&
        make -j"$JOBS" && make install)

    # Kaldi (only the libraries libvosk needs)
    git clone --depth 1 -b "$KALDI_REF" --single-branch https://github.com/alphacep/kaldi "$w/kaldi"
    (cd "$w/kaldi/src" &&
        CXX="$cxx" AR="$(xcrun --sdk "$sdk" -f ar)" RANLIB="$(xcrun --sdk "$sdk" -f ranlib)" \
        CXXFLAGS="-O3 -DFST_NO_DYNAMIC_LINKING" ./configure --use-cuda=no --ios=true \
            --host="$HOST" --fst-root="$w/local" --fst-version="$OPENFST_VERSION" &&
        make -j"$JOBS" depend && make -j"$JOBS" online2 rnnlm)

    # libvosk.a = vosk objects + all Kaldi/OpenFst archives
    make -C "$VOSK_SRC" -f "$HERE/libvosk_static.mk" libvosk.a \
        VOSK_SRC="$VOSK_SRC" OUTDIR="$w/vosk" EXT=a \
        KALDI_ROOT="$w/kaldi" OPENFST_ROOT="$w/local" \
        HAVE_OPENBLAS_CLAPACK=0 HAVE_ACCELERATE=1 \
        CXX="$cxx" EXTRA_CFLAGS="-DHAVE_CLAPACK"
}

slice_spec() {
    case $1 in
        device) echo "iphoneos arm64-apple-ios$IOS_MIN" ;;
        simulator) echo "iphonesimulator arm64-apple-ios$IOS_MIN-simulator" ;;
        *) echo "unknown slice '$1' (expected: device, simulator)" >&2; exit 1 ;;
    esac
}

mkdir -p "$OUT/headers" && cp "$VOSK_SRC/vosk_api.h" "$OUT/headers/"
xcframework_args=()
for slice in ${SLICES:-device simulator}; do
    # shellcheck disable=SC2046 # slice_spec yields "<sdk> <target>"
    build_slice "$slice" $(slice_spec "$slice")
    xcframework_args+=(-library "$OUT/$slice/vosk/libvosk.a" -headers "$OUT/headers")
done

rm -rf "$OUT/libvosk.xcframework"
xcodebuild -create-xcframework "${xcframework_args[@]}" -output "$OUT/libvosk.xcframework"
