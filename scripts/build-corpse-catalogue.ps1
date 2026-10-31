param([switch]$Render,[switch]$IndexOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$arguments=@('--path',"$root/Viewer",'--script','res://Presentation/CorpseCatalogue.gd')
if (!$Render) {$arguments=@('--headless')+$arguments}
if ($Render) {$arguments+=@('--','--render')}
if ($IndexOnly) {$arguments+=@('--','--index-only')}
& $godot @arguments
if ($LASTEXITCODE) {throw 'Corpse model/catalogue checks failed'}
Copy-Item -LiteralPath "$root/scripts/corpse-catalogue.html" -Destination "$root/outputs/corpses/index.html" -Force
Write-Output "Corpse graphics catalogue: $root/outputs/corpses/index.html"
