param([string]$DataDir,[switch]$NoOpen)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 if (!(Test-Path outputs/item-catalog/catalog.js)) {
  $source=@();if($DataDir){$source=@('-DataDir',$DataDir)}
  & ./scripts/build-item-catalog.ps1 @source -NoOpen
 }
 $godot=(Get-ChildItem .tools/godot/*console.exe|Select-Object -First 1).FullName
 $env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
 & $godot --headless --path Viewer --script res://Presentation/CharacterCoverage.gd
 if($LASTEXITCODE){throw 'Human coverage audit failed'}
 $source=@();if($DataDir){$source=@('--data-dir',$DataDir)}
 & python -B -X utf8 scripts/build-human-catalogue.py @source
 if($LASTEXITCODE){throw 'Human catalogue build failed'}
 if(!$NoOpen){Start-Process (Join-Path $root 'outputs/human-catalogue/index.html')}
} finally {Pop-Location}
