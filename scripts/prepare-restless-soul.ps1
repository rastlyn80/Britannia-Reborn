param([string]$Extractor)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$python = Join-Path $root '.tools/pyenv/Scripts/python.exe'
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$review = Join-Path $PSScriptRoot 'restless-soul'

function Invoke-GhostPython([string]$Recipe, [string[]]$Arguments = @()) {
    & $python -B $Recipe @Arguments
    if ($LASTEXITCODE) { throw "Restless Soul recipe failed ($Recipe)" }
}

function Invoke-GhostGodot([string]$Recipe, [string[]]$Arguments = @()) {
    & $godot --headless --path "$root/Viewer" --script (Join-Path $review $Recipe) -- @Arguments
    if ($LASTEXITCODE) { throw "Restless Soul bake failed ($Recipe)" }
}

Push-Location $root
try {
    $extract = if ($Extractor) { @('--extractor', $Extractor) } else { @() }
    Invoke-GhostPython "$PSScriptRoot/prepare-ghost-donor-library.py" $extract
    Invoke-GhostGodot 'export-ghost-silhouette-poses.gd' @('--library')
    Invoke-GhostPython "$review/compare-ghost-silhouettes.py"
    Invoke-GhostPython "$review/fit-ghost-hood.py"
    Invoke-GhostGodot 'bake-ghost-on-foot-preview.gd' @('--hood')
    Invoke-GhostGodot 'export-ghost-silhouette-poses.gd' @('--on-foot')
    Invoke-GhostPython "$review/fit-ghost-registration.py"
    Invoke-GhostGodot 'bake-ghost-on-foot-preview.gd' @('--hood', '--fit')
    Invoke-GhostGodot 'export-ghost-silhouette-poses.gd' @('--on-foot')
    Invoke-GhostPython "$review/review-ghost-on-foot.py"
    Invoke-GhostGodot 'stage-ghost-on-foot-preview.gd'
}
finally {
    Pop-Location
}
