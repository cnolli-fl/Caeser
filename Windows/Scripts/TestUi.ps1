[CmdletBinding()]
param(
    [string]$ApplicationDirectory = (Join-Path $PSScriptRoot '..\artifacts\app'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\artifacts\ui-smoke')
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Este teste abre o aplicativo real em um desktop Windows.' }
$application = Join-Path ([IO.Path]::GetFullPath($ApplicationDirectory)) 'Caeser.exe'
$output = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ('run-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output -Force | Out-Null
$process = Start-Process -FilePath $application -ArgumentList @('--smoke-test', ('"' + $output + '"')) -PassThru
if (-not $process.WaitForExit(60000)) {
    $process.Kill($true)
    throw 'O aplicativo não concluiu o teste de interface em 60 segundos.'
}
$resultFile = Join-Path $output 'result.json'
if (-not (Test-Path $resultFile)) {
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddMinutes(-2) } -ErrorAction SilentlyContinue |
        Where-Object { $_.ProviderName -in @('Application Error', '.NET Runtime', 'Windows Error Reporting') } |
        Select-Object -First 4 TimeCreated, ProviderName, Message | Format-List
    throw "O aplicativo encerrou sem confirmar o teste. Código: $($process.ExitCode)"
}
$result = Get-Content -Raw $resultFile | ConvertFrom-Json
if (Test-Path (Join-Path $output 'xaml-diagnostics.txt')) {
    Get-Content (Join-Path $output 'xaml-diagnostics.txt') -Tail 80 | Write-Host
}
if (-not $result.succeeded) { throw "Falha no teste de interface: $($result.error)" }
if (@(Get-ChildItem $output -Filter '*.png').Count -ne 4) { throw 'As quatro capturas de tema/origem não foram geradas.' }
Write-Host 'Interface aberta e verificada: YouTube/Spotify, claro/escuro, link inválido e foco de teclado.'
