param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$blender=(Get-ChildItem "$root/.tools/blender/*/blender.exe" | Select-Object -First 1).FullName
Push-Location $root
try {
  $verify=@(); if ($VerifyOnly) { $verify=@('--verify-only') }
  foreach ($download in @('download-free-human.py','download-free-equipment.py','download-character-expansion.py')) {
    & python -B -X utf8 "scripts/$download" @verify
    if ($LASTEXITCODE) { throw "Pinned inputs failed: $download" }
  }
  foreach ($female in @($false,$true)) {
    $sex=@(); if ($female) { $sex=@('--female') }
    if (!$VerifyOnly) {
      & $blender --background --factory-startup --python-exit-code 1 --python scripts/fit-uo-to-free-human.py -- --base-only @sex
      if ($LASTEXITCODE) { throw 'Human base build failed' }
      & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-free-equipment.py -- @sex
      if ($LASTEXITCODE) { throw 'Human clothing build failed' }
    }
    & python -B -X utf8 scripts/validate-free-equipment.py @sex
    if ($LASTEXITCODE) { throw 'Actual exported human asset checks failed' }
    & $blender --background --factory-startup --python-exit-code 1 --python scripts/validate-robe-clearance.py -- @sex
    if ($LASTEXITCODE) { throw 'Robe clearance checks failed' }
    if (!$VerifyOnly) {
      & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-character-expansion.py -- @sex
      if ($LASTEXITCODE) { throw 'Expanded equipment/cosmetics build failed' }
    }
  }
  & python -B -X utf8 scripts/validate-character-expansion.py
  if ($LASTEXITCODE) { throw 'Expanded equipment/cosmetic asset checks failed' }
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/validate-expanded-skirts.py
  if ($LASTEXITCODE) { throw 'Expanded skirt animation checks failed' }
} finally { Pop-Location }
