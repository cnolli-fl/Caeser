#!/bin/bash
# Build FFmpeg/FFprobe sharing their own libraries, never Homebrew's.
set -euo pipefail
task_cache="${1:?Usage: BuildMediaTools.sh CACHE_DIRECTORY}"
task_cache="$(cd "$task_cache" && pwd)"
task_prefix="$task_cache/media-prefix"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export MACOSX_DEPLOYMENT_TARGET=26.0
tar -xf "$task_cache/lame-3.100.tar.gz" -C "$task_cache"
tar -xf "$task_cache/ffmpeg-9.0.2.tar.xz" -C "$task_cache"
(
    cd "$task_cache/lame-3.100"
    ./configure --prefix="$task_prefix" --disable-shared --enable-static --disable-frontend --disable-dependency-tracking
    make -j8
    make install
)
(
    cd "$task_cache/ffmpeg-9.0.2"
    ./configure --prefix="$task_prefix" --enable-shared --disable-static --install-name-dir=@rpath \
        --disable-autodetect --disable-doc --disable-debug --disable-ffplay \
        --enable-securetransport --disable-encoders --enable-encoder=libmp3lame,aac,mjpeg,png \
        --enable-libmp3lame --extra-cflags="-I$task_prefix/include" --extra-ldflags="-L$task_prefix/lib"
    make -j8
    make install
)
for task_tool in ffmpeg ffprobe; do
    if otool -L "$task_prefix/bin/$task_tool" | sed -n '/^[[:space:]]/p' | /usr/bin/grep -E '/opt/homebrew/|/usr/local/|/private/tmp/'; then
        echo "ERROR: $task_tool still links a non-system library." >&2
        exit 1
    fi
done
