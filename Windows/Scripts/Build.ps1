[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\artifacts\app'))
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'A interface WinUI precisa ser compilada no Windows.' }
$windowsRoot = Split-Path $PSScriptRoot -Parent
$project = Join-Path $windowsRoot 'Caeser.App\Caeser.App.csproj'
Push-Location $windowsRoot
try {
    & dotnet restore $project -r win-x64 -p:Platform=x64
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao restaurar as dependências WinUI.' }
    & dotnet msbuild $project -p:Configuration=Release -p:RuntimeIdentifier=win-x64 -p:Platform=x64 '-getProperty:EnableMsixTooling,MsixPackageSupport,EnableCoreMrtTooling,AppxGeneratePriEnabled,ProjectPriFileName,ProjectPriFullPath'
    & dotnet publish $project -c Release -r win-x64 --self-contained true --no-restore -p:Platform=x64 -o $OutputDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Falha na compilação WinUI.' }
    if (-not (Test-Path (Join-Path $OutputDirectory 'resources.pri'))) {
        Get-ChildItem (Join-Path $windowsRoot 'Caeser.App') -Recurse -File -Include *.pri,*.xbf | Select-Object -First 30 FullName | Format-Table -AutoSize
        Get-ChildItem $OutputDirectory -Filter *.pri | Select-Object Name | Format-Table -AutoSize
        throw 'O índice resources.pri não foi publicado. Não distribuir um pacote sem os recursos XAML.'
    }
    $legal = Join-Path $OutputDirectory 'Licenses\Runtime'
    New-Item -ItemType Directory -Path $legal -Force | Out-Null
    $dotnetRoot = Split-Path (Get-Command dotnet).Source -Parent
    foreach ($name in @('LICENSE.txt', 'ThirdPartyNotices.txt')) {
        $notice = Join-Path $dotnetRoot $name
        if (-not (Test-Path $notice)) { throw "Aviso do runtime .NET ausente: $name" }
        Copy-Item $notice (Join-Path $legal ('dotnet-' + $name)) -Force
    }
    $assets = Get-Content -Raw (Join-Path $windowsRoot 'Caeser.App\obj\project.assets.json') | ConvertFrom-Json
    foreach ($library in $assets.libraries.PSObject.Properties) {
        if ($library.Value.type -ne 'package') { continue }
        foreach ($folder in $assets.packageFolders.PSObject.Properties.Name) {
            $packagePath = Join-Path $folder $library.Value.path
            if (-not (Test-Path $packagePath)) { continue }
            $packageNotices = Get-ChildItem $packagePath -File | Where-Object { $_.Name -match '^(license|notice|third.?party)' }
            foreach ($notice in $packageNotices) {
                $prefix = $library.Name -replace '[/\\]', '-'
                Copy-Item $notice.FullName (Join-Path $legal ($prefix + '-' + $notice.Name)) -Force
            }
        }
    }
    if (-not (Get-ChildItem $legal -Filter 'Microsoft.WindowsAppSDK-*-license.txt')) {
        throw 'A licença do Windows App SDK não foi incluída na distribuição.'
    }
} finally { Pop-Location }
