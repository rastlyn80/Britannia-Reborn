$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force "$root/outputs/validation" | Out-Null
& $godot --path "$root/Viewer" --script res://Presentation/StabilityVisual.gd
if ($LASTEXITCODE) { throw 'Moving-camera floor/doorway/bank checks failed' }

$previewPython = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
if (Test-Path -LiteralPath $previewPython) {
  & $previewPython "$root/scripts/make-stability-previews.py"
  if ($LASTEXITCODE) { throw 'Moving-camera GIF encoding failed' }
}
