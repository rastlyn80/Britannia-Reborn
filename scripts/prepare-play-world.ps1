param([string]$DataDir = "$env:USERPROFILE\OneDrive\Electronic Arts\Ultima Online Classic")
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& "$root\build.ps1"
& "$root\.tools\dotnet\dotnet.exe" "$root\Converter\bin\Release\net8.0\Converter.dll" convert $DataDir "$root\Viewer\play-world.json" 1576 1568 64 64 4096
if ($LASTEXITCODE) { throw 'Britain play-region conversion failed' }
