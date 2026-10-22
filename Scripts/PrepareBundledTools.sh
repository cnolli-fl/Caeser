#!/bin/bash
# Build-time only: end users need neither Homebrew nor Python.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_cache="${CAESER_PACKAGING_CACHE:-$task_root/.packaging-cache}"
task_output="${1:-$task_root/.tools/bundled-arm64}"
if [ "$(uname -m)" != arm64 ]; then
    echo 'This packaging recipe currently targets Apple Silicon only.' >&2
    exit 1
fi
mkdir -p "$task_cache" "$task_output/Licenses" "$task_output/Sources"
task_cache="$(cd "$task_cache" && pwd)"
task_output="$(cd "$task_output" && pwd)"
fetch() {
    local task_url="$1" task_name="$2" task_sha="$3"
    if [ ! -f "$task_cache/$task_name" ]; then
        curl --fail --location --retry 3 --connect-timeout 30 --max-time 600 \
            --output "$task_cache/$task_name.partial" "$task_url"
        mv "$task_cache/$task_name.partial" "$task_cache/$task_name"
    fi
    local task_actual
    task_actual="$(shasum -a 256 "$task_cache/$task_name" | cut -d ' ' -f 1)"
    if [ "$task_actual" != "$task_sha" ]; then
        echo "SHA-256 mismatch: $task_name. File was not executed." >&2
        exit 1
    fi
}
fetch 'https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/yt-dlp_macos' yt-dlp 0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202
fetch 'https://github.com/denoland/deno/releases/download/v2.9.8/deno-aarch64-apple-darwin.zip' deno.zip 9f0bf660393da2eaff044cdc7444cb08c73f235849b61d224d825a194ce7c98e
fetch 'https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz' ffmpeg-9.0.2.tar.xz 8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
fetch 'https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz' lame-3.100.tar.gz ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e

task_media_key="$(shasum -a 256 "$task_root/Scripts/BuildMediaTools.sh" | cut -d ' ' -f 1)"
task_python_key="$(shasum -a 256 "$task_root/Scripts/BuildSpotDL.sh" "$task_root/Scripts/SpotDLEntry.py" \
    "$task_root/Packaging/MediaTools.spec" "$task_root/Packaging/spotdl-requirements.txt" | shasum -a 256 | cut -d ' ' -f 1)"
task_media_work="$task_cache/media-$task_media_key"
task_python_work="$task_cache/python-$task_python_key"
mkdir -p "$task_media_work" "$task_python_work"
cp "$task_cache/ffmpeg-9.0.2.tar.xz" "$task_cache/lame-3.100.tar.gz" "$task_media_work/"
if [ ! -x "$task_media_work/media-prefix/bin/ffmpeg" ] || [ ! -x "$task_media_work/media-prefix/bin/ffprobe" ]; then
    /bin/bash "$task_root/Scripts/BuildMediaTools.sh" "$task_media_work" > "$task_media_work/media-build.log" 2>&1
fi
if [ ! -x "$task_python_work/spotdl-arm64" ]; then
    /bin/bash "$task_root/Scripts/BuildSpotDL.sh" "$task_python_work" > "$task_python_work/spotdl-build.log" 2>&1
fi
cp "$task_python_work/spotdl-arm64" "$task_output/spotdl"
# The relative link survives moving/extracting the app; no second Python copy.
if [ -d "$task_output/yt-dlp" ]; then
    echo 'Refusing to replace a directory named yt-dlp.' >&2
    exit 1
fi
ln -sfn spotdl "$task_output/yt-dlp"
unzip -oq "$task_cache/deno.zip" -d "$task_output"
cp "$task_media_work/media-prefix/bin/ffmpeg" "$task_media_work/media-prefix/bin/ffprobe" "$task_output/"
mkdir -p "$task_output/Lib"
for task_library in "$task_media_work/media-prefix/lib"/*.dylib; do
    [ -L "$task_library" ] && continue
    task_id="$(otool -D "$task_library" | tail -1)"
    task_destination="$task_output/Lib/${task_id##*/}"
    cp "$task_library" "$task_destination"
    install_name_tool -add_rpath '@loader_path' "$task_destination"
done
for task_tool in ffmpeg ffprobe; do
    install_name_tool -add_rpath '@loader_path/Lib' "$task_output/$task_tool"
done
chmod 755 "$task_output/yt-dlp" "$task_output/spotdl" "$task_output/deno" "$task_output/ffmpeg" "$task_output/ffprobe"

# Corresponding sources are staged here, then offered as a separate download.
cp "$task_cache/ffmpeg-9.0.2.tar.xz" "$task_cache/lame-3.100.tar.gz" "$task_output/Sources/"
cp "$task_root/Scripts/BuildMediaTools.sh" "$task_output/Sources/"
mkdir -p "$task_output/Sources/spotdl-build-recipe/Scripts" "$task_output/Sources/spotdl-build-recipe/Packaging"
cp "$task_root/Scripts/BuildSpotDL.sh" "$task_root/Scripts/SpotDLEntry.py" "$task_output/Sources/spotdl-build-recipe/Scripts/"
cp "$task_root/Packaging/spotdl-requirements.txt" "$task_root/Packaging/MediaTools.spec" "$task_output/Sources/spotdl-build-recipe/Packaging/"
cp "$task_media_work/ffmpeg-9.0.2/COPYING.LGPLv2.1" "$task_output/Licenses/FFmpeg-LGPL-2.1.txt"
cp "$task_media_work/lame-3.100/COPYING" "$task_output/Licenses/LAME-LGPL.txt"
cp "$task_root/THIRD-PARTY.md" "$task_output/"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.08.19/LICENSE' -o "$task_output/Licenses/yt-dlp-Unlicense.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.08.19/THIRD_PARTY_LICENSES.txt' -o "$task_output/Licenses/yt-dlp-third-party.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/spotDL/spotify-downloader/v4.5.2/LICENSE' -o "$task_output/Licenses/spotDL-MIT.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/LICENSE.md' -o "$task_output/Licenses/Deno-MIT.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/python/cpython/v3.14.7/LICENSE' -o "$task_output/Licenses/Python.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/pyinstaller/pyinstaller/v6.22.3/COPYING.txt' -o "$task_output/Licenses/PyInstaller.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/v8/v8/main/LICENSE' -o "$task_output/Licenses/V8.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/cli/tsc/dts/node/LICENSE' -o "$task_output/Licenses/Deno-Node.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/cli/tsc/dts/node/undici/LICENSE' -o "$task_output/Licenses/Deno-Undici.txt"
curl -fsSL --retry 3 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/ext/webgpu/LICENSE.md' -o "$task_output/Licenses/Deno-WebGPU.txt"

"${CAESER_TOOLS_PYTHON:-$task_python_work/spotdl-build/bin/python}" "$task_root/Scripts/CollectToolLicenses.py" "$task_output"
# These two existing helpers are platform-neutral and shared with Windows.
task_python="$task_python_work/spotdl-build/bin/python"
"$task_python" "$task_root/Windows/Scripts/CollectPythonLicenses.py" "$task_output/Licenses/Python-packages"
"$task_python" "$task_root/Windows/Scripts/CollectSourceNotices.py" "$task_output" "$task_cache/source-cache" python
"$task_python" "$task_root/Windows/Scripts/CollectSourceNotices.py" "$task_output" "$task_cache/source-cache" deno

# A SHA manifest also records the locally compiled FFmpeg/FFprobe.
(cd "$task_output" && shasum -a 256 yt-dlp spotdl deno ffmpeg ffprobe Lib/*.dylib > SHA256SUMS)
echo "Standalone tools prepared in $task_output"
