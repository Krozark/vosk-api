# Vosk Speech Recognition Toolkit

Vosk is an offline open source speech recognition toolkit. It enables
speech recognition for 20+ languages and dialects - English, Indian
English, German, French, Spanish, Portuguese, Chinese, Russian, Turkish,
Vietnamese, Italian, Dutch, Catalan, Arabic, Greek, Farsi, Filipino,
Ukrainian, Kazakh, Swedish, Japanese, Esperanto, Hindi, Czech, Polish.
More to come.

Vosk models are small (50 Mb) but provide continuous large vocabulary
transcription, zero-latency response with streaming API, reconfigurable
vocabulary and speaker identification.

Speech recognition bindings implemented for various programming languages
like Python, Java, Node.JS, C#, C++, Rust, Go and others.

Vosk supplies speech recognition for chatbots, smart home appliances,
virtual assistants. It can also create subtitles for movies,
transcription for lectures and interviews.

Vosk scales from small devices like Raspberry Pi or Android smartphone to
big clusters.

# Prebuilt binaries (this fork)

This fork builds the **same Vosk sources for every platform** (one version everywhere) in
[GitHub Actions](.github/workflows/build.yml) and publishes the result in the
[releases](https://github.com/Krozark/vosk-api/releases): Python wheels, `libvosk` for every
platform, an Android library and an iOS xcframework.

## Install with pip

The wheels are listed in a pip index, so pip (or uv) picks the one that matches the machine:

```
pip install vosk==0.3.75 --extra-index-url https://krozark.github.io/vosk-api/simple/
```

Use `--extra-index-url`, not `--index-url`: the dependencies (`cffi`, `requests`, ...) still come
from PyPI. With [uv](https://docs.astral.sh/uv/), declare the index for `vosk` only:

```toml
# pyproject.toml
[project]
dependencies = ["vosk==0.3.75"]

[[tool.uv.index]]
name = "vosk"
url = "https://krozark.github.io/vosk-api/simple/"
explicit = true

[tool.uv.sources]
vosk = { index = "vosk" }
```

Models are not included: download one from the [model list](https://alphacephei.com/vosk/models).

## Supported platforms

| Platform | Architecture | Python wheel tag | Native library | Checked in CI |
|---|---|---|---|---|
| Linux (glibc) | x86_64 | `manylinux_2_28_x86_64` | `libvosk.so` | transcription, wheel installed from the index |
| Linux (glibc) | x86_64, Intel MKL | no wheel (same name as the OpenBLAS one) | `libvosk.so` in `vosk-linux-x86_64-mkl.zip` | built |
| Linux (glibc) | aarch64 | `manylinux_2_28_aarch64` | `libvosk.so` | built |
| Linux (glibc) | armv7l | `linux_armv7l` | `libvosk.so` | built |
| Linux (glibc) | i686 | `linux_i686` | `libvosk.so` | built |
| Linux (glibc) | riscv64 | `linux_riscv64` | `libvosk.so` | built |
| Linux (musl) | armv7l | `musllinux_1_2_armv7l` | `libvosk.so` | built |
| Windows | x64 | `win_amd64` | `libvosk.dll` | transcription |
| Windows | x86 | `win32` | `libvosk.dll` | built |
| Windows | arm64 | `win_arm64` | `libvosk.dll` | built |
| macOS 11+ | universal2 (arm64 + x86_64) | `macosx_11_0_universal2` | `libvosk.dylib` | transcription (arm64) |
| Android (API 21+) | armeabi-v7a, arm64-v8a, x86, x86_64 | none (not installed by pip) | `libvosk.so` in `vosk-android.zip` | transcription (x86_64 emulator) |
| iOS 13+ | arm64 (device and simulator) | none (not installed by pip) | `libvosk.xcframework` in `libvosk-ios-xcframework.zip` | transcription (simulator) |

"built" means the binary is compiled and packaged by CI but not run on that architecture.
The Python wheels are pure Python plus the native library: they do not depend on the Python
version (`py3-none-<platform>`). Every release also contains one `vosk-<platform>.zip` per
platform with `libvosk` and `vosk_api.h`, for the other language bindings.

## Android and iOS

Python is not installed with pip on mobile: the build tools build it into the application.
Use the `libvosk` of the release and a recipe for your toolchain:

- Android ([python-for-android](https://python-for-android.readthedocs.io/) / buildozer): copy
  `jniLibs/<abi>/libvosk.so` from `vosk-android.zip` next to the `vosk` Python package.
- iOS ([kivy-ios](https://github.com/kivy/kivy-ios)): embed `libvosk.xcframework`; the dynamic
  library is loaded as `@rpath/libvosk.dylib`.

A complete Kivy application using both (and running on Linux, Windows, Android and the iOS
simulator in CI) is in [Krozark/sandbox](https://github.com/Krozark/sandbox/tree/master/ideas/python-android/vosk-test).

## Build from source

`ios/build_libvosk.sh` builds the iOS and macOS libraries; the other platforms are built by the
scripts of `travis/` and `android/lib/build-vosk.sh`, driven by
[`build.yml`](.github/workflows/build.yml). To publish a release, run that workflow with the
`release_tag` input (or push a `vX.Y.Z` tag).

# Documentation

For installation instructions, examples and documentation visit [Vosk
Website](https://alphacephei.com/vosk).
