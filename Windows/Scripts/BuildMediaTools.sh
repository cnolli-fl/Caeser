#!/usr/bin/env bash
# Run inside MSYS2/UCRT64 on Windows. Same narrow LGPL build as macOS.
set -euo pipefail
if [ "$#" -ne 2 ]; then echo "Usage: BuildMediaTools.sh CACHE TOOLS" >&2; exit 1; fi
case "$(uname -s)" in MINGW*|MSYS*) ;; *) echo "Use MSYS2/UCRT64 no Windows." >&2; exit 1 ;; esac
task_cache="$(cd "$1" && pwd)"
task_output="$(cd "$2" && pwd)"
task_script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
task_build="$(mktemp -d "$task_cache/build.XXXXXX")"
task_prefix="$task_build/prefix"
export PATH="/ucrt64/bin:/usr/bin:$PATH"
export CC=gcc AR=ar RANLIB=ranlib
tar -xf "$task_cache/lame-3.100.tar.gz" -C "$task_build"
tar -xf "$task_cache/ffmpeg-9.0.2.tar.xz" -C "$task_build"
(
    cd "$task_build/lame-3.100"
    ./configure --host=x86_64-w64-mingw32 --prefix="$task_prefix" \
        --disable-shared --enable-static --disable-frontend --disable-dependency-tracking
    make -j4
    make install
)
export PKG_CONFIG_PATH="$task_prefix/lib/pkgconfig"
(
    cd "$task_build/ffmpeg-9.0.2"
    ./configure --prefix="$task_prefix" --arch=x86_64 --target-os=mingw32 \
        --enable-cross-compile --cc=gcc --ar=ar --ranlib=ranlib --pkg-config=pkgconf \
        --disable-autodetect --disable-shared --enable-static --disable-doc --disable-debug --disable-ffplay \
        --enable-schannel --enable-w32threads --disable-pthreads \
        --disable-encoders --enable-encoder=libmp3lame,aac,mjpeg,png --enable-libmp3lame \
        --extra-cflags="-I$task_prefix/include" --extra-ldflags="-L$task_prefix/lib -static -static-libgcc"
    make -j4
    make install
)
cp "$task_prefix/bin/ffmpeg.exe" "$task_prefix/bin/ffprobe.exe" "$task_output/"
cp "$task_build/ffmpeg-9.0.2/COPYING.LGPLv2.1" "$task_output/Licenses/FFmpeg-LGPL-2.1.txt"
cp "$task_build/lame-3.100/COPYING" "$task_output/Licenses/LAME-LGPL.txt"
mkdir -p "$task_output/Licenses/MinGW-runtime"
for task_notice in /ucrt64/share/licenses/gcc-libs/* /ucrt64/share/licenses/crt-git/* /ucrt64/share/licenses/headers-git/*; do
    if [ -f "$task_notice" ]; then
        task_owner="$(basename "$(dirname "$task_notice")")"
        cp "$task_notice" "$task_output/Licenses/MinGW-runtime/$task_owner-$(basename "$task_notice")"
    fi
done
cp "$task_script" "$task_output/Sources/BuildMediaTools.sh"
cp "$task_build/ffmpeg-9.0.2/ffbuild/config.log" "$task_output/Sources/FFmpeg-config.log"
"$task_output/ffmpeg.exe" -hide_banner -version
"$task_output/ffprobe.exe" -hide_banner -version
