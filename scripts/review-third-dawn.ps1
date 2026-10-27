param([switch]$Compatibility, [string]$Screenshot = '', [switch]$Validate, [ValidateSet('Idle','Walk','Run')][string]$Clip = 'Idle')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force "$root/outputs/third-dawn" | Out-Null
foreach ($body in @('human','ogre')) {
    if (!(Test-Path "$root/Viewer/local-art/third-dawn/$body.gltf")) { throw 'Run scripts/import-third-dawn.py --archive PATH first.' }
}
& $godot --headless --path "$root/Viewer" --editor --import
if ($LASTEXITCODE) { throw 'Godot import failed' }
$engineArgs = @('--path', "$root/Viewer", '--script', 'res://Presentation/ThirdDawnReview.gd')
if ($Compatibility) { $engineArgs += @('--rendering-method','gl_compatibility') }
if ($Validate -and !$Screenshot) { $engineArgs += '--headless' }
$userArgs = @("--clip=$Clip")
if ($Screenshot) { $userArgs += "--screenshot=$([IO.Path]::GetFullPath($Screenshot))" }
if ($Validate) { $userArgs += "--report=$root/outputs/third-dawn/engine-validation.json" }
& $godot @engineArgs -- @userArgs
if ($LASTEXITCODE) { throw 'Third Dawn review failed' }
