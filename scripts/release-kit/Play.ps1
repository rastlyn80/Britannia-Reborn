# Britannia Reborn friends' test package: starts this folder's own game
# server (if it is not already running) and the game. Everything stays on this
# computer: the server listens on 127.0.0.1 only.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$runtime = Join-Path $root 'Server\runtime'
$dotnet = Join-Path $root '.tools\dotnet-server\dotnet.exe'
$config = Join-Path $runtime 'Configuration\modernuo.json'

# The UO data travels with the package: point the server at it wherever the
# folder was unzipped.
$settings = Get-Content $config -Raw | ConvertFrom-Json
$settings.dataDirectories = @((Join-Path $root 'UO'))
$settings.listeners = @('127.0.0.1:2593')
$settings | ConvertTo-Json -Depth 12 | Set-Content $config -Encoding UTF8

function Listening {
  $probe = New-Object Net.Sockets.TcpClient
  try { $probe.ConnectAsync('127.0.0.1', 2593).Wait(400) -and $probe.Connected } catch { $false } finally { $probe.Dispose() }
}

if (!(Listening)) {
  Write-Output 'Starting the game server...'
  $env:DOTNET_ROOT = Split-Path $dotnet
  $empty = Join-Path $runtime 'no-input.txt'
  Set-Content -LiteralPath $empty -Value '' -NoNewline
  $log = Join-Path $runtime 'server.log'
  Start-Process -FilePath $dotnet -ArgumentList '.\ModernUO.dll' -WorkingDirectory $runtime -WindowStyle Hidden -RedirectStandardInput $empty -RedirectStandardOutput $log -RedirectStandardError ($log + '.err') | Out-Null
  $deadline = (Get-Date).AddMinutes(4)
  while (!(Listening)) {
    if ((Get-Date) -gt $deadline) { throw "The game server did not start. See $log" }
    Start-Sleep -Seconds 2
  }
  Write-Output 'Game server ready.'
}

Write-Output 'Starting Britannia Reborn...'
& (Join-Path $root 'launch.ps1')
