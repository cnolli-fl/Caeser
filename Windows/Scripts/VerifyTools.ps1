[CmdletBinding()]
param([string]$ToolsDirectory = (Join-Path $PSScriptRoot '..\.tools\win-x64'))
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Verificação destinada ao Windows.' }
$directory = [IO.Path]::GetFullPath($ToolsDirectory)
$windowsRoot = Split-Path $PSScriptRoot -Parent
$work = Join-Path $windowsRoot ('.cache\verify-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
foreach ($folder in @('profile', 'appdata', 'localappdata')) {
    New-Item -ItemType Directory -Path (Join-Path $work $folder) -Force | Out-Null
}
function Invoke-Tool([string]$Name, [string[]]$Arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new((Join-Path $directory $Name))
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WorkingDirectory = $work
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.Environment['PATH'] = "$directory;$([Environment]::SystemDirectory);$($env:SystemRoot)"
    foreach ($key in @('PYTHONPATH', 'PYTHONHOME', 'VIRTUAL_ENV', 'SSL_CERT_FILE', 'REQUESTS_CA_BUNDLE')) {
        [void]$start.Environment.Remove($key)
    }
    $start.Environment['USERPROFILE'] = Join-Path $work 'profile'
    $start.Environment['APPDATA'] = Join-Path $work 'appdata'
    $start.Environment['LOCALAPPDATA'] = Join-Path $work 'localappdata'
    $start.Environment['DENO_NO_UPDATE_CHECK'] = '1'
    $start.Environment['PYTHONUTF8'] = '1'
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) {
            $process.Kill($true)
            throw "$Name não terminou a verificação em 60 segundos."
        }
        $output = $stdout.GetAwaiter().GetResult()
        $errors = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "$Name falhou: $errors $output" }
        return $output + $errors
    } finally { $process.Dispose() }
}
$versions = @{}
[void](Invoke-Tool 'spotdl.exe' @('--caeser-runtime-check'))
foreach ($name in @('yt-dlp.exe', 'ffmpeg.exe', 'ffprobe.exe', 'deno.exe', 'spotdl.exe')) {
    if (-not (Test-Path (Join-Path $directory $name))) { throw "Pacote incompleto: $name" }
    $versionArgs = if ($name -in @('ffmpeg.exe', 'ffprobe.exe')) { @('-version') } else { @('--version') }
    $versions[$name] = Invoke-Tool $name $versionArgs
}
$config = Invoke-Tool 'ffmpeg.exe' @('-buildconf')
if ($config -match '--enable-gpl|--enable-nonfree' -or $config -notmatch '--enable-schannel') {
    throw 'Configuração FFmpeg inesperada: verificar licença e HTTPS antes de empacotar.'
}
$audio = Join-Path $work 'música de teste 100% {mix}.mp3'
[void](Invoke-Tool 'ffmpeg.exe' @('-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=0.2', '-c:a', 'libmp3lame', '-q:a', '0', $audio))
$probe = Invoke-Tool 'ffprobe.exe' @('-v', 'error', '-show_entries', 'stream=codec_name', '-of', 'json', $audio)
if (($probe | ConvertFrom-Json).streams[0].codec_name -ne 'mp3') { throw 'A conversão real para MP3 falhou.' }
$versions | ConvertTo-Json -Depth 3 | Set-Content -Encoding utf8 (Join-Path $directory 'versions.json')
Write-Host 'Cinco ferramentas abriram sem Python, FFmpeg ou Deno externos. Conversão MP3 verificada.'
