param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 $sourceArgs=@();if($VerifyOnly){$sourceArgs=@('--verify-only')}
 & python -B scripts/download-character-expansion.py @sourceArgs
 if($LASTEXITCODE){throw 'Pinned wardrobe inputs failed'}
 $blender=(Get-ChildItem .tools/blender/*/blender.exe|Select-Object -First 1).FullName
 foreach($suffix in @('','-female')) {
  if(!(Test-Path "Viewer/local-art/free-equipment$suffix/motion/human-motion.glb")) {
   throw 'Prepare the existing free bodies/runtime wardrobe, then prepare-human-motion.ps1 before accepting the civilian batch.'
  }
  if(!$VerifyOnly) {
   $sexArgs=@();if($suffix){$sexArgs=@('--','--female')}
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-character-expansion.py @sexArgs
   if($LASTEXITCODE){throw 'Wardrobe preparation failed'}
  }
 }
 & python -B scripts/validate-character-expansion.py
 if($LASTEXITCODE){throw 'Exported wardrobe bindings failed'}
 & $blender --background --factory-startup --python-exit-code 1 --python scripts/validate-human-civilian-clothes.py
 if($LASTEXITCODE){throw 'Civilian motion contacts failed'}
} finally {Pop-Location}
