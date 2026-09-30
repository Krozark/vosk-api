#!/usr/bin/env bash
# Build libvosk (dynamic libvosk.dylib, Accelerate) for Apple platforms:
#   - iOS device + simulator (arm64) -> libvosk.xcframework
#   - macOS arm64 + x86_64           -> macos/libvosk.dylib (universal2)
#
# Mirrors vosk-api/android/lib/build-vosk.sh, but uses the `--ios` mode of Alpha
# Cephei's Kaldi fork (Apple Accelerate instead of OpenBLAS/CLAPACK; Kaldi/OpenFst are static and linked into libvosk.dylib).
# Needs macOS + Xcode + `brew install autoconf automake libtool`.
#
# Kaldi's `--ios` mode (Accelerate, no SSE flags) is used for the macOS slices too: it is the
# Darwin configuration minus the x86-only options.
#
# Usage: [SLICES="device simulator"] ios/build_libvosk.sh [output_dir]
#        SLICES: any of device, simulator (iOS) and macos-arm64, macos-x86_64 (macOS)
#        (default output: build/ios-libvosk, relative to the current directory; SLICES=simulator halves the build time)
set -euo pipefail

KALDI_REF="${KALDI_REF:-vosk-android}" # TODO: pin to a commit once a build is known good
OPENFST_VERSION=1.8.0
IOS_MIN=13.0
MACOS_MIN_ARM64=11.0 # first macOS with Apple silicon
MACOS_MIN_X86_64=10.15

HERE="$(cd "$(dirname "$0")" && pwd)"
VOSK_SRC="$HERE/../src" # this repository's libvosk sources
OUT="$(mkdir -p "${1:-build/ios-libvosk}" && cd "${1:-build/ios-libvosk}" && pwd)"
JOBS="$(sysctl -n hw.ncpu)"

build_slice() {
    local name=$1 sdk=$2 target=$3 host=$4
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
            --host="$host" --build="$(uname -m)-apple-darwin" &&
        make -j"$JOBS" && make install)

    # Kaldi (only the libraries libvosk needs)
    git clone --depth 1 -b "$KALDI_REF" --single-branch https://github.com/alphacep/kaldi "$w/kaldi"
    (cd "$w/kaldi/src" &&
        CXX="$cxx" AR="$(xcrun --sdk "$sdk" -f ar)" RANLIB="$(xcrun --sdk "$sdk" -f ranlib)" \
        CXXFLAGS="-O3 -DFST_NO_DYNAMIC_LINKING" ./configure --use-cuda=no --ios=true \
            --host="$host" --fst-root="$w/local" --fst-version="$OPENFST_VERSION" &&
        make -j"$JOBS" depend && make -j"$JOBS" online2 rnnlm)

    # libvosk.dylib = vosk objects + all Kaldi/OpenFst archives
    make -C "$VOSK_SRC" -f "$HERE/libvosk_dylib.mk" all \
        VOSK_SRC="$VOSK_SRC" OUTDIR="$w/vosk" EXT=dylib \
        KALDI_ROOT="$w/kaldi" OPENFST_ROOT="$w/local" \
        HAVE_OPENBLAS_CLAPACK=0 HAVE_ACCELERATE=1 \
        CXX="$cxx" EXTRA_CFLAGS="-DHAVE_CLAPACK"
}

# "<sdk> <clang target> <autotools host>"
slice_spec() {
    case $1 in
        device) echo "iphoneos arm64-apple-ios$IOS_MIN aarch64-apple-darwin" ;;
        simulator) echo "iphonesimulator arm64-apple-ios$IOS_MIN-simulator aarch64-apple-darwin" ;;
        macos-arm64) echo "macosx arm64-apple-macos$MACOS_MIN_ARM64 aarch64-apple-darwin" ;;
        macos-x86_64) echo "macosx x86_64-apple-macos$MACOS_MIN_X86_64 x86_64-apple-darwin" ;;
        *) echo "unknown slice '$1' (expected: device, simulator, macos-arm64, macos-x86_64)" >&2; exit 1 ;;
    esac
}

mkdir -p "$OUT/headers" && cp "$VOSK_SRC/vosk_api.h" "$OUT/headers/"
xcframework_args=()
macos_dylibs=()
for slice in ${SLICES:-device simulator}; do
    # shellcheck disable=SC2046 # slice_spec yields "<sdk> <target> <host>"
    build_slice "$slice" $(slice_spec "$slice")
    case $slice in
        macos-*) macos_dylibs+=("$OUT/$slice/vosk/libvosk.dylib") ;;
        *) xcframework_args+=(-library "$OUT/$slice/vosk/libvosk.dylib" -headers "$OUT/headers") ;;
    esac
done

if [ ${#xcframework_args[@]} -gt 0 ]; then
    rm -rf "$OUT/libvosk.xcframework"
    xcodebuild -create-xcframework "${xcframework_args[@]}" -output "$OUT/libvosk.xcframework"
fi

if [ ${#macos_dylibs[@]} -gt 0 ]; then
    mkdir -p "$OUT/macos"
    lipo -create "${macos_dylibs[@]}" -output "$OUT/macos/libvosk.dylib"
    cp "$OUT/headers/vosk_api.h" "$OUT/macos/"
    lipo -info "$OUT/macos/libvosk.dylib"
fi
