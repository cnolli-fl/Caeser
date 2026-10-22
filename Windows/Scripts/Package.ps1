[CmdletBinding()]
param(
    [string]$ApplicationDirectory = (Join-Path $PSScriptRoot '..\artifacts\app'),
    [string]$ToolsDirectory = (Join-Path $PSScriptRoot '..\.tools\win-x64')
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'O empacotamento é feito em Windows x64.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $windowsRoot -Parent
$candidate = Join-Path $windowsRoot ('artifacts\candidate-' + [Guid]::NewGuid().ToString('N'))
$dist = Join-Path $windowsRoot 'artifacts\dist'
New-Item -ItemType Directory -Path $candidate, $dist -Force | Out-Null
Copy-Item (Join-Path $ApplicationDirectory '*') $candidate -Recurse -Force
Copy-Item $ToolsDirectory (Join-Path $candidate 'Tools') -Recurse -Force
Copy-Item (Join-Path $repoRoot 'LICENSE') (Join-Path $candidate 'LICENSE.txt')
Copy-Item (Join-Path $windowsRoot 'THIRD-PARTY.md') $candidate
& (Join-Path $PSScriptRoot 'VerifyTools.ps1') -ToolsDirectory (Join-Path $candidate 'Tools')
if (-not (Test-Path (Join-Path $candidate 'Caeser.exe'))) { throw 'Aplicativo não encontrado no pacote.' }
$zip = Join-Path $dist 'Caeser-2.1.0-Windows-x64-Preview.zip'
Compress-Archive -Path (Join-Path $candidate '*') -DestinationPath $zip -CompressionLevel Optimal -Force
$compiler = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Inno Setup 6\ISCC.exe'
if (-not (Test-Path $compiler)) { throw 'Instale o Inno Setup 6 no computador de desenvolvimento.' }
& $compiler "/DSourceDirectory=$candidate" "/DOutputDirectory=$dist" (Join-Path $windowsRoot 'Packaging\Caeser.iss')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o instalador.' }
$checksums = Get-ChildItem $dist -File | Where-Object { $_.Extension -in @('.zip', '.exe') } | ForEach-Object {
    "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
}
$checksums | Set-Content -Encoding ascii (Join-Path $dist 'Caeser-2.1.0-Windows-x64-Preview-SHA256SUMS.txt')
Write-Host "Pacotes de teste preparados em $dist. Nada foi publicado em Releases."
