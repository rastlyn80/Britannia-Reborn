param(
  [Parameter(Mandatory=$true)][string]$WorldPath,
  [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$inputPath = (Resolve-Path -LiteralPath $WorldPath).Path
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root ('outputs/conversions/' + [IO.Path]::GetFileNameWithoutExtension($inputPath)) }
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force $outputPath | Out-Null
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --headless --path "$root/Viewer" --script res://Presentation/ConversionPass.gd -- "--world=$inputPath" "--output=$outputPath"
if ($LASTEXITCODE) { throw 'Shared 3D reconstruction failed; inspect the conversion report for unmapped tiles.' }
