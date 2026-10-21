#!/bin/bash
# Creates a local ad-hoc signed distribution. No Developer ID, account or payment.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_output="${1:-$task_root/dist}"
task_tools="${CAESER_BUNDLED_TOOLS:-$task_root/.tools/bundled-arm64}"
task_build="${CAESER_BUILD_DIRECTORY:-$(mktemp -d /private/tmp/caeser-package.XXXXXX)}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [ ! -x "$task_tools/spotdl" ] || [ ! -f "$task_tools/Licenses/spotDL-MIT.txt" ]; then
    echo 'Run bash Scripts/PrepareBundledTools.sh first.' >&2
    exit 1
fi
mkdir -p "$task_output" "$task_build"
task_stage="$(mktemp -d "$task_build/installer.XXXXXX")"
task_output="$(cd "$task_output" && pwd)"
"$DEVELOPER_DIR/usr/bin/xcodebuild" -quiet -project "$task_root/VideoDownloader.xcodeproj" \
    -scheme Caeser -configuration Release -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$task_build/Xcode" build CODE_SIGNING_ALLOWED=NO ARCHS=arm64
task_app="$task_stage/Caeser.app"
ditto --norsrc "$task_build/Xcode/Build/Products/Release/Caeser.app" "$task_app"
ditto --norsrc "$task_tools" "$task_app/Contents/Resources/Tools"
cp "$task_root/LICENSE" "$task_app/Contents/Resources/Caeser-MIT.txt"
cp "$task_root/docs/INSTALACAO.md" "$task_stage/LEIA-ME.md"
cp "$task_root/docs/INSTALACAO.md" "$task_app/Contents/Resources/INSTALACAO.md"
ln -s /Applications "$task_stage/Aplicativos"

for task_tool in yt-dlp ffmpeg ffprobe spotdl deno; do
    codesign --force --sign - --preserve-metadata=entitlements,flags,runtime \
        "$task_app/Contents/Resources/Tools/$task_tool"
done
# Recreate the manifest after signing changes the executable bytes.
(cd "$task_app/Contents/Resources/Tools" && shasum -a 256 yt-dlp spotdl deno ffmpeg ffprobe > SHA256SUMS)
codesign --force --sign - "$task_app"
codesign --verify --deep --strict "$task_app"
task_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$task_app/Contents/Info.plist")"
task_name="Caeser-$task_version-macOS-AppleSilicon"
ditto -c -k --sequesterRsrc --keepParent "$task_app" "$task_output/$task_name.zip"
hdiutil create -ov -volname Caeser -srcfolder "$task_stage" -format UDZO "$task_output/$task_name.dmg"
(cd "$task_output" && shasum -a 256 "$task_name.dmg" "$task_name.zip" > "$task_name-SHA256SUMS.txt")
echo "App: $task_app"
echo "Packages: $task_output/$task_name.{dmg,zip}"
