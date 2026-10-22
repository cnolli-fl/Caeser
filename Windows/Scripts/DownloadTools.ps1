[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Preparação destinada ao Windows x64.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
$cache = Join-Path $windowsRoot '.cache\media'
$tools = Join-Path $windowsRoot '.tools\win-x64'
$licenses = Join-Path $tools 'Licenses'
$sources = Join-Path $tools 'Sources'
foreach ($directory in @($cache, $tools, $licenses, $sources)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$lockFile = Join-Path $windowsRoot 'Packaging\tools.lock.json'
$lock = Get-Content -Raw $lockFile | ConvertFrom-Json
foreach ($entry in $lock.PSObject.Properties) {
    $item = $entry.Value
    $target = Join-Path $cache $item.file
    if (-not (Test-Path $target)) {
        Invoke-WebRequest -Uri $item.url -OutFile $target -MaximumRetryCount 3 -RetryIntervalSec 2
    }
    if ((Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant() -ne $item.sha256) {
        throw "Checksum inválido: $($item.file). Não executar nem empacotar este arquivo."
    }
}
Copy-Item (Join-Path $cache 'yt-dlp.exe') $tools -Force
$denoExtract = Join-Path $cache ('deno-' + [Guid]::NewGuid().ToString('N'))
Expand-Archive -Path (Join-Path $cache 'deno.zip') -DestinationPath $denoExtract
Copy-Item (Join-Path $denoExtract 'deno.exe') $tools -Force
Copy-Item (Join-Path $cache 'ffmpeg-9.0.2.tar.xz') $sources -Force
Copy-Item (Join-Path $cache 'lame-3.100.tar.gz') $sources -Force
Copy-Item $lockFile (Join-Path $tools 'tools.lock.json') -Force

$notices = @{
    'yt-dlp-Unlicense.txt' = 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.08.19/LICENSE'
    'yt-dlp-third-party.txt' = 'https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.08.19/THIRD_PARTY_LICENSES.txt'
    'spotDL-MIT.txt' = 'https://raw.githubusercontent.com/spotDL/spotify-downloader/v4.5.2/LICENSE'
    'Deno-MIT.txt' = 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/LICENSE.md'
    'Python.txt' = 'https://raw.githubusercontent.com/python/cpython/v3.14.7/LICENSE'
    'PyInstaller.txt' = 'https://raw.githubusercontent.com/pyinstaller/pyinstaller/v6.22.3/COPYING.txt'
}
foreach ($notice in $notices.GetEnumerator()) {
    Invoke-WebRequest -Uri $notice.Value -OutFile (Join-Path $licenses $notice.Key) -MaximumRetryCount 3 -RetryIntervalSec 2
}
Write-Host 'Downloads fixados e verificados. Binários macOS não são reutilizados.'
