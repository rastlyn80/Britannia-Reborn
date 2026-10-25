$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dotnet = Join-Path $root '.tools\dotnet-server\dotnet.exe'
$env:DOTNET_ROOT = Split-Path $dotnet
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
& "$PSScriptRoot\configure-server.ps1"
Push-Location "$root\Server\runtime"
try { & $dotnet '.\ModernUO.dll'; if ($LASTEXITCODE) { throw 'Server stopped with an error' } }
finally { Pop-Location }
