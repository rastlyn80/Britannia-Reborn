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
if (Test-Path "$root/Viewer/local-art/human-npcs/savages/local-presentation.json") {
 & python -B "$root/scripts/accept-savage-profiles.py" --check-active
 if ($LASTEXITCODE) {throw 'Active Savage human profile evidence failed'}
 $savageNormal = & $godot --headless --path "$root/Viewer" --script res://Presentation/SavageNormalRouteTests.gd 2>&1
 $savageNormalExit = $LASTEXITCODE
 $savageNormal | ForEach-Object {Write-Output $_}
 if ($savageNormalExit -or ($savageNormal | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Normal Savage profile/dance/mount/corpse routes failed'}
 $corpseTransfer = & $godot --headless --path "$root/Viewer" --script res://Presentation/HumanCorpseTransferTests.gd 2>&1
 $corpseTransferExit = $LASTEXITCODE
 $corpseTransfer | ForEach-Object {Write-Output $_}
 if ($corpseTransferExit -or ($corpseTransfer | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Native-order human corpse equipment recovery failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/reviewed_presentations/local-presentation.json") {
 & python -B "$root/scripts/accept-reviewed-creatures.py" --check-active
 if ($LASTEXITCODE) {throw 'Activated reviewed creature evidence failed'}
 $reviewedRoutes = & $godot --headless --path "$root/Viewer" --script res://Presentation/ReviewedCreatureRouteTests.gd 2>&1
 $reviewedRouteExit = $LASTEXITCODE
 $reviewedRoutes | ForEach-Object {Write-Output $_}
 if ($reviewedRouteExit -or ($reviewedRoutes | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Default reviewed creature avatar/corpse routes failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/source_family_batch/local-presentation.json") {
 & python -B "$root/scripts/prepare-source-family-batch.py" --check-skins
 if ($LASTEXITCODE) {throw 'Source family complete skins and static corpses failed'}
 & python -B "$root/scripts/prepare-source-family-batch.py" --check-actions
 if ($LASTEXITCODE) {throw 'Source family native action timing and hue contracts failed'}
 & python -B "$root/scripts/accept-source-family-batch.py" --check-active
 if ($LASTEXITCODE) {throw 'Source family active evidence or asset proportions changed'}
 $familyRoutes = & $godot --headless --path "$root/Viewer" --script res://Presentation/CreatureBatchRouteTests.gd 2>&1
 $familyRouteExit = $LASTEXITCODE
 $familyRoutes | ForEach-Object {Write-Output $_}
 if ($familyRouteExit -or ($familyRoutes | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Normal source family avatar/static-corpse routes failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/ant_lion_chain/local-presentation.json") {
 & python -B "$root/scripts/prepare-ant-lion.py" --check-skins
 if ($LASTEXITCODE) {throw 'Ant Lion complete skin and static corpse checks failed'}
 & python -B "$root/scripts/prepare-ant-lion.py" --check-actions
 if ($LASTEXITCODE) {throw 'Normal Ant Lion registry, rig and hue checks failed'}
 & python -B "$root/scripts/accept-ant-lion.py" --check-active
 if ($LASTEXITCODE) {throw 'Active Ant Lion source/presentation receipt failed'}
}
if (Test-Path "$root/Viewer/local-art/creatures/crystal_lattice/local-presentation.json") {
 & python -B "$root/scripts/prepare-crystal-lattice.py" --check-skins
 if ($LASTEXITCODE) {throw 'Crystal Lattice Seeker complete skin and static corpse checks failed'}
 & python -B "$root/scripts/prepare-crystal-lattice.py" --check-actions
 if ($LASTEXITCODE) {throw 'Normal Crystal Lattice Seeker registry, rig and hue checks failed'}
 & python -B "$root/scripts/accept-crystal-lattice.py" --check-active
 if ($LASTEXITCODE) {throw 'Active Crystal Lattice Seeker source/presentation receipt failed'}
}
$beetlePublisher = 'accept-giant-beetle.py'
$fireBeetlePublisher = 'accept-fire-beetle.py'
$creatureIndexPath = "$root/Viewer/local-art/creatures/accepted-index.json"
if ((Test-Path $creatureIndexPath) -and (Select-String -Path $creatureIndexPath -SimpleMatch '"beetle_rest_native_sha256"' -Quiet)) {
 $beetlePublisher = 'accept-giant-beetle-rest.py'
}
if ((Test-Path $creatureIndexPath) -and (Select-String -Path $creatureIndexPath -SimpleMatch '"fire_beetle_rest_native_sha256"' -Quiet)) {
 $fireBeetlePublisher = 'accept-fire-beetle-rest.py'
}
foreach ($route in @(
 @{Folder='giant_beetle'; Publisher=$beetlePublisher},
 @{Folder='giant_beetle_fire'; Publisher=$fireBeetlePublisher},
 @{Folder='giant_beetle_ethereal'; Publisher='accept-ethereal-beetle.py'},
 @{Folder='solen_queens'; Publisher='accept-solen-queens.py'},
 @{Folder='gazer_larva'; Publisher='accept-gazer-larva.py'},
 @{Folder='bog_thing'; Publisher='prepare-bog-thing.py'}
)) {
 if (!(Test-Path "$root/Viewer/local-art/creatures/$($route.Folder)/local-presentation.json")) {continue}
 & python -B "$root/scripts/$($route.Publisher)" --check-active
 if ($LASTEXITCODE) {throw "Active creature presentation evidence failed: $($route.Folder)"}
}
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
 $preservingActions = & $godot --headless --path "$root/Viewer" --script res://Presentation/SourcePreservingBaseActionTests.gd 2>&1
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
& python -B "$root/scripts/check-creature-wire-routes.py"
if ($LASTEXITCODE) {throw 'Classic wire source evidence failed'}
& python -B "$root/scripts/check-classic-gesture-bridge.py"
if ($LASTEXITCODE) {throw 'Classic creature gesture compatibility source evidence failed'}
& $godot --headless --path "$root/Viewer" --script res://../scripts/test-creature-wire-routes.gd
if ($LASTEXITCODE) {throw 'Classic wire playback failed'}
& $godot --headless --path "$root/Viewer" --script res://../scripts/test-creature-wire-routes.gd -- --bridge
if ($LASTEXITCODE) {throw 'Classic gesture compatibility playback failed'}
& $godot --headless --path "$root/Viewer" --script res://Presentation/CorpseAttributeTests.gd
if ($LASTEXITCODE) {throw 'Static corpse custom UV/attribute format preservation failed'}
& $godot --headless --path "$root/Viewer" --script res://Presentation/SavagePaintAttributeTests.gd
if ($LASTEXITCODE) {throw 'Human NPC paint/source attributes, 16/32-bit LOD or static snapshot preservation failed'}
if (Test-Path "$root/Viewer/local-art/creatures/accepted-index.json") {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/CreatureDeathTests.gd
 if ($LASTEXITCODE) {throw 'Existing generic decoded creature-death transitions or lifecycle regressed'}
 $lateIndex = Get-Content "$root/Viewer/local-art/creatures/accepted-index.json" -Raw | ConvertFrom-Json
 if ($lateIndex.entries | Where-Object { $_.uop_redirect_native_sha256 }) {
  & python -B "$root/scripts/prepare-creature-uop-redirects.py" --check-active
  if ($LASTEXITCODE) {throw 'Active UOP creature redirect evidence failed'}
 }
 $classicBatches = @(if ($lateIndex.entries | Where-Object { $_.legacy_slot11_evidence.matched_payload_signature }) {
  'exact_creature_fidgets'
 })
 foreach ($actionBatch in @{4='gargoyle_classic';9='dragon_daemon';14='earth_elemental_aos';17='orc_fidgets';18='ettin_fidgets';21='giant_serpent_pillage';26='wraith_sway';28='spider_mongbat';30='reaper_harpy';42='ratman_hunch';48='scorpion_imp';56='skeleton_axe';57='bone_cyclops';67='fidget_aliases_toad';70='terathan_classic';77='kraken_fidgets';85='ophidian_staff';86='ophidian_bardiche';130='blistering_pillage';148='skeletal_mage_staff';150='sea_serpent_actions';172='late_classic_actions';234='deer_fidgets';248='gaman_gestures';259='grizzle_antler';267='troglodyte_reach';302='hopper_horde_actions';317='vampire_bat_actions';730='ready_stances';734='slith_actions';831='parrot_flight'}.GetEnumerator()) {
  if ($lateIndex.entries | Where-Object { $_.status -eq 'validated' -and $_.classic_gesture_native_sha256 -and $_.bodies.body -contains $actionBatch.Key }) {
   $classicBatches += $actionBatch.Value
  }
 }
 $classicBatches = @($classicBatches + $lateIndex.entries.classic_gesture_batch | Where-Object { $_ } | Sort-Object -Unique)
 $classicCheck = {
  param($root, $batches)
  $ErrorActionPreference = 'Stop'
  foreach ($batch in $batches) {
   & python -B "$root/scripts/accept-classic-gestures.py" --batch $batch --check-active
   if ($LASTEXITCODE) {throw "Active creature action evidence failed: $batch"}
  }
 }
 # These checks only read the accepted registry and their sealed evidence.
 $workerLimit = [Math]::Max(1, [Math]::Min(4, [int][Math]::Floor([Environment]::ProcessorCount / 2)))
 $workers = [Math]::Min($classicBatches.Count, $workerLimit)
 $classicTimer = [Diagnostics.Stopwatch]::StartNew()
 if ($workers -lt 2) {
  & $classicCheck $root $classicBatches
 } else {
  $classicJobs = @()
  try {
   for ($worker = 0; $worker -lt $workers; $worker++) {
    $assigned = @(for ($index = $worker; $index -lt $classicBatches.Count; $index += $workers) { $classicBatches[$index] })
    $classicJobs += Start-Job -Name "ClassicCreatureActions-$worker" -ScriptBlock $classicCheck -ArgumentList $root,$assigned
   }
   foreach ($job in $classicJobs) {
    Receive-Job -Job $job -Wait -ErrorAction Continue
    if ($job.State -ne 'Completed') {throw "Creature action verification failed: $($job.Name)"}
   }
  } finally {
   $classicJobs | Remove-Job -Force
  }
 }
 Write-Output ('{0} Classic action packages verified in {1:N1} seconds.' -f $classicBatches.Count, $classicTimer.Elapsed.TotalSeconds)
 foreach ($family in @('late_source','hydra','energy_vortex','champions','fey_champions','crane','deathwatch','tsuki_wolf','kappa','vampire_bat','yomotsu','occurrence_next','sand_vortex','bake_kitsune','horde_rune','devourer_lion_hiryu','elemental_minotaur','meer_donors','captain_cu','clockwork_tokuno','aos_creatures','aos_aliases','aos_mound','recovered_late','tormented_minotaur','harrower','late_donors','gargoyle_vendor','aos_armed','aos_abysmal','animated_weapon', 'slith', 'raptor', 'fetid_essence', 'corporeal_brume', 'khaldun_doom')) {
  if ($lateIndex.entries | Where-Object { $_.status -eq 'validated' -and $_.assets.modern -like "res://local-art/creatures/$family/*" }) {
   $routeTest = @{energy_vortex='EnergyVortexRouteTests.gd';champions='ChampionCreatureRouteTests.gd';fey_champions='FeyChampionRouteTests.gd';crane='CraneRouteTests.gd';deathwatch='DeathwatchRouteTests.gd';tsuki_wolf='TsukiWolfRouteTests.gd';kappa='KappaRouteTests.gd';vampire_bat='VampireBatRouteTests.gd';yomotsu='YomotsuRouteTests.gd';occurrence_next='OccurrenceCreatureRouteTests.gd';sand_vortex='SandVortexRouteTests.gd';bake_kitsune='BakeKitsuneRouteTests.gd';horde_rune='OccurrenceCreatureRouteTests.gd';devourer_lion_hiryu='DevourerLionHiryuRouteTests.gd';elemental_minotaur='ElementalMinotaurRouteTests.gd';meer_donors='MeerDonorRouteTests.gd';captain_cu='CaptainCuRouteTests.gd';clockwork_tokuno='ClockworkTokunoRouteTests.gd';harrower='HarrowerMorphTests.gd'}[$family]
   if (!$routeTest) {$routeTest = 'LateCreatureRouteTests.gd'}
   $lateRoutes = & $godot --headless --path "$root/Viewer" --script "res://Presentation/$routeTest" -- "--family=$family" 2>&1
   $lateExit = $LASTEXITCODE
   $lateRoutes | ForEach-Object { Write-Output $_ }
   if ($lateExit -or ($lateRoutes | Select-String 'SCRIPT ERROR:|ERROR:')) {throw "Recovered creature route failed: $family"}
  }
 }
 if ($lateIndex.entries | Where-Object { $_.status -eq 'validated' -and $_.khaldun_native_sha256 }) {
  & python -B "$root/scripts/accept-khaldun-actions.py" check-active
  if ($LASTEXITCODE) {throw 'Active Spectral Armour routes failed'}
 }
 if ($lateIndex.entries | Where-Object { $_.status -eq 'validated' -and $_.restless_soul_native_sha256 }) {
  & python -B "$root/scripts/accept-restless-soul-actions.py" check-active
  if ($LASTEXITCODE) {throw 'Active Restless Soul routes failed'}
 }
 if ($lateIndex.entries | Where-Object { $_.status -eq 'validated' -and $_.restless_soul_mount_sha256 }) {
  & python -B "$root/scripts/accept-restless-soul-mounted.py" check-active
  if ($LASTEXITCODE) {throw 'Active Restless Soul mounted routes failed'}
 }
 if ($lateIndex.entries | Where-Object { $_.status -eq 'validated' -and $_.family -eq 'hiryu_mount' }) {
  $hiryuRide = & $godot --headless --path "$root/Viewer" --script res://Presentation/HiryuRidingTests.gd -- --active 2>&1
  $hiryuExit = $LASTEXITCODE
  $hiryuRide | ForEach-Object { Write-Output $_ }
  if ($hiryuExit -or ($hiryuRide | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Active Hiryu riding route failed'}
 }
 if ($lateIndex.entries | Where-Object { $_.status -eq 'validated' -and $_.family -eq 'cu_sidhe_mount' }) {
  $cuScript = if ($lateIndex.entries | Where-Object { $_.family -eq 'cu_sidhe_mount' -and $_.classic_gesture_batch -eq 'lattice_through_meer_actions' }) {
   'res://../scripts/test-cu-sidhe-retained.gd'
  } else { 'res://Presentation/CuSidheRidingTests.gd' }
  $cuRide = & $godot --headless --path "$root/Viewer" --script $cuScript -- --active 2>&1
  $cuExit = $LASTEXITCODE
  $cuRide | ForEach-Object { Write-Output $_ }
  if ($cuExit -or ($cuRide | Select-String 'SCRIPT ERROR:|ERROR:')) {throw 'Active Cu Sidhe riding route failed'}
 }
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
# These families read shared assets and each write their own evidence folder.
$sourceCreatureChecks = [ordered]@{
 Mummy = {
  param($root, $godot)
  $ErrorActionPreference = 'Stop'
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
 }
 SolenWarrior = {
  param($root, $godot)
  $ErrorActionPreference = 'Stop'
  if (Test-Path "$root/Viewer/local-art/creatures/black_ant_warrior-ground.json") {
   foreach ($trial in @('SolenWarriorSourceTests','SolenWarriorRuntimeTests','SolenWarriorTerrainTests','SolenWarriorDeathTests')) {
    & $godot --headless --path "$root/Viewer" --script "res://Presentation/$trial.gd"
    if ($LASTEXITCODE) {throw "Prepared eight-slot Solen warrior test failed: $trial"}
   }
   & python -B "$root/scripts/check-solen-warrior-sources.py" --fidelity
   if ($LASTEXITCODE) {throw 'Exact original Solen warrior source/import/action/corpse proof failed'}
  }
 }
 IceElemental = {
  param($root, $godot)
  $ErrorActionPreference = 'Stop'
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
 }
}
$sourceCreatureJobs = @()
$sourceCreatureTimer = [Diagnostics.Stopwatch]::StartNew()
try {
 foreach ($check in $sourceCreatureChecks.GetEnumerator()) {
  if ([Environment]::ProcessorCount -lt 4) {
   & $check.Value $root $godot
  } else {
   $sourceCreatureJobs += Start-Job -Name $check.Key -ScriptBlock $check.Value -ArgumentList $root,$godot
  }
 }
 foreach ($job in $sourceCreatureJobs) {
  Receive-Job -Job $job -Wait -ErrorAction Continue
  if ($job.State -ne 'Completed') {throw "Original creature verification failed: $($job.Name)"}
 }
} finally {
 if ($sourceCreatureJobs.Count) { $sourceCreatureJobs | Remove-Job -Force }
}
Write-Output ('Original creature runtime checks completed in {0:N1} seconds.' -f $sourceCreatureTimer.Elapsed.TotalSeconds)
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
 if (Test-Path "$root/Viewer/Art/Creatures/Rabbit/distinct-actions.res") {
  & python -B "$root/scripts/prepare-rabbit-distinct-actions.py" --check-public
  if ($LASTEXITCODE) {throw 'Public rabbit distinct action and corpse evidence failed'}
 }
}
if (Test-Path "$root/Viewer/Art/Creatures/Wisp/wisp.scn") {
  if (Test-Path "$root/Viewer/Art/Creatures/Wisp/distinct-actions.res") {
    & python -B "$root/scripts/prepare-wisp-distinct-actions.py" --check-public
    if ($LASTEXITCODE) {throw 'Public Wisp distinct action provenance failed'}
  }
  & python -B "$root/scripts/test-wisp-distribution.py"
  if ($LASTEXITCODE) {throw 'Public Wisp rig/actions, deterministic energy phase and static corpse distribution failed'}
}
if ((Get-Content "$root/Viewer/Art/Creatures/index.json" -Raw | ConvertFrom-Json).entries.kind -contains 'shadow_wisp') {
  & python -B "$root/scripts/test-shadow-wisp-distribution.py"
  if ($LASTEXITCODE) {throw 'Public Shadow Wisp shared rig/actions, native hue flags and static corpse distribution failed'}
}
if ((Test-Path "$root/Viewer/Art/Creatures/Air/air-elemental.scn") -and
    (Test-Path "$root/Viewer/Art/Creatures/Fire/fire-elemental.scn")) {
 $elementalGestures = & $godot --headless --path "$root/Viewer" --script res://../scripts/test-elemental-classic-gestures.gd 2>&1
 $elementalGesturesExit = $LASTEXITCODE
 $elementalGestures | ForEach-Object {Write-Output $_}
 if ($elementalGesturesExit -or ($elementalGestures | Select-String 'SCRIPT ERROR:|Parse Error:')) {throw 'Air and Fire Classic gesture checks failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Air/air-elemental.scn") {
  if (Test-Path "$root/Viewer/Art/Creatures/Air/distinct-actions.res") {
    & python -B "$root/scripts/prepare-air-distinct-actions.py" --check-public
    if ($LASTEXITCODE) {throw 'Public Air Elemental distinct action provenance failed'}
  }
  & python -B "$root/scripts/test-air-distribution.py"
  if ($LASTEXITCODE) {throw 'Public AirElemental rig/actions, spectral hue and static dust distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Bogling/bogling.glb") {
  & python -B "$root/scripts/test-bogling-distribution.py"
  if ($LASTEXITCODE) {throw 'Public Bogling rig, normal maps, action skins and static corpse distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Fire/fire-elemental.scn") {
  if (Test-Path "$root/Viewer/Art/Creatures/Fire/distinct-actions.res") {
    & python -B "$root/scripts/prepare-fire-distinct-actions.py" --check-public
    if ($LASTEXITCODE) {throw 'Public Fire Elemental distinct action provenance failed'}
  }
  & python -B "$root/scripts/test-fire-distribution.py"
  if ($LASTEXITCODE) {throw 'Public FireElemental rig/actions, static ash and transient death cleanup distribution failed'}
}
if (Test-Path "$root/Viewer/Art/Creatures/Chicken/chicken.glb") {
  if (Test-Path "$root/Viewer/Art/Creatures/Chicken/distinct-actions.res") {
    & python -B "$root/scripts/prepare-chicken-distinct-actions.py" --check-public
    if ($LASTEXITCODE) {throw 'Public Chicken distinct routes or terrain corpse transitions failed'}
  }
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
if (Test-Path "$root/Viewer/local-art/ostards/desert-actions-active.json") {
 & python -B "$root/scripts/accept-desert-ostard-actions.py" --check-active
 if ($LASTEXITCODE) {throw 'Active Desert Ostard animation and corpse evidence failed'}
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
 if (Test-Path "$root/Viewer/local-art/animals/bovine-actions-active.json") {
  & python -B "$root/scripts/accept-bovine-actions.py" --check-active
  if ($LASTEXITCODE) {throw 'Active bovine animation and corpse evidence failed'}
 }
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
$polishOutput = & $godot --headless --path "$root/Viewer" --script res://Network/PolishTests.gd 2>&1
$polishExit = $LASTEXITCODE
$polishOutput | ForEach-Object { Write-Output $_ }
if ($polishExit -and ($polishOutput | Out-String) -match '(?s)POLISH TESTS: \d+ checks / 0 failures.*CrashHandlerException: Program crashed with signal 11') {
 Write-Output 'Godot crashed during gameplay polish shutdown. Repeating the complete test once.'
 & $godot --headless --path "$root/Viewer" --script res://Network/PolishTests.gd
 $polishExit = $LASTEXITCODE
}
if ($polishExit) { throw 'Gameplay polish (gains, paperdoll, target, cast bar) checks failed' }
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
