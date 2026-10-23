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
$payload = Join-Path $candidate 'Aplicativo'
$documentation = Join-Path $candidate 'Documentacao'
$payloadTools = Join-Path $payload 'Tools'
New-Item -ItemType Directory -Path $payload, $payloadTools, $documentation -Force | Out-Null
foreach ($item in Get-ChildItem $ApplicationDirectory) {
    if ($item.Name -in @('Licenses', 'Launcher') -or $item.Extension -eq '.pdb') { continue }
    Copy-Item $item.FullName $payload -Recurse -Force
}
# Sources are distributed alongside the binaries, not installed as runtime data.
# Keep complete licenses accessible in the app's documentation folder.
Get-ChildItem $ToolsDirectory -File | Copy-Item -Destination $payloadTools -Force
Copy-Item (Join-Path $ToolsDirectory 'Licenses') (Join-Path $documentation 'Ferramentas') -Recurse -Force
Copy-Item (Join-Path $ApplicationDirectory 'Licenses') (Join-Path $documentation 'Runtime') -Recurse -Force
Copy-Item (Join-Path $repoRoot 'LICENSE') (Join-Path $documentation 'LICENSE.txt')
Copy-Item (Join-Path $repoRoot 'BRAND-ASSETS.md') $documentation
Copy-Item (Join-Path $windowsRoot 'THIRD-PARTY.md') $documentation
(Get-Content -Raw (Join-Path $windowsRoot 'Packaging\LEIA-ME.txt')).Replace('VERSAO', $version) |
    Set-Content -Encoding utf8 (Join-Path $candidate 'LEIA-ME.txt')
Copy-Item (Join-Path $ApplicationDirectory 'Launcher\Caeser.exe') $candidate
& (Join-Path $PSScriptRoot 'VerifyTools.ps1') -ToolsDirectory $payloadTools
Copy-Item (Join-Path $payloadTools 'versions.json') (Join-Path $windowsRoot 'artifacts\tools-versions.json') -Force
$previousTestDirectory = $env:CAESER_TEST_APPLICATION_DIRECTORY
try {
    $env:CAESER_TEST_APPLICATION_DIRECTORY = $payload
    & dotnet test (Join-Path $windowsRoot 'Caeser.Core.Tests\Caeser.Core.Tests.csproj') -c Release --filter 'Category=BundledTools' --logger 'trx;LogFileName=bundled-download.trx' --results-directory (Join-Path $windowsRoot 'TestResults')
    if ($LASTEXITCODE -ne 0) { throw 'O download local e a conversão pelo pacote completo falharam.' }
} finally { $env:CAESER_TEST_APPLICATION_DIRECTORY = $previousTestDirectory }
if (-not (Test-Path (Join-Path $candidate 'Caeser.exe'))) { throw 'Aplicativo não encontrado no pacote.' }
$product = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $payload 'Caeser.exe'))
if ($product.ProductVersion -ne $version) { throw "Versão do aplicativo inesperada: $($product.ProductVersion); esperado $version." }
$zip = Join-Path $dist "Caeser-$version-Windows-x64.zip"
Compress-Archive -Path (Join-Path $candidate '*') -DestinationPath $zip -CompressionLevel Optimal -Force
$sourceCandidate = Join-Path $windowsRoot ('artifacts\source-bundle-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sourceCandidate -Force | Out-Null
Copy-Item (Join-Path $ToolsDirectory 'Sources') $sourceCandidate -Recurse -Force
Copy-Item (Join-Path $ToolsDirectory 'Licenses') $sourceCandidate -Recurse -Force
Copy-Item (Join-Path $ToolsDirectory 'tools.lock.json') $sourceCandidate
Copy-Item (Join-Path $windowsRoot 'Scripts') $sourceCandidate -Recurse
Copy-Item (Join-Path $windowsRoot 'Packaging') $sourceCandidate -Recurse
Copy-Item (Join-Path $windowsRoot 'Caeser.Launcher') $sourceCandidate -Recurse
Copy-Item (Join-Path $windowsRoot 'Caeser.Bootstrap') $sourceCandidate -Recurse
Compress-Archive -Path (Join-Path $sourceCandidate '*') -DestinationPath (Join-Path $dist "Caeser-$version-Windows-x64-Fontes-Terceiros.zip") -CompressionLevel Optimal -Force
# Test the actual portable ZIP, extracted under a different path with spaces and
# Unicode, including launcher argument forwarding. Never test only build output.
$portable = Join-Path $windowsRoot ('artifacts\Teste portatil ação ' + [Guid]::NewGuid().ToString('N'))
Expand-Archive -Path $zip -DestinationPath $portable
& (Join-Path $PSScriptRoot 'TestUi.ps1') -ApplicationDirectory $portable -OutputDirectory (Join-Path $windowsRoot 'artifacts\portable-ui')
$rootNames = @(Get-ChildItem $portable | Select-Object -ExpandProperty Name | Sort-Object)
if (($rootNames -join '|') -ne 'Aplicativo|Caeser.exe|Documentacao|LEIA-ME.txt') { throw 'A raiz do pacote portátil ficou desorganizada.' }
if (Test-Path (Join-Path $portable 'Aplicativo\Tools\Sources')) { throw 'Fontes de terceiros não devem ser instalados no aplicativo.' }
foreach ($unused in @('onnxruntime.dll', 'DirectML.dll', 'Microsoft.Windows.Widgets.dll', 'Microsoft.Windows.Search.dll')) {
    if (Test-Path (Join-Path $portable ('Aplicativo\' + $unused))) { throw "Componente não utilizado ainda foi empacotado: $unused" }
}
$languages = @(Get-ChildItem (Join-Path $portable 'Aplicativo') -Directory | Where-Object { $_.Name -match '^[a-z]{2,3}(-[a-zA-Z0-9]{2,8})*$' })
if (@($languages | Where-Object { $_.Name -notin @('pt-BR', 'en-US') }).Count -gt 0) { throw 'O pacote ainda contém traduções além de português e do fallback interno obrigatório do WinUI.' }
$compiler = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Inno Setup 6\ISCC.exe'
if (-not (Test-Path $compiler)) { throw 'Instale o Inno Setup 6 no computador de desenvolvimento.' }
& $compiler "/DSourceDirectory=$candidate" "/DOutputDirectory=$dist" "/DAppVersion=$version" (Join-Path $windowsRoot 'Packaging\Caeser.iss')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o instalador.' }
& (Join-Path $PSScriptRoot 'BuildBootstrap.ps1') -Installer (Join-Path $dist "Caeser-$version-Windows-x64-Setup.exe") -OutputDirectory $dist
@{ version = $version; installedBytes = [long](Get-ChildItem $candidate -Recurse -File | Measure-Object -Property Length -Sum).Sum;
   files = @(Get-ChildItem $candidate -Recurse -File).Count;
   tools = @(Get-ChildItem $payloadTools -File | Select-Object Name, Length) } |
    ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $dist 'package-size.json')
$checksums = Get-ChildItem $dist -File | Where-Object { $_.Extension -in @('.zip', '.exe') } | ForEach-Object {
    "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)"
}
$checksums | Set-Content -Encoding ascii (Join-Path $dist "Caeser-$version-Windows-x64-SHA256SUMS.txt")
Write-Host "Caeser $version para Windows preparado em $dist. A publicação no GitHub é uma etapa separada."
