#!/bin/bash
set -euo pipefail
task_app="${1:?Usage: VerifyBundledApp.sh /path/to/Caeser.app}"
task_tools="$task_app/Contents/Resources/Tools"
task_test="$(mktemp -d /private/tmp/caeser-smoke.XXXXXX)"
codesign --verify --deep --strict "$task_app"
(cd "$task_tools" && shasum -a 256 --check SHA256SUMS)
for task_tool in yt-dlp spotdl ffmpeg ffprobe deno; do
    test -x "$task_tools/$task_tool"
    lipo "$task_tools/$task_tool" -verify_arch arm64
    if otool -L "$task_tools/$task_tool" | /usr/bin/grep -E '/opt/homebrew/|/usr/local/'; then
        echo "ERROR: external library in $task_tool" >&2
        exit 1
    fi
done
run_clean() {
    env -i HOME="$task_test" TMPDIR="$task_test" \
        PATH="$task_tools:/usr/bin:/bin:/usr/sbin:/sbin" \
        DENO_NO_UPDATE_CHECK=1 NO_COLOR=1 TERM=dumb "$@"
}
run_clean "$task_tools/yt-dlp" --version
run_clean "$task_tools/spotdl" --version
run_clean "$task_tools/deno" eval 'if (1 + 1 !== 2) throw new Error("runtime failure"); console.log("Deno JavaScript OK")'
run_clean "$task_tools/ffmpeg" -hide_banner -loglevel error -f lavfi \
    -i sine=frequency=440:duration=1 -codec:a libmp3lame -q:a 0 "$task_test/test.mp3"
run_clean "$task_tools/ffprobe" -v error -show_entries stream=codec_name \
    -of default=noprint_wrappers=1 "$task_test/test.mp3"
echo "Bundle verified without Homebrew or user configuration. Test files: $task_test"
