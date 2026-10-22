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
} finally { Pop-Location }
