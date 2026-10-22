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
    if ($item.sha256 -notmatch '^[0-9a-f]{64}$') { throw "SHA-256 malformado: $($item.file)" }
    $target = Join-Path $cache $item.file
    if (-not (Test-Path $target)) {
        # Preserve the exact archive bytes, even if a mirror sends Content-Encoding: gzip.
        # Invoke-WebRequest transparently decompresses that response and changes its hash.
        & curl.exe --fail --location --retry 3 --retry-all-errors --max-time 180 --output $target -- $item.url
        if ($LASTEXITCODE -ne 0) { throw "Falha ao baixar $($item.file)." }
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant()
    if ($actualHash -ne $item.sha256) {
        throw "Checksum inválido: $($item.file). Esperado $($item.sha256); recebido $actualHash ($((Get-Item $target).Length) bytes). Não executar nem empacotar este arquivo."
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
    'Deno-Node.txt' = 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/cli/tsc/dts/node/LICENSE'
    'Deno-Undici.txt' = 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/cli/tsc/dts/node/undici/LICENSE'
    'Deno-WebGPU.txt' = 'https://raw.githubusercontent.com/denoland/deno/v2.9.8/ext/webgpu/LICENSE.md'
    'Python.txt' = 'https://raw.githubusercontent.com/python/cpython/v3.14.7/LICENSE'
    'PyInstaller.txt' = 'https://raw.githubusercontent.com/pyinstaller/pyinstaller/v6.22.3/COPYING.txt'
}
foreach ($notice in $notices.GetEnumerator()) {
    Invoke-WebRequest -Uri $notice.Value -OutFile (Join-Path $licenses $notice.Key) -MaximumRetryCount 3 -RetryIntervalSec 2
}
& python (Join-Path $PSScriptRoot 'CollectSourceNotices.py') $tools (Join-Path $cache 'source-cache') deno
if ($LASTEXITCODE -ne 0) { throw 'Falha na coleta dos avisos de dependências Deno/V8.' }
Write-Host 'Downloads fixados e verificados. Binários macOS não são reutilizados.'
