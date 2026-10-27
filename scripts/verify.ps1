$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
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
& $godot --headless --path "$root/Viewer" --script res://Presentation/ItemResponseTests.gd
if ($LASTEXITCODE) { throw 'Native item response/appearance checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/WorldItemTests.gd
if ($LASTEXITCODE) { throw 'World item/doorway/sign regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/EnvironmentTests.gd
if ($LASTEXITCODE) { throw 'Server environment regression checks failed' }
& $godot --headless --path "$root\Viewer" --script res://Network/GameTests.gd
if ($LASTEXITCODE) { throw 'Game session tests failed' }
& $godot --headless --path "$root\Viewer" --script res://Network/CharacterTests.gd
if ($LASTEXITCODE) { throw 'Character status/skills/sheet tests failed' }
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
$argsForWorld = @()
if (Test-Path "$root\Viewer\play-world.json") { $argsForWorld = @("--world=$root\Viewer\play-world.json") }
elseif (Test-Path "$root\Viewer\local-world.json") { $argsForWorld = @("--world=$root\Viewer\local-world.json") }
& $godot --headless --path "$root\Viewer" --quit-after 3 -- @argsForWorld
if ($LASTEXITCODE) { throw 'World smoke test failed' }
