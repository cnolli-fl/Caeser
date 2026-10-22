[CmdletBinding()]
param(
    [string]$ApplicationDirectory = (Join-Path $PSScriptRoot '..\artifacts\app'),
    [string]$ToolsDirectory = (Join-Path $PSScriptRoot '..\.tools\win-x64')
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'O empacotamento é feito em Windows x64.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $windowsRoot -Parent
[xml]$properties = Get-Content -Raw (Join-Path $windowsRoot 'Directory.Build.props')
$version = $properties.Project.PropertyGroup.Version
$candidate = Join-Path $windowsRoot ('artifacts\candidate-' + [Guid]::NewGuid().ToString('N'))
$dist = Join-Path $windowsRoot 'artifacts\dist'
New-Item -ItemType Directory -Path $candidate, $dist -Force | Out-Null
Copy-Item (Join-Path $ApplicationDirectory '*') $candidate -Recurse -Force
Copy-Item $ToolsDirectory (Join-Path $candidate 'Tools') -Recurse -Force
Copy-Item (Join-Path $repoRoot 'LICENSE') (Join-Path $candidate 'LICENSE.txt')
Copy-Item (Join-Path $repoRoot 'BRAND-ASSETS.md') $candidate
Copy-Item (Join-Path $windowsRoot 'THIRD-PARTY.md') $candidate
& (Join-Path $PSScriptRoot 'VerifyTools.ps1') -ToolsDirectory (Join-Path $candidate 'Tools')
Copy-Item (Join-Path $candidate 'Tools\versions.json') (Join-Path $windowsRoot 'artifacts\tools-versions.json') -Force
$previousTestDirectory = $env:CAESER_TEST_APPLICATION_DIRECTORY
try {
    $env:CAESER_TEST_APPLICATION_DIRECTORY = $candidate
    & dotnet test (Join-Path $windowsRoot 'Caeser.Core.Tests\Caeser.Core.Tests.csproj') -c Release --filter 'Category=BundledTools' --logger 'trx;LogFileName=bundled-download.trx' --results-directory (Join-Path $windowsRoot 'TestResults')
    if ($LASTEXITCODE -ne 0) { throw 'O download local e a conversão pelo pacote completo falharam.' }
} finally { $env:CAESER_TEST_APPLICATION_DIRECTORY = $previousTestDirectory }
if (-not (Test-Path (Join-Path $candidate 'Caeser.exe'))) { throw 'Aplicativo não encontrado no pacote.' }
$product = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $candidate 'Caeser.exe'))
if ($product.ProductVersion -ne $version) { throw "Versão do aplicativo inesperada: $($product.ProductVersion); esperado $version." }
$zip = Join-Path $dist "Caeser-$version-Windows-x64.zip"
Compress-Archive -Path (Join-Path $candidate '*') -DestinationPath $zip -CompressionLevel Optimal -Force
$compiler = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Inno Setup 6\ISCC.exe'
if (-not (Test-Path $compiler)) { throw 'Instale o Inno Setup 6 no computador de desenvolvimento.' }
& $compiler "/DSourceDirectory=$candidate" "/DOutputDirectory=$dist" "/DAppVersion=$version" (Join-Path $windowsRoot 'Packaging\Caeser.iss')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o instalador.' }
$checksums = Get-ChildItem $dist -File | Where-Object { $_.Extension -in @('.zip', '.exe') } | ForEach-Object {
    "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
}
$checksums | Set-Content -Encoding ascii (Join-Path $dist "Caeser-$version-Windows-x64-SHA256SUMS.txt")
Write-Host "Caeser $version para Windows preparado em $dist. A publicação no GitHub é uma etapa separada."
