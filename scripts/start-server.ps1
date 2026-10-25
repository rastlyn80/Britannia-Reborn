$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dotnet = Join-Path $root '.tools\dotnet-server\dotnet.exe'
$env:DOTNET_ROOT = Split-Path $dotnet
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$probe = [System.Net.Sockets.TcpClient]::new()
try {
  $connection = $probe.ConnectAsync('127.0.0.1',2593)
  if ($connection.Wait(500) -and $probe.Connected) { throw 'A server is already listening on 127.0.0.1:2593. Use the running server; do not start a second instance.' }
} catch [System.AggregateException] {
  if ($_.Exception.InnerException -is [System.Net.Sockets.SocketException] -and $_.Exception.InnerException.SocketErrorCode -eq 'AccessDenied') { throw 'Network sandbox blocked the listener check. Run this server with approved local network access.' }
} finally { $probe.Dispose() }
& "$PSScriptRoot\configure-server.ps1"
$lock = $null
try { $lock = [System.IO.File]::Open("$root\Server\runtime\.server.lock",[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None) }
catch { throw 'This runtime is already in use by another server process.' }
Push-Location "$root\Server\runtime"
try { & $dotnet '.\ModernUO.dll'; if ($LASTEXITCODE) { throw 'Server stopped with an error' } }
finally { Pop-Location; $lock.Dispose() }
