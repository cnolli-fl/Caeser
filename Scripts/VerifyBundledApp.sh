#!/bin/bash
set -euo pipefail
task_app="${1:?Usage: VerifyBundledApp.sh /path/to/Caeser.app}"
task_tools="$task_app/Contents/Resources/Tools"
task_test="$(mktemp -d /private/tmp/caeser-smoke.XXXXXX)"
codesign --verify --deep --strict "$task_app"
task_region="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDevelopmentRegion' "$task_app/Contents/Info.plist")"
test "$task_region" = pt-BR
test ! -e "$task_tools/Sources"
test "$(readlink "$task_tools/yt-dlp")" = spotdl
unzip -tq "$task_tools/Licenses.zip"
(cd "$task_tools" && shasum -a 256 --check SHA256SUMS)
for task_tool in "$task_tools"/yt-dlp "$task_tools"/spotdl "$task_tools"/ffmpeg \
    "$task_tools"/ffprobe "$task_tools"/deno "$task_tools"/Lib/*.dylib; do
    test -x "$task_tool"
    test "$(lipo -archs "$task_tool")" = arm64
    codesign --verify --strict "$task_tool"
    if otool -L "$task_tool" | sed -n '/^[[:space:]]/p' | /usr/bin/grep -E '/opt/homebrew/|/usr/local/|/private/tmp/'; then
        echo "ERROR: external library in $task_tool" >&2
        exit 1
    fi
done
while IFS= read -r task_locale; do
    case "${task_locale##*/}" in Base.lproj|pt.lproj|pt-BR.lproj|pt_BR.lproj) ;; *) exit 1 ;; esac
done < <(find "$task_app/Contents" -type d -name '*.lproj')
run_clean() {
    env -i HOME="$task_test" TMPDIR="$task_test" \
        PATH="$task_tools:/usr/bin:/bin:/usr/sbin:/sbin" \
        DENO_NO_UPDATE_CHECK=1 NO_COLOR=1 TERM=dumb "$@"
}
run_clean "$task_tools/yt-dlp" --version
run_clean "$task_tools/yt-dlp" --list-extractors > "$task_test/extractors.txt"
test "$(wc -l < "$task_test/extractors.txt")" -gt 1000
run_clean "$task_tools/spotdl" --version
run_clean "$task_tools/spotdl" download --help > "$task_test/spotify-help.txt"
run_clean "$task_tools/deno" eval 'if (1 + 1 !== 2) throw new Error("runtime failure"); console.log("Deno JavaScript OK")'
run_clean "$task_tools/ffmpeg" -hide_banner -loglevel error -f lavfi \
    -i sine=frequency=440:duration=1 -codec:a libmp3lame -q:a 0 "$task_test/test.mp3"
run_clean "$task_tools/ffprobe" -v error -show_entries stream=codec_name \
    -of default=noprint_wrappers=1 "$task_test/test.mp3"
run_clean "$task_tools/ffmpeg" -hide_banner -loglevel error -f lavfi \
    -i testsrc=size=128x72:rate=10 -f lavfi -i sine=frequency=440:duration=1 \
    -t 1 -c:v mjpeg -c:a aac -shortest "$task_test/test.mp4"
run_clean "$task_tools/ffmpeg" -hide_banner -loglevel error -i "$task_test/test.mp4" \
    -map 0 -c copy "$task_test/remux.mkv"
run_clean "$task_tools/ffprobe" -v error -show_entries stream=codec_name \
    -of default=noprint_wrappers=1 "$task_test/remux.mkv"
echo "Bundle verified without Homebrew or user configuration. Test files: $task_test"
