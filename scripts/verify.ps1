$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& python -B "$root/scripts/test-uo-human-sequences.py"
if ($LASTEXITCODE) { throw 'Human sequence parser bounds/format checks failed' }
& python -B "$root/scripts/test-mhclo.py"
if ($LASTEXITCODE) { throw 'Static clothing importer checks failed' }
& "$root/scripts/prepare-surfaces.ps1" -VerifyOnly
& "$root/scripts/import-reviewed-art.ps1" -VerifyOnly
& "$root/scripts/prepare-polyhaven.ps1" -VerifyOnly
& "$root\build.ps1"
if (Test-Path "$root/Server/runtime/Server.dll") { & "$root/scripts/build-preview-tools.ps1" -BuildOnly }
$godot = (Get-ChildItem "$root\.tools\godot\*console.exe" | Select-Object -First 1).FullName
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
& $godot --headless --path "$root\Viewer" --editor --import
if ($LASTEXITCODE) { throw 'Asset import failed' }
& $godot --headless --path "$root\Viewer" --script res://Network/LoginTests.gd
if ($LASTEXITCODE) { throw 'Protocol tests failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/ArtFidelityTests.gd
if ($LASTEXITCODE) { throw 'Reviewed asset/support regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/MinimapTests.gd
if ($LASTEXITCODE) { throw 'Native radar/minimap tests failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/PreparedTests.gd
if ($LASTEXITCODE) { throw 'Prepared resource/source/instancing checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/LiveDistrictTests.gd
if ($LASTEXITCODE) { throw 'Live district readiness checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/RegionalSeamTests.gd
if ($LASTEXITCODE) { throw 'Regional architecture/terrain seam checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/AtlasTests.gd
if ($LASTEXITCODE) { throw 'World atlas regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/CommerceUiTests.gd
if ($LASTEXITCODE) { throw 'Commerce/gump UI checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/CommerceTests.gd
if ($LASTEXITCODE) { throw 'Native commerce/inventory regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/GumpTests.gd
if ($LASTEXITCODE) { throw 'Native gump layout/response checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/QuickbarTests.gd
if ($LASTEXITCODE) { throw 'Quickbar/classic macro action checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/FrontEndTests.gd
if ($LASTEXITCODE) { throw 'Front end / game menu checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/ProtocolTests.gd
if ($LASTEXITCODE) { throw 'Protocol coverage/fixture checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/CraftTests.gd
if ($LASTEXITCODE) { throw 'Crafting window checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/FuzzTests.gd
if ($LASTEXITCODE) { throw 'Malformed-packet fuzz checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/MovableTests.gd
if ($LASTEXITCODE) { throw 'Movable panel checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/ProfileTests.gd
if ($LASTEXITCODE) { throw 'Per-character settings checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/ItemResponseTests.gd
if ($LASTEXITCODE) { throw 'Native item response/appearance checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/WorldItemTests.gd
if ($LASTEXITCODE) { throw 'World item/doorway/sign regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/EnvironmentTests.gd
if ($LASTEXITCODE) { throw 'Server environment regression checks failed' }
& $godot --headless --path "$root\Viewer" --script res://Network/GameTests.gd
if ($LASTEXITCODE) { throw 'Game session tests failed' }
if (Test-Path "$root/Viewer/local-art/free-equipment-female/runtime/body-mask-31.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanBatchTests.gd
  if ($LASTEXITCODE) { throw 'Male/female shared wardrobe checks failed' }
}
if (Test-Path "$root/Viewer/local-art/free-equipment-female/expansion/closed_helmet.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/CharacterExpansionTests.gd
  if ($LASTEXITCODE) { throw 'Expanded equipment/cosmetic checks failed' }
}
if (Test-Path "$root/Viewer/local-art/free-equipment-female/expansion/shirt.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanWardrobeBatchTests.gd
  if ($LASTEXITCODE) { throw 'Civilian wardrobe/native dye checks failed' }
}
if (Test-Path "$root/Viewer/local-art/free-equipment-female/expansion/cloak.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanCivilianTests.gd
  if ($LASTEXITCODE) { throw 'Layered civilian clothing/footwear checks failed' }
}
& $godot --headless --path "$root\Viewer" --script res://Network/CharacterTests.gd
if ($LASTEXITCODE) { throw 'Character status/skills/sheet tests failed' }
if (Test-Path "$root/Viewer/local-art/free-equipment-female/motion/human-motion.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanMotionTests.gd
  if ($LASTEXITCODE) { throw 'Prepared human motion checks failed' }
}
if (Test-Path "$root/Viewer/local-art/free-equipment-female/coverage/crossbow.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanCoverageTests.gd
  if ($LASTEXITCODE) { throw 'Human category coverage checks failed' }
}
if (Test-Path "$root/Viewer/local-art/horses/warhorse.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HorseTests.gd
  if ($LASTEXITCODE) { throw 'Horse identity, mounted actions and rider contact checks failed' }
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HorsePolishTests.gd
  if ($LASTEXITCODE) { throw 'Horse appearance, transitions and slope support checks failed' }
}
& $godot --headless --path "$root\Viewer" --script res://Presentation/PresentationTests.gd
if ($LASTEXITCODE) { throw 'Presentation tests failed' }
& $godot --headless --path "$root\Viewer" --script res://Presentation/GraphicsTests.gd
if ($LASTEXITCODE) { throw 'Graphics/camera/traversal tests failed' }
& $godot --headless --path "$root\Viewer" --script res://Network/InputMemoryTests.gd
if ($LASTEXITCODE) { throw 'Mouse input/login memory tests failed' }
& $godot --headless --path "$root\Viewer" --script res://Presentation/StreetTests.gd
if ($LASTEXITCODE) { throw 'Street reconstruction/retargeted movement tests failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/VisualPassTests.gd
if ($LASTEXITCODE) { throw 'Shared architectural/nature presentation tests failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/SurfacePolishTests.gd
if ($LASTEXITCODE) { throw 'Terrain/shoreline/PBR surface regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/ContactTests.gd
if ($LASTEXITCODE) { throw 'Interior/stair/foot-contact regression checks failed' }
# Developer edit session: server logic (no ModernUO needed) and client overlay.
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
Push-Location "$root/Server/PreviewTools.Tests"
try { & "$root/.tools/dotnet-server/dotnet.exe" run -c Release }
finally { Pop-Location }
if ($LASTEXITCODE) { throw 'Developer edit session tests failed' }
& $godot --headless --path "$root/Viewer" --script res://DevEdit/DevEditTests.gd
if ($LASTEXITCODE) { throw 'Developer edit overlay tests failed' }
$argsForWorld = @()
if (Test-Path "$root\Viewer\play-world.json") { $argsForWorld = @("--world=$root\Viewer\play-world.json") }
elseif (Test-Path "$root\Viewer\local-world.json") { $argsForWorld = @("--world=$root\Viewer\local-world.json") }
& $godot --headless --path "$root\Viewer" --quit-after 3 -- @argsForWorld
if ($LASTEXITCODE) { throw 'World smoke test failed' }
