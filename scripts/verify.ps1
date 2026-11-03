$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& python -B "$root/scripts/test-uo-human-sequences.py"
if ($LASTEXITCODE) { throw 'Human sequence parser bounds/format checks failed' }
& python -B "$root/scripts/test-mhclo.py"
if ($LASTEXITCODE) { throw 'Static clothing importer checks failed' }
& python -B "$root/scripts/test-third-dawn.py"
if ($LASTEXITCODE) { throw 'Bounded Third Dawn parser / refinement checks failed' }
& python -B "$root/scripts/test-eight-influence-skin.py"
if ($LASTEXITCODE) {throw 'Explicit eight-slot skin export/refinement boundaries or legacy golden outputs failed'}
& python -B "$root/scripts/test-eight-influence-skin.py" --fixture
if ($LASTEXITCODE) {throw 'Source-free five-influence fixture generation failed'}
& python -B "$root/scripts/test-creature-pipeline.py"
if ($LASTEXITCODE) {throw 'Creature rig/visible-geometry/reader regression checks failed'}
& python -B "$root/scripts/test-creature-mage-masks.py"
if ($LASTEXITCODE) {throw 'Creature garment dye isolation or source-buffer preservation failed'}
& python -B "$root/scripts/test-creature-priority.py"
if ($LASTEXITCODE) {throw 'Creature occurrence ordering checks failed'}
& python -B "$root/scripts/test-creature-humanoid-actions.py"
if ($LASTEXITCODE) {throw 'Creature gesture limb-length, stance and source-grip checks failed'}
& python -B "$root/scripts/test-creature-cervid-actions.py"
if ($LASTEXITCODE) {throw 'Cervid four-hoof, cervical motion and source-identity checks failed'}
if (Test-Path "$root/Server/ModernUO/Projects/UOContent/Engines/Ethics/Core/Ethic.cs") {
 & python -B "$root/scripts/prepare-server-fixes.py" --verify-only
 if ($LASTEXITCODE) {throw 'Reviewed server overlay source/anchor audit failed'}
}
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
if (Test-Path "$root/Viewer/local-art/creatures/source_variants/preparation.json") {
 & python -B "$root/scripts/prepare-source-variants.py" --check-prepared
 if ($LASTEXITCODE) {throw 'Source variant exact-source/donor/scene audit failed'}
 $variantSkin = & $godot --headless --path "$root/Viewer" --script res://Presentation/SourceVariantSkinTests.gd 2>&1
 $variantExit = $LASTEXITCODE
 $variantSkin | ForEach-Object {Write-Output $_}
 if ($variantExit -or ($variantSkin | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Exact saved source variants/static corpses failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/source_preserving/preparation.json") {
 & python -B "$root/scripts/prepare-source-preserving.py" --check-prepared
 if ($LASTEXITCODE) {throw 'Source-preserving candidate input/scene audit failed'}
 $preservingSkin = & $godot --headless --path "$root/Viewer" --script res://Presentation/SourcePreservingSkinTests.gd 2>&1
 $preservingExit = $LASTEXITCODE
 $preservingSkin | ForEach-Object {Write-Output $_}
 if ($preservingExit -or ($preservingSkin | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Saved source-preserving skins/static corpses failed'}
 $preservingActions = & $godot --headless --path "$root/Viewer" --script res://Presentation/SourcePreservingActionTests.gd 2>&1
 $preservingActionExit = $LASTEXITCODE
 $preservingActions | ForEach-Object {Write-Output $_}
 if ($preservingActionExit -or ($preservingActions | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Source-preserving action/material/skin reuse failed'}
 if (Test-Path "$root/Viewer/local-art/creatures/source_preserving/local-presentation.json") {
  & python -B "$root/scripts/accept-source-preserving.py" --check-active
  if ($LASTEXITCODE) {throw 'Activated local source presentations lack current exact evidence'}
 }
 $sourceForms = (Get-Content "$root/Viewer/local-art/creatures/source_preserving/preparation.json" -Raw | ConvertFrom-Json).models
 if (($sourceForms | Where-Object {$_.kind -in @('swamp_dragon','swamp_dragon_armor')}).Count -eq 2) {
  $swampRiding = & $godot --headless --path "$root/Viewer" --script res://Presentation/SwampDragonRidingTests.gd 2>&1
  $swampExit = $LASTEXITCODE
  $swampRiding | ForEach-Object {Write-Output $_}
  if ($swampExit -or ($swampRiding | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Prepared Swamp Dragon native-item/rider/barding-form presentation failed'}
 }
 if (($sourceForms | Where-Object {$_.kind -like 'ridgeback_*'}).Count -eq 3 -and (Test-Path "$root/Viewer/local-art/human-npcs/savages/riders.json")) {
  & python -B "$root/scripts/prepare-savage-profiles.py" --check-inputs
  if ($LASTEXITCODE) {throw 'Savage Rider exact reference/native/human input pins failed'}
  $ridgebackRiding = & $godot --headless --path "$root/Viewer" --script res://Presentation/RidgebackRidingTests.gd 2>&1
  $ridgebackExit = $LASTEXITCODE
  $ridgebackRiding | ForEach-Object {Write-Output $_}
  if ($ridgebackExit -or ($ridgebackRiding | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Original Ridgeback/Savage Rider presentation failed'}
  $mountedDeath = & $godot --headless --path "$root/Viewer" --script res://Presentation/MountedHumanDeathTests.gd 2>&1
  $mountedDeathExit = $LASTEXITCODE
  $mountedDeath | ForEach-Object {Write-Output $_}
  if ($mountedDeathExit -or ($mountedDeath | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Mounted human/Savage Rider death handoff failed'}
 }
}
if (Test-Path "$root/Viewer/local-art/creatures/solen_warriors/preparation.json") {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/ConfigureSolenWarriorImport.gd
 if ($LASTEXITCODE) {throw 'Bounded original warrior motion/atlas import configuration failed'}
 $warriorImport=Get-Content "$root/work/creatures/solen-warriors/import-settings.json" -Raw | ConvertFrom-Json
 if ($warriorImport.changed -gt 0) {
  & $godot --headless --path "$root/Viewer" --editor --import
  if ($LASTEXITCODE) {throw 'Precise original warrior motion/atlas reimport failed'}
  & $godot --headless --path "$root/Viewer" --script res://Presentation/ConfigureSolenWarriorImport.gd
  if ($LASTEXITCODE -or (Get-Content "$root/work/creatures/solen-warriors/import-settings.json" -Raw | ConvertFrom-Json).changed -ne 0) {throw 'Warrior import settings did not settle after actual reimport'}
 }
 & $godot --headless --path "$root/Viewer" --script res://Presentation/SolenWarriorImportTests.gd
 if ($LASTEXITCODE) {throw 'Saved warrior rig/weighted skin/UV/topology/atlas fidelity failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/ice_elementals/candidate.json") {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/ConfigureIceElementalImport.gd
 if ($LASTEXITCODE) {throw 'Bounded original Ice motion/atlas import configuration failed'}
 if ((Get-Content "$root/work/creatures/ice-elemental/import-settings.json" -Raw | ConvertFrom-Json).changed -gt 0) {
  & $godot --headless --path "$root/Viewer" --editor --import
  if ($LASTEXITCODE) {throw 'Precise original Ice motion/atlas reimport failed'}
  & $godot --headless --path "$root/Viewer" --script res://Presentation/ConfigureIceElementalImport.gd
  if ($LASTEXITCODE -or (Get-Content "$root/work/creatures/ice-elemental/import-settings.json" -Raw | ConvertFrom-Json).changed -ne 0) {throw 'Ice import settings did not settle after actual reimport'}
 }
 & $godot --headless --path "$root/Viewer" --script res://Presentation/IceElementalImportTests.gd
 if ($LASTEXITCODE) {throw 'Original Ice saved-import source motion/skin/atlas fidelity failed'}
}
& $godot --headless --path "$root/Viewer" --script res://Presentation/EightInfluenceImportTests.gd
if ($LASTEXITCODE) {throw 'Actual eight-slot GLTF import, fifth-joint deformation or static corpse failed'}
& $godot --headless --path "$root/Viewer" --script res://Presentation/CreatureActionRoutingTests.gd
if ($LASTEXITCODE) {throw 'Native animal/sea/monster action semantics failed'}
& $godot --headless --path "$root/Viewer" --script res://Presentation/CorpseAttributeTests.gd
if ($LASTEXITCODE) {throw 'Static corpse custom UV/attribute format preservation failed'}
& $godot --headless --path "$root/Viewer" --script res://Presentation/SavagePaintAttributeTests.gd
if ($LASTEXITCODE) {throw 'Human NPC paint/source attributes, 16/32-bit LOD or static snapshot preservation failed'}
if (Test-Path "$root/Viewer/local-art/creatures/accepted-index.json") {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/CreatureDeathTests.gd
 if ($LASTEXITCODE) {throw 'Existing generic decoded creature-death transitions or lifecycle regressed'}
}
if (Test-Path "$root/Viewer/local-art/human-npcs/savages/dance/preparation.json") {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanNPCMotionTests.gd
 if ($LASTEXITCODE) {throw 'Exact NPC motion isolation, gait/pause restoration or gender/hash guards failed'}
 & $godot --headless --path "$root/Viewer" --script res://Presentation/SavageActionIntegrationTests.gd
 if ($LASTEXITCODE) {throw 'Prepared Savage111 controller, timing, source lift or profile restoration failed'}
 & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanNPCGroundTests.gd
 if ($LASTEXITCODE) {throw 'Prepared NPC finite-ground transitions, complete skin, source rotations or fixed leg lengths failed'}
}
if (Test-Path "$root/Viewer/local-art/human-npcs/shared/death-preparation.json") {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanDeathFloorTests.gd
 if ($LASTEXITCODE) {throw 'Exact human death-floor dense/off-grid skin or source signature checks failed'}
 & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanNPCDeathTests.gd
 if ($LASTEXITCODE) {throw 'Decoded human death/corpse snapshot or lifecycle checks failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/walking_dead_mummy-ground.json") {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/MummySourcePoseTests.gd
 if ($LASTEXITCODE) {throw 'Prepared Mummy source/refined rig or complete-skin residual lookup failed'}
 foreach ($trial in @('MummyRuntimeTests','MummyTerrainTests','MummyDeathTests')) {
  & $godot --headless --path "$root/Viewer" --script "res://Presentation/$trial.gd"
  if ($LASTEXITCODE) {throw "Prepared Mummy avatar/terrain/death test failed: $trial"}
 }
 & python -B "$root/scripts/check-prepared-mummy.py" --runtime
 if ($LASTEXITCODE) {throw 'Exact prepared Mummy source/curve/asset evidence failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/black_ant_warrior-ground.json") {
 foreach ($trial in @('SolenWarriorSourceTests','SolenWarriorRuntimeTests','SolenWarriorTerrainTests','SolenWarriorDeathTests')) {
  & $godot --headless --path "$root/Viewer" --script "res://Presentation/$trial.gd"
  if ($LASTEXITCODE) {throw "Prepared eight-slot Solen warrior test failed: $trial"}
 }
 & python -B "$root/scripts/check-solen-warrior-sources.py" --fidelity
 if ($LASTEXITCODE) {throw 'Exact original Solen warrior source/import/action/corpse proof failed'}
}
if (Test-Path "$root/work/creatures/ice-elemental/prepared/elementals_ice_elemental-ground.json") {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/IceElementalSourceTests.gd
 if ($LASTEXITCODE) {throw 'Original Ice source/refined skin or measured model support failed'}
 & python -B "$root/scripts/check-source-ice-elemental.py"
 if ($LASTEXITCODE) {throw 'Exact original Ice source/recipe/asset pins failed'}
 if (Test-Path "$root/Viewer/local-art/creatures/ice_elementals/candidate.json") {
  foreach ($trial in @('IceElementalRuntimeTests','IceElementalTerrainTests','IceElementalDeathTests')) {
   & $godot --headless --path "$root/Viewer" --script "res://Presentation/$trial.gd"
   if ($LASTEXITCODE) {throw "Original Ice candidate stage failed: $trial"}
  }
  & python -B "$root/scripts/check-source-ice-elemental.py" --candidate
  if ($LASTEXITCODE) {throw 'Exact original Ice candidate imports/avatar/terrain/death proof failed'}
 }
}
if (Test-Path "$root/Viewer/Art/Creatures/Birds/small-bird.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/BirdMotionTests.gd -- --asset=res://Art/Creatures/Birds/small-bird.glb
  if ($LASTEXITCODE) {throw 'Licensed bird skin, action continuity and static corpse checks failed'}
  & python -B "$root/scripts/test-bird-distribution.py"
  if ($LASTEXITCODE) {throw 'Public bird distribution requires private art or has a startup error'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Water/water-elemental.scn") {
  & python -B "$root/scripts/test-water-distribution.py"
  if ($LASTEXITCODE) {throw 'Public water elemental distribution, actions or static puddle failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Dolphin/dolphin.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/DolphinMotionTests.gd -- --asset=res://Art/Creatures/Dolphin/dolphin.glb
  if ($LASTEXITCODE) {throw 'Distributed dolphin skin and cetacean motion checks failed'}
  & python -B "$root/scripts/test-dolphin-distribution.py"
  if ($LASTEXITCODE) {throw 'Public dolphin distribution requires private inputs or has a startup error'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Rat/rat.glb") {
  & python -B "$root/scripts/test-rat-distribution.py"
  if ($LASTEXITCODE) {throw 'Public rat skin, action, four-leg and static corpse distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Cat/cat.glb") {
  & python -B "$root/scripts/test-cat-distribution.py"
  if ($LASTEXITCODE) {throw 'Public cat skin, physical-speed gaits, four-paw support and corpse distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Eagle/eagle.glb") {
  & python -B "$root/scripts/test-eagle-distribution.py"
  if ($LASTEXITCODE) {throw 'Public eagle skin, flight transitions and static corpse distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Rabbit/rabbit.glb") {
  & python -B "$root/scripts/test-rabbit-distribution.py"
  if ($LASTEXITCODE) {throw 'Public rabbit skins, source hop, alpha/normal maps and static corpse distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Wisp/wisp.scn") {
  & python -B "$root/scripts/test-wisp-distribution.py"
  if ($LASTEXITCODE) {throw 'Public Wisp rig/actions, deterministic energy phase and static corpse distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Air/air-elemental.scn") {
  & python -B "$root/scripts/test-air-distribution.py"
  if ($LASTEXITCODE) {throw 'Public AirElemental rig/actions, spectral hue and static dust distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Bogling/bogling.glb") {
  & python -B "$root/scripts/test-bogling-distribution.py"
  if ($LASTEXITCODE) {throw 'Public Bogling rig, normal maps, action skins and static corpse distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Fire/fire-elemental.scn") {
  & python -B "$root/scripts/test-fire-distribution.py"
  if ($LASTEXITCODE) {throw 'Public FireElemental rig/actions, static ash and transient death cleanup distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Chicken/chicken.glb") {
  & python -B "$root/scripts/test-chicken-distribution.py"
  if ($LASTEXITCODE) {throw 'Public Chicken source motions, authored gaits, PBR maps, skin bounds and cadaver distribution failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/serpents_snake_giant_ice-ground.json") {
  $iceTransitions = & $godot --headless --path "$root/Viewer" --script res://Presentation/IceSerpentTransitionTests.gd 2>&1
  $iceTransitionExit = $LASTEXITCODE
  $iceTransitions | ForEach-Object {Write-Output $_}
  if ($iceTransitionExit -or ($iceTransitions | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Ice serpent mixed poses, terrain transitions or native action duration failed'}
  $iceChecks = & $godot --headless --path "$root/Viewer" --script res://Presentation/IceSerpentActionTests.gd 2>&1
  $iceExit = $LASTEXITCODE
  $iceChecks | ForEach-Object {Write-Output $_}
  if ($iceExit -or ($iceChecks | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Ice serpent retained-source skins, sampled floor corrections, bounds and action routing failed'}
}
foreach ($kind in @('desert','forest','frenzied','ethereal')) {
 if (Test-Path "$root/Viewer/local-art/ostards/$kind-modern.gltf") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/OstardTests.gd -- "--kind=$kind"
  if ($LASTEXITCODE) { throw 'Original/refined ostard deformation checks failed' }
 }
}
if ((Test-Path "$root/Viewer/local-art/mounts/kirin-modern.gltf") -and (Test-Path "$root/Viewer/local-art/mounts/llama_ethereal-modern.gltf") -and (Test-Path "$root/Viewer/local-art/mounts/skeletal-horse.glb")) {
 foreach ($script in @('DistinctMountTests','OstardRidingTests','MountTerrainTests','EquineCompletionTests','AnimalActionTests')) {
  & $godot --headless --path "$root/Viewer" --script "res://Presentation/$script.gd"
  if ($LASTEXITCODE) {throw "Distinct mount validation failed: $script"}
 }
}
if (Test-Path "$root/Viewer/local-art/animals/bovine_bull_spotted-modern.gltf") {
 & python -B "$root/scripts/audit-bovines.py"
 if ($LASTEXITCODE) {throw 'Native bovine identity/interaction audit failed'}
 & $godot --headless --path "$root/Viewer" --script res://Presentation/BovineTests.gd
 if ($LASTEXITCODE) {throw 'Bovine native identity/source skin/contact checks failed'}
}
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
& $godot --headless --path "$root/Viewer" --script res://Presentation/CompactStreamingTests.gd
if ($LASTEXITCODE) { throw 'Compact streaming cache rule checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/UndergroundTests.gd
if ($LASTEXITCODE) { throw 'Dungeon, cave entrance and death presentation checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/TranslatorTests.gd
if ($LASTEXITCODE) { throw 'Live translation presentation checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/ReliefTests.gd
if ($LASTEXITCODE) { throw 'Mountain relief checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Network/StackSplitTests.gd
if ($LASTEXITCODE) { throw 'Stack splitting checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/PersonalSpaceTests.gd
if ($LASTEXITCODE) { throw 'Personal space checks failed' }
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
& $godot --headless --path "$root/Viewer" --script res://Network/PolishTests.gd
if ($LASTEXITCODE) { throw 'Gameplay polish (gains, paperdoll, target, cast bar) checks failed' }
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
if (Test-Path "$root/Viewer/local-art/free-equipment-female/coverage/gilded_dress_riding.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanWardrobe50LayerTests.gd
  if ($LASTEXITCODE) { throw 'Native wardrobe layer/variant checks failed' }
}
if (Test-Path "$root/Viewer/local-art/free-equipment-female/coverage/legacy_long_dress_riding.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanWardrobe65LayerTests.gd
  if ($LASTEXITCODE) { throw 'Native historical wardrobe layer/variant checks failed' }
}
if (Test-Path "$root/Viewer/local-art/horses/warhorse.glb") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HorseTests.gd
  if ($LASTEXITCODE) { throw 'Horse identity, mounted actions and rider contact checks failed' }
  & $godot --headless --path "$root/Viewer" --script res://Presentation/RiderHandsTests.gd
  if ($LASTEXITCODE) { throw 'Rider wrist, rein grip and held-equipment checks failed' }
  & $godot --headless --path "$root/Viewer" --script res://Presentation/HorsePolishTests.gd
  if ($LASTEXITCODE) { throw 'Horse appearance, transitions and slope support checks failed' }
  if (Test-Path "$root/Server/ModernUO/Projects/UOContent/Mobiles/Animals/Mounts/Horse.cs") {
    & python -B "$root/scripts/audit-equines.py"
    if ($LASTEXITCODE) { throw 'Equine native identity audit failed' }
    & python -B "$root/scripts/audit-distinct-mounts.py"
    if ($LASTEXITCODE) { throw 'Distinct mount identity audit failed' }
    & python -B "$root/scripts/audit-equine-completion.py"
    if ($LASTEXITCODE) { throw 'Equine compatibility/native census audit failed' }
  }
  & $godot --headless --path "$root/Viewer" --script res://Presentation/EquineTests.gd
  if ($LASTEXITCODE) { throw 'Equine body, accessory, hue and rider checks failed' }
}
& $godot --headless --path "$root\Viewer" --script res://Presentation/PresentationTests.gd
if ($LASTEXITCODE) { throw 'Presentation tests failed' }
if (Test-Path "$root/Viewer/local-art/creatures/liches/preparation.json") {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/LichActionTests.gd
  if ($LASTEXITCODE) { throw 'Original Lich source, grip, action and static corpse checks failed' }
}
& $godot --headless --path "$root\Viewer" --script res://Presentation/GraphicsTests.gd
if ($LASTEXITCODE) { throw 'Graphics/camera/traversal tests failed' }
& $godot --headless --path "$root\Viewer" --script res://Network/InputMemoryTests.gd
if ($LASTEXITCODE) { throw 'Mouse input/login memory tests failed' }
$streetChecks = & $godot --headless --path "$root\Viewer" --script res://Presentation/StreetTests.gd 2>&1
$streetExit = $LASTEXITCODE
$streetChecks | ForEach-Object { Write-Output $_ }
if ($streetExit -or ($streetChecks | Select-String 'SCRIPT ERROR:|ERROR: Failed to load script')) { throw 'Street reconstruction/retargeted movement tests failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/VisualPassTests.gd
if ($LASTEXITCODE) { throw 'Shared architectural/nature presentation tests failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/SurfacePolishTests.gd
if ($LASTEXITCODE) { throw 'Terrain/shoreline/PBR surface regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/ContactTests.gd
if ($LASTEXITCODE) { throw 'Interior/stair/foot-contact regression checks failed' }
& $godot --headless --path "$root/Viewer" --script res://Presentation/BridgeTests.gd
if ($LASTEXITCODE) { throw 'Footbridge/pier presentation checks failed' }
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
$worldSmoke = & $godot --headless --path "$root\Viewer" --quit-after 3 -- @argsForWorld 2>&1
$worldExit = $LASTEXITCODE
$worldSmoke | ForEach-Object { Write-Output $_ }
# Godot can exit zero after a startup script fails to compile.
if ($worldExit -or ($worldSmoke | Select-String 'SCRIPT ERROR:|ERROR: Failed to load script')) { throw 'World smoke test failed' }
