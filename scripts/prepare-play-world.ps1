param(
  [string]$DataDir = "$env:USERPROFILE\OneDrive\Electronic Arts\Ultima Online Classic",
  [int]$X = 1576, [int]$Y = 1568, [int]$Width = 64, [int]$Height = 64,
  [string]$WorldPath, [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& "$root\build.ps1"
if (!$WorldPath) { $WorldPath = Join-Path $root 'Viewer/play-world.json' }
& "$root\.tools\dotnet\dotnet.exe" "$root\Converter\bin\Release\net8.0\Converter.dll" convert $DataDir $WorldPath $X $Y $Width $Height 4096
if ($LASTEXITCODE) { throw 'Britain play-region conversion failed' }
& "$root/scripts/prepare-terrain-halo.ps1" -WorldPath $WorldPath -DataDir $DataDir
& "$root/scripts/reconstruct-world.ps1" -WorldPath $WorldPath -OutputDirectory $OutputDirectory
