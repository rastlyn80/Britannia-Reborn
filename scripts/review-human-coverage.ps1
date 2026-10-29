param([string]$Python='python')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 & $Python -B scripts/review-human-coverage.py
 if ($LASTEXITCODE) { throw 'Review job preparation failed' }
 $godot=(Get-ChildItem .tools/godot/*console.exe|Select-Object -First 1).FullName
 $env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
 & $godot --headless --path Viewer --editor --import
 if ($LASTEXITCODE) { throw 'Review asset import failed' }
 & $godot --path Viewer --script res://Presentation/HumanWardrobeCatalogue.gd -- "--jobs=$root/outputs/human-coverage-session/jobs.json"
 if ($LASTEXITCODE) { throw 'Human category review render failed' }
 & $Python -B scripts/review-human-coverage.py --sheets
 if ($LASTEXITCODE) { throw 'Review contact sheet assembly failed; Pillow is required' }
} finally {Pop-Location}
