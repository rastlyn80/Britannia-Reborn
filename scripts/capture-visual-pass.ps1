$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force "$root/outputs/validation" | Out-Null
& $godot --path "$root/Viewer" --script res://Presentation/EnvironmentVisual.gd
if ($LASTEXITCODE) { throw 'Rendered environment animation checks failed' }
& $godot --path "$root/Viewer" --script res://Presentation/VisualPassCapture.gd -- "--coverage=$root/outputs/validation/visual-coverage.json"
if ($LASTEXITCODE) { throw 'Visual pass capture failed' }
& $godot --path "$root/Viewer" --script res://Presentation/InteriorCapture.gd
if ($LASTEXITCODE) { throw 'Interior capture failed' }
Write-Output 'Screenshots, animation frames and architectural coverage are in outputs/validation.'

$previewPython = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
if (Test-Path -LiteralPath $previewPython) {
 & $previewPython "$root/scripts/make-environment-previews.py"
 if ($LASTEXITCODE) { throw 'Animated preview assembly failed' }
}
