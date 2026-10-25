param([string]$Godot,[switch]$Local)
$ErrorActionPreference = 'Stop'
if (!$Godot) { $Godot = (Get-ChildItem "$PSScriptRoot\.tools\godot\*console.exe" | Select-Object -First 1).FullName }
$env:APPDATA = Join-Path $PSScriptRoot '.godot-user'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$worldArgs = @()
$prefix = ''
if ($Local) { $worldArgs = @("--world=$PSScriptRoot\Viewer\local-world.json"); $prefix = 'local-' }
& $Godot --headless --path "$PSScriptRoot\Viewer" --quit-after 3 -- @worldArgs
if ($LASTEXITCODE) { throw 'Viewer validation failed' }
& $Godot --path "$PSScriptRoot\Viewer" -- @worldArgs "--screenshot=$PSScriptRoot\${prefix}screenshot-overview.png"
if ($LASTEXITCODE) { throw 'Overview capture failed' }
& $Godot --path "$PSScriptRoot\Viewer" -- @worldArgs --close-view "--screenshot=$PSScriptRoot\${prefix}screenshot-close.png"
if ($LASTEXITCODE) { throw 'Close capture failed' }
