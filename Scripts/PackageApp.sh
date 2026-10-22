#!/bin/bash
# Creates a local ad-hoc signed distribution. No Developer ID, account or payment.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_output="${1:-$task_root/dist}"
task_tools="${CAESER_BUNDLED_TOOLS:-$task_root/.tools/bundled-arm64}"
task_build="${CAESER_BUILD_DIRECTORY:-$(mktemp -d /private/tmp/caeser-package.XXXXXX)}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [ ! -x "$task_tools/spotdl" ] || [ ! -f "$task_tools/Licenses/spotDL-MIT.txt" ] || [ ! -d "$task_tools/Lib" ]; then
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
ditto --norsrc --noextattr --noqtn "$task_build/Xcode/Build/Products/Release/Caeser.app" "$task_app"
task_runtime="$task_app/Contents/Resources/Tools"
/usr/libexec/PlistBuddy -c 'Add :CFBundleLocalizations array' "$task_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleLocalizations:0 string pt-BR' "$task_app/Contents/Info.plist"
mkdir -p "$task_runtime"
# Explicit allowlist: do not copy build sources, caches or arbitrary extra files.
for task_tool in yt-dlp ffmpeg ffprobe spotdl deno; do
    cp -P "$task_tools/$task_tool" "$task_runtime/"
done
ditto --norsrc --noextattr --noqtn "$task_tools/Lib" "$task_runtime/Lib"
# Preserve every original notice, grouped in one readable archive rather than
# thousands of loose files. No runtime component reads this documentation.
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --noqtn --keepParent \
    "$task_tools/Licenses" "$task_runtime/Licenses.zip"
cp "$task_root/THIRD-PARTY.md" "$task_runtime/THIRD-PARTY.md"
cp "$task_root/LICENSE" "$task_app/Contents/Resources/Caeser-MIT.txt"
cp "$task_root/docs/INSTALACAO.md" "$task_stage/LEIA-ME.md"
cp "$task_root/docs/INSTALACAO.md" "$task_app/Contents/Resources/INSTALACAO.md"
ln -s /Applications "$task_stage/Aplicativos"

# Only this newly generated app is pruned; never modify an installed app/cache.
while IFS= read -r -d '' task_locale; do
    case "${task_locale##*/}" in
        Base.lproj|pt.lproj|pt-BR.lproj|pt_BR.lproj) ;;
        *) /bin/rm -r "$task_locale" ;;
    esac
done < <(find "$task_app/Contents" -type d -name '*.lproj' -prune -print0)
for task_library in "$task_runtime/Lib"/*.dylib; do
    codesign --force --sign - "$task_library"
done
for task_tool in yt-dlp ffmpeg ffprobe spotdl deno; do
    [ -L "$task_runtime/$task_tool" ] && continue
    codesign --force --sign - --preserve-metadata=entitlements,flags,runtime \
        "$task_app/Contents/Resources/Tools/$task_tool"
done
# Recreate the manifest after signing changes the executable bytes.
(cd "$task_runtime" && shasum -a 256 yt-dlp spotdl deno ffmpeg ffprobe Lib/*.dylib > SHA256SUMS)
codesign --force --sign - "$task_app"
bash "$task_root/Scripts/VerifyBundledApp.sh" "$task_app"
task_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$task_app/Contents/Info.plist")"
task_name="Caeser-$task_version-macOS-AppleSilicon"
# Sources stay available as a separate companion download, not in the app.
task_sources="$(mktemp -d "$task_build/fontes.XXXXXX")"
ditto --norsrc --noextattr --noqtn "$task_tools/Sources" "$task_sources/Sources"
ditto --norsrc --noextattr --noqtn "$task_tools/Licenses" "$task_sources/Licenses"
mkdir -p "$task_sources/Receita/Scripts" "$task_sources/Receita/Packaging"
mkdir -p "$task_sources/Receita/Windows/Scripts"
cp "$task_root/Windows/Scripts/CollectPythonLicenses.py" "$task_root/Windows/Scripts/CollectSourceNotices.py" "$task_sources/Receita/Windows/Scripts/"
cp "$task_root/Scripts/PrepareBundledTools.sh" "$task_root/Scripts/BuildMediaTools.sh" \
    "$task_root/Scripts/BuildSpotDL.sh" "$task_root/Scripts/SpotDLEntry.py" \
    "$task_root/Scripts/CollectToolLicenses.py" "$task_sources/Receita/Scripts/"
cp "$task_root/Packaging/spotdl-requirements.txt" "$task_root/Packaging/MediaTools.spec" "$task_sources/Receita/Packaging/"
cp "$task_root/THIRD-PARTY.md" "$task_sources/"
cp "$task_root/THIRD-PARTY.md" "$task_sources/Receita/"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --noqtn "$task_sources" "$task_output/$task_name-Fontes-Terceiros.zip"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --noqtn --keepParent "$task_app" "$task_output/$task_name.zip"
hdiutil create -ov -volname Caeser -srcfolder "$task_stage" -format UDZO "$task_output/$task_name.dmg"
(cd "$task_output" && shasum -a 256 "$task_name.dmg" "$task_name.zip" "$task_name-Fontes-Terceiros.zip" > "$task_name-SHA256SUMS.txt")
echo "App: $task_app"
echo "Packages: $task_output/$task_name.{dmg,zip}"
