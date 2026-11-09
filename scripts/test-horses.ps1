param([switch]$Live,[switch]$SkipContact,[switch]$Gpu,[switch]$LiveGpu,[switch]$Equines,[switch]$Ostards,[switch]$EquineCompletion,[switch]$LlamaCompletion,[switch]$Ethics,[switch]$Bovines,[switch]$PreparedBovineActions,[switch]$SeaHorse,[switch]$GiantBeetle,[switch]$FireBeetle,[switch]$Hiryu,[switch]$CuSidhe,[switch]$SourceMounts,[switch]$PreparedSwampDragonActions,[switch]$OrcBomb,[switch]$ActiveCuSidhe,[switch]$ActiveHiryu,[switch]$EtherealBeetle,[switch]$Savages,[switch]$SavageRiders,[string]$CreatureFamily='', [switch]$PreparedQueen, [switch]$ActiveJukaLord, [switch]$DesertOstardActions, [switch]$PreparedDesertOstardActions,[switch]$PreparedGiantBeetleRest,[switch]$PreparedFireBeetleRest)
$ErrorActionPreference='Stop'
if ($PreparedFireBeetleRest -and (!$Live -or !$FireBeetle -or $CreatureFamily -or $PreparedGiantBeetleRest)) {throw '-PreparedFireBeetleRest requires its own -Live -FireBeetle run'}
if ($OrcBomb -and (!$Live -or $CreatureFamily -or $Equines -or $Ostards -or $EquineCompletion -or
 $LlamaCompletion -or $Ethics -or $Bovines -or $SeaHorse -or $GiantBeetle -or $FireBeetle -or
 $Hiryu -or $CuSidhe -or $SourceMounts -or $EtherealBeetle -or $Savages -or $SavageRiders -or
 $DesertOstardActions)) {throw '-OrcBomb requires -Live and its own disposable test run'}
if ($PreparedSwampDragonActions -and (!$Live -or !$SourceMounts)) {throw '-PreparedSwampDragonActions requires -Live -SourceMounts'}
if ($PreparedBovineActions -and !$Bovines) {throw '-PreparedBovineActions requires -Bovines'}
if ($PreparedDesertOstardActions -and !$DesertOstardActions) {throw '-PreparedDesertOstardActions requires -DesertOstardActions'}
if ($PreparedGiantBeetleRest -and (!$Live -or !$GiantBeetle -or $CreatureFamily)) {throw '-PreparedGiantBeetleRest requires its own -Live -GiantBeetle run'}
if ($ActiveCuSidhe -and !$CuSidhe) {throw '-ActiveCuSidhe requires -CuSidhe'}
if ($ActiveHiryu -and !$Hiryu) {throw '-ActiveHiryu requires -Hiryu'}
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
if ($ActiveJukaLord -and $CreatureFamily -ne 'juka_lord') {throw 'ActiveJukaLord requires juka_lord'}
if ($PreparedQueen -and $CreatureFamily -ne 'solen_queens') {throw 'PreparedQueen requires the solen_queens family'}
$preparedCreatureTrial=$PreparedQueen -or $CreatureFamily -in @('mummies','solen_warriors','ice_elementals','candidate_batch','late_source','hydra','energy_vortex','champions','fey_champions','crane','deathwatch','tsuki_wolf','kappa','vampire_bat','yomotsu','occurrence_next','horde_rune','sand_vortex','bake_kitsune','devourer_lion_hiryu','elemental_minotaur','meer_donors','captain_cu','clockwork_tokuno','aos_creatures','aos_aliases','aos_mound','recovered_late','tormented_minotaur','harrower','late_donors','gargoyle_vendor','aos_armed','aos_abysmal','animated_weapon', 'slith', 'raptor', 'fetid_essence', 'corporeal_brume','khaldun_doom','khaldun_actions','restless_soul_actions','restless_soul_mounted','lizard_armed','gargoyle_pillage','classic_gestures','troll_gestures','blistering_pillage','parrot_flight','troglodyte_reach','uop_redirects','ready_stances','giant_serpent_pillage','skeleton_axe','ratman_hunch','spider_mongbat','reaper_harpy','earth_elemental_aos','wraith_sway','gargoyle_classic','scorpion_imp','ophidian_bardiche','dragon_daemon','terathan_classic','ophidian_staff','bone_cyclops','fidget_aliases_toad','skeletal_mage_staff','grizzle_antler','vampire_bat_actions','hopper_horde_actions','late_classic_actions','orc_fidgets','kraken_fidgets','ettin_fidgets','water_fidgets','mongbat_fidgets','sea_serpent_actions','deer_fidgets','rat_fidgets','orc_ettin_reactions','occurrence_deaths','kraken_reactions','water_reactions','field_deaths','lizard_actions','quadruped_actions','hart_deaths','dog_bear_actions','cat_actions','troll_actions','field_fauna','spider_mongbat_actions','grazers_grizzly_actions','pig_reaper_harpy_actions','rabbit_distinct_actions','wisp_distinct_actions','air_distinct_actions','fire_distinct_actions','serpent_ogre_actions','zombie_corpser_gargoyle_actions','earth_gazer_imp_actions','scorpion_headless_actions','alligator_lich_actions','gaman_gestures','chicken_distinct_actions','deathwatch_gestures','daemon_wyvern_polar_actions','wraith_drake_walrus_actions','occurrence_gestures','later_creature_gestures','lowland_creature_gestures','armed_flying_creature_gestures','tokuno_spider_dragon_actions','ophidian_patchwork_actions','copper_kaze_actions','ratman_lava_actions','mage_lord_tentacle_actions','cyclops_titan_ice_actions','ophidian_terathan_actions','hopper_fan_blood_actions','goat_harpy_horde_actions','gargoyle_kitsune_larva_actions','solen_worker_actions','avenger_rotting_actions','efreet_actions','orc_bog_actions','slith_actions','ranked_classic_actions','swamp_widow_juka_actions','bomber_ogre_rune_dopple_actions','golem_raptor_juka_solen_actions','post_solen_actions','frost_through_gargoyle_actions','lattice_through_meer_actions','meer_forward_falls','quagmire_through_exodus_actions','classic_wire_aliases','banshee_through_queens_actions','ridgeback_through_dragons_actions','gargoyle_flight_minotaur_actions','daemon_kin_wings','gargoyle_vendor_wings','related_champion_actions','centaur_through_essence_actions','doom_creature_actions','skeleton_actions','exact_creature_fidgets')
$recordCreatureTrial=$preparedCreatureTrial -or $CreatureFamily -in @('recent_batch','source_coverage_common','source_coverage_uncommon','source_coverage_rare','source_coverage_loose_mounts','lizard_armed_active','shared_body_constructors')
$savageTrial=$Savages -or $SavageRiders
if ($Savages -and $SavageRiders) {throw 'Choose one Savage native suite per fresh server'}
Push-Location $root
try {
 & "$PSScriptRoot/prepare-horses.ps1" -VerifyOnly
 & $godot --headless --path Viewer --editor --import
 if ($LASTEXITCODE) { throw 'Horse import failed' }
 if (!$SkipContact) {
  & $godot --headless --path Viewer --script res://Presentation/HorseTests.gd
  if ($LASTEXITCODE) { throw 'Horse contact/playback checks failed' }
  & $godot --headless --path Viewer --script res://Presentation/RiderHandsTests.gd
  if ($LASTEXITCODE) { throw 'Rider wrist/rein grip checks failed' }
  & $godot --headless --path Viewer --script res://Presentation/HorsePolishTests.gd
  if ($LASTEXITCODE) { throw 'Horse colour/transition/slope checks failed' }
 }
 if ($Gpu) {
  & $godot --path Viewer --script res://Presentation/HorseAppearanceTests.gd
  if ($LASTEXITCODE) { throw 'Horse rendered appearance checks failed' }
  & $godot --path Viewer --script res://Presentation/HorseClothingTests.gd
  if ($LASTEXITCODE) { throw 'Mounted and transition clothing coverage failed' }
 }
 if (!$Live) { return }
 if ($CreatureFamily -or $savageTrial) {
  $checkScript=if ($SavageRiders) {'res://Network/SavageRiderLive.gd'} elseif ($Savages) {'res://Network/SavageLive.gd'} elseif ($CreatureFamily -in @('quadruped_actions','hart_deaths','dog_bear_actions','grazers_grizzly_actions','rabbit_distinct_actions')) {'res://Network/QuadrupedActionsLive.gd'} elseif ($CreatureFamily -eq 'cat_actions') {'res://Network/CatActionsLive.gd'} elseif ($CreatureFamily -eq 'spider_mongbat_actions') {'res://Network/SpiderMongbatActionsLive.gd'} elseif ($CreatureFamily -eq 'pig_reaper_harpy_actions') {'res://Network/PigReaperHarpyActionsLive.gd'} elseif ($CreatureFamily -in @('field_fauna','serpent_ogre_actions','zombie_corpser_gargoyle_actions','earth_gazer_imp_actions','scorpion_headless_actions','alligator_lich_actions','chicken_distinct_actions')) {'res://Network/FieldFaunaLive.gd'} elseif ($CreatureFamily -eq 'troll_actions') {'res://Network/TrollActionsLive.gd'} elseif ($CreatureFamily -eq 'lizard_actions') {'res://Network/LizardActionsLive.gd'} elseif ($CreatureFamily -eq 'field_deaths') {'res://Network/FieldDeathsLive.gd'} elseif ($CreatureFamily -eq 'occurrence_deaths') {'res://Network/OccurrenceDeathsLive.gd'} elseif ($CreatureFamily -eq 'restless_soul_mounted') {'res://Network/RestlessSoulMountedLive.gd'} elseif ($CreatureFamily -eq 'restless_soul_actions') {'res://Network/RestlessSoulActionsLive.gd'} elseif ($CreatureFamily -eq 'khaldun_actions') {'res://Network/KhaldunActionsLive.gd'} elseif ($CreatureFamily -eq 'khaldun_doom') {'res://Network/KhaldunDoomLive.gd'} elseif ($CreatureFamily -eq 'troll_gestures') {'res://Network/TrollGestureLive.gd'} elseif ($CreatureFamily -eq 'exact_creature_fidgets') {'res://Network/ExactCreatureFidgetLive.gd'} elseif ($CreatureFamily -eq 'classic_gestures') {'res://Network/ClassicGestureLive.gd'} elseif ($CreatureFamily -in @('parrot_flight','troglodyte_reach','ready_stances','giant_serpent_pillage','skeleton_axe','ratman_hunch','spider_mongbat','reaper_harpy','earth_elemental_aos','wraith_sway','gargoyle_classic','scorpion_imp','ophidian_bardiche','dragon_daemon','terathan_classic','ophidian_staff','bone_cyclops','fidget_aliases_toad','skeletal_mage_staff','grizzle_antler','vampire_bat_actions','hopper_horde_actions','late_classic_actions','orc_fidgets','kraken_fidgets','ettin_fidgets','water_fidgets','mongbat_fidgets','sea_serpent_actions','rat_fidgets')) {'res://Network/PreparedCreatureActionLive.gd'} elseif ($CreatureFamily -in @('deer_fidgets','orc_ettin_reactions','kraken_reactions','water_reactions','skeleton_actions','wisp_distinct_actions','air_distinct_actions','fire_distinct_actions','gaman_gestures','deathwatch_gestures','lowland_creature_gestures','copper_kaze_actions')) {'res://Network/PreparedClassicActionsLive.gd'} elseif ($CreatureFamily -eq 'shared_body_constructors') {'res://Network/SharedBodyConstructorsLive.gd'} elseif ($CreatureFamily -eq 'daemon_wyvern_polar_actions') {'res://Network/DaemonActionsLive.gd'} elseif ($CreatureFamily -eq 'wraith_drake_walrus_actions') {'res://Network/WraithDrakeWalrusLive.gd'} elseif ($CreatureFamily -eq 'occurrence_gestures') {'res://Network/OccurrenceGesturesLive.gd'} elseif ($CreatureFamily -eq 'later_creature_gestures') {'res://Network/LaterCreatureGesturesLive.gd'} elseif ($CreatureFamily -eq 'armed_flying_creature_gestures') {'res://Network/ArmedFlyingCreatureGesturesLive.gd'} elseif ($CreatureFamily -in @('tokuno_spider_dragon_actions','ophidian_patchwork_actions','ratman_lava_actions','cyclops_titan_ice_actions','ophidian_terathan_actions','hopper_fan_blood_actions')) {'res://Network/TokunoSpiderDragonLive.gd'} elseif ($CreatureFamily -eq 'solen_worker_actions') {'res://Network/SolenWorkerActionsLive.gd'} elseif ($CreatureFamily -eq 'gargoyle_kitsune_larva_actions') {'res://Network/GargoyleKitsuneLarvaLive.gd'} elseif ($CreatureFamily -eq 'orc_bog_actions') {'res://Network/OrcBogActionsLive.gd'} elseif ($CreatureFamily -eq 'slith_actions') {'res://Network/SlithActionsLive.gd'} elseif ($CreatureFamily -eq 'ranked_classic_actions') {'res://Network/RankedClassicActionsLive.gd'} elseif ($CreatureFamily -eq 'swamp_widow_juka_actions') {'res://Network/SwampWidowJukaActionsLive.gd'} elseif ($CreatureFamily -eq 'classic_wire_aliases') {'res://Network/ClassicWireAliasesLive.gd'} elseif ($CreatureFamily -eq 'meer_forward_falls') {'res://Network/MeerForwardFallsLive.gd'} elseif ($CreatureFamily -in @('lattice_through_meer_actions','quagmire_through_exodus_actions','banshee_through_queens_actions','ridgeback_through_dragons_actions','gargoyle_flight_minotaur_actions','daemon_kin_wings','gargoyle_vendor_wings','related_champion_actions','centaur_through_essence_actions','doom_creature_actions')) {'res://Network/SwampWidowJukaActionsLive.gd'} elseif ($CreatureFamily -eq 'frost_through_gargoyle_actions') {'res://Network/FrostThroughGargoyleLive.gd'} elseif ($CreatureFamily -eq 'post_solen_actions') {'res://Network/PostSolenActionsLive.gd'} elseif ($CreatureFamily -eq 'golem_raptor_juka_solen_actions') {'res://Network/GolemRaptorJukaSolenLive.gd'} elseif ($CreatureFamily -eq 'bomber_ogre_rune_dopple_actions') {'res://Network/BomberOgreRuneDoppleLive.gd'} elseif ($CreatureFamily -in @('goat_harpy_horde_actions','avenger_rotting_actions','efreet_actions')) {'res://Network/GoatHarpyHordeLive.gd'} elseif ($CreatureFamily -eq 'mage_lord_tentacle_actions') {'res://Network/MageLordTentacleActionsLive.gd'} elseif ($CreatureFamily -eq 'uop_redirects') {'res://Network/UopRedirectsLive.gd'} elseif ($CreatureFamily -eq 'blistering_pillage') {'res://Network/BlisteringPillageLive.gd'} elseif ($CreatureFamily -eq 'gargoyle_pillage') {'res://Network/GargoylePillageLive.gd'} elseif ($CreatureFamily -eq 'lizard_armed') {'res://Network/SourceArmedLizardmanLive.gd'} elseif ($CreatureFamily -eq 'mages') {'res://Network/SourceMageLive.gd'} elseif ($CreatureFamily -in @('juka','juka_lord')) {'res://Network/SourceJukaLive.gd'} else {'res://Network/CreatureLive.gd'}
  & $godot --headless --path Viewer --script $checkScript --check-only
  if ($LASTEXITCODE) {throw 'Native client script parse failed before server startup'}
 }
 $runtime=Join-Path $root 'work/horse-session/server'
 if ($Ethics) {$runtime=Join-Path $root ('work/ethics-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($CreatureFamily -or $savageTrial) {$runtime=Join-Path $root ('work/creature-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($EtherealBeetle) {$runtime=Join-Path $root ('work/ethereal-beetle-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($CuSidhe) {$runtime=Join-Path $root ('work/cu-sidhe-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($Hiryu) {$runtime=Join-Path $root ('work/hiryu-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($FireBeetle) {$runtime=Join-Path $root ('work/fire-beetle-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($GiantBeetle) {$runtime=Join-Path $root ('work/giant-beetle-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($SeaHorse) {$runtime=Join-Path $root ('work/sea-horse-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($DesertOstardActions) {$runtime=Join-Path $root ('work/desert-ostard-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($OrcBomb) {$runtime=Join-Path $root ('work/creature-session/orc-bomb-'+[Guid]::NewGuid().ToString('N')+'/server')}
 $probe=[Net.Sockets.TcpClient]::new()
 try {
  $connection=$probe.ConnectAsync('127.0.0.1',2594)
  if ($connection.Wait(500) -and $probe.Connected) { throw 'Port 2594 is in use; do not attach to or stop an unknown server.' }
 } catch [AggregateException] { if ($_.Exception.InnerException.SocketErrorCode -eq 'AccessDenied') { throw 'Local network access is required for the isolated horse test.' } }
 finally { $probe.Dispose() }
 New-Item -ItemType Directory -Force $runtime,"$runtime/Assemblies","$runtime/Configuration"|Out-Null
 # Copy binaries/data only. No production saves, accounts, journals or credentials.
 Get-ChildItem "$root/Server/runtime" -File | Where-Object { $_.Extension -in @('.dll','.json','.config') -and $_.Name -notlike '*.local.json' } | Copy-Item -Destination $runtime
 Get-ChildItem "$root/Server/runtime/Assemblies" -File -Filter '*.dll' | Where-Object { $_.Name -ne 'UltimaClone.PreviewTools.dll' } | Copy-Item -Destination "$runtime/Assemblies" -Force
 Copy-Item "$root/Server/runtime/Data" -Destination $runtime -Recurse -Force
 Copy-Item "$root/Server/runtime/Configuration/expansion.json" "$runtime/Configuration/expansion.json" -Force
 if ($Ethics -or $EquineCompletion -or $Bovines -or $CreatureFamily -or $savageTrial) {
  & python -B "$root/scripts/prepare-server-fixes.py" --verify-only
  if ($LASTEXITCODE) {throw 'Server overlay input audit failed'}
  $receipt=Get-Content "$root/work/server-fixes/build-manifest.json" -Raw|ConvertFrom-Json
  $fixedContent=Join-Path $root 'Server/ModernUO/Distribution/Assemblies/UOContent.dll'
  & python -B "$root/scripts/prepare-server-fixes.py" --check-build
  if ($LASTEXITCODE) {throw 'Rebuild the reviewed content after changing any baseline or approved local recipe'}
  Copy-Item -LiteralPath $fixedContent -Destination "$runtime/Assemblies/UOContent.dll" -Force
 }
 if ($CreatureFamily) {
  if ($preparedCreatureTrial -or $CreatureFamily -in @('mages','juka','juka_lord')) {& python -B "$root/scripts/prepare-creature-fixtures.py" $CreatureFamily --prepared --runtime $runtime}
  else {& python -B "$root/scripts/prepare-creature-fixtures.py" $CreatureFamily --runtime $runtime}
  if ($LASTEXITCODE) {throw 'Creature native constructor allow-list preparation failed'}
 }
 $dotnet="$root/.tools/dotnet-server/dotnet.exe"
 $env:DOTNET_CLI_HOME=Join-Path $root '.dotnet-home'
 $savageBuildInputs=@{}
 if ($savageTrial -or $recordCreatureTrial -or $PreparedGiantBeetleRest -or $PreparedFireBeetleRest) {
  Get-ChildItem "$root/Server/HorseIntegrationFixtures" -File | Where-Object {$_.Extension -in @('.cs','.csproj')} | ForEach-Object {
   $savageBuildInputs[('Server/HorseIntegrationFixtures/'+$_.Name)]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
 }
 Push-Location "$root/Server/HorseIntegrationFixtures"
 try { & $dotnet build -c Release --ignore-failed-sources } finally { Pop-Location }
 if ($LASTEXITCODE) { throw 'Isolated fixture extension build failed' }
 Copy-Item "$root/Server/HorseIntegrationFixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll" "$runtime/Assemblies/" -Force
 $savageAssemblies=@{}
 if ($savageTrial -or $recordCreatureTrial -or $PreparedGiantBeetleRest -or $PreparedFireBeetleRest) {
  foreach ($relative in @('ModernUO.dll','Server.dll','Assemblies/UOContent.dll','Assemblies/BritanniaReborn.HorseIntegrationFixtures.dll')) {
   $savageAssemblies[$relative]=(Get-FileHash -LiteralPath (Join-Path $runtime $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
  }
 }
 ConvertTo-Json -InputObject @('UOContent.dll','BritanniaReborn.HorseIntegrationFixtures.dll')|Set-Content "$runtime/Data/assemblies.json"
 $existing=Get-Content "$root/Server/runtime/Configuration/modernuo.json" -Raw|ConvertFrom-Json
 @{assemblyDirectories=@('Assemblies');dataDirectories=@($existing.dataDirectories);listeners=@('127.0.0.1:2594');settings=@{
  'serverListing.serverName'='Britannia Reborn isolated horse tests';'serverListing.address'='127.0.0.1';'serverListing.autoDetect'='False';'network.encryptionMode'='Unencrypted';'accountHandler.enableAutoAccountCreation'='True';'accountHandler.maxAccountsPerIP'='6';'pathfinding.prebakeMaps'='False';'autosave.enabled'='False';'world.savePath'=(Join-Path $runtime 'Saves');'britanniaReborn.isolatedHorseTests'='True';'britanniaReborn.isolatedKhaldunActionTests'=$(if ($CreatureFamily -in @('khaldun_actions','restless_soul_actions','restless_soul_mounted')) {'True'} else {'False'});'britanniaReborn.isolatedRestlessSoulMountTests'=$(if ($CreatureFamily -eq 'restless_soul_mounted') {'True'} else {'False'});'britanniaReborn.isolatedPlagueTests'=$(if ($CreatureFamily -eq 'amorphous') {'True'} else {'False'});'britanniaReborn.isolatedSolenTests'=$(if ($CreatureFamily -eq 'solen_workers') {'True'} else {'False'});'britanniaReborn.isolatedFluidElementalTests'=$(if ($CreatureFamily -eq 'fluid_elementals') {'True'} else {'False'});'britanniaReborn.isolatedJukaTests'=$(if ($CreatureFamily -in @('juka','juka_lord')) {'True'} else {'False'});'britanniaReborn.isolatedDragonBreathTests'=$(if ($CreatureFamily -eq 'dragon_daemon') {'True'} else {'False'});'britanniaReborn.isolatedMageTests'=$(if ($CreatureFamily -eq 'mages') {'True'} else {'False'});'britanniaReborn.isolatedSilverSerpentTests'=$(if ($CreatureFamily -eq 'silver_serpents') {'True'} else {'False'});'ethics.enable'=$(if ($Ethics -or $EquineCompletion) {'True'} else {'False'});'factions.enabled'=$(if ($Ethics -or $EquineCompletion) {'True'} else {'False'});'pingServer.enabled'='False'
  'britanniaReborn.isolatedClassicWireTests'=$(if ($CreatureFamily -eq 'classic_wire_aliases') {'True'} else {'False'})
  'britanniaReborn.isolatedFireBeetleRestTests'=$(if ($PreparedFireBeetleRest) {'True'} else {'False'})
  'britanniaReborn.isolatedGiantBeetleRestTests'=$(if ($PreparedGiantBeetleRest) {'True'} else {'False'})
  'britanniaReborn.isolatedFireGargoyleStanceTests'=$(if ($CreatureFamily -eq 'frost_through_gargoyle_actions') {'True'} else {'False'})
  'britanniaReborn.isolatedCreatureCombatFlagTests'=$(if ($CreatureFamily -eq 'golem_raptor_juka_solen_actions') {'True'} else {'False'})
  'britanniaReborn.isolatedOrcBombTests'=$(if ($OrcBomb) {'True'} else {'False'})
  'britanniaReborn.isolatedSavageTests'=$(if ($savageTrial) {'True'} else {'False'})
  'britanniaReborn.isolatedDesertOstardActions'=$(if ($DesertOstardActions) {'True'} else {'False'})
 }}|ConvertTo-Json -Depth 8|Set-Content "$runtime/Configuration/modernuo.json"
 $accounts=@(@{username='brhorse-test-m';password=[Guid]::NewGuid().ToString('N').Substring(0,24)},@{username='brhorse-test-f';password=[Guid]::NewGuid().ToString('N').Substring(0,24)})
 $credentials=Join-Path $root 'work/horse-session/accounts.local.json'
 if (!(Test-Path $credentials)) { ConvertTo-Json -InputObject $accounts|Set-Content $credentials }
 # The guarded fixture creates an inaccessible ordinary bootstrap account
 # after world load, avoiding the upstream interactive owner-creation prompt.
 # Keep stdin closed to interactive input; never create a privileged owner.
 Set-Content "$root/work/horse-session/decline-owner-prompt.txt" 'n'
 $server=Start-Process $dotnet -ArgumentList 'ModernUO.dll' -WorkingDirectory $runtime -WindowStyle Hidden -PassThru -RedirectStandardInput "$root/work/horse-session/decline-owner-prompt.txt" -RedirectStandardOutput "$root/work/horse-session/server.log" -RedirectStandardError "$root/work/horse-session/server-errors.log"
 try {
  $deadline=[DateTime]::UtcNow.AddSeconds(90)
  do {
   if ($server.HasExited) { throw 'Isolated horse server exited; inspect work/horse-session/server.log' }
   if (Test-Path "$root/work/horse-session/server.log") {
    if (Select-String -Path "$root/work/horse-session/server.log" -SimpleMatch 'This exception is fatal') { throw 'Isolated server startup failed; inspect its local log.' }
   }
   $ready=$false;$listener=[Net.Sockets.TcpClient]::new()
   try { $attempt=$listener.ConnectAsync('127.0.0.1',2594);$ready=$attempt.Wait(100) -and $listener.Connected } catch {} finally {$listener.Dispose()}
   if (!$ready) { Start-Sleep -Milliseconds 200 }
  } while (!$ready -and [DateTime]::UtcNow -lt $deadline)
  if (!$ready) { throw 'Isolated server readiness timeout' }
  $liveArgs=@()
  if ($EquineCompletion) {$liveArgs+='--equine-completion'}
  if ($LlamaCompletion) {$liveArgs+='--llama-completion'}
  if ($Ethics) {$liveArgs+='--ethics-only'}
  if ($Bovines) {$liveArgs+='--bovines'}
  if ($PreparedBovineActions) {$liveArgs+='--bovine-actions'}
  if ($EtherealBeetle) {$liveArgs+='--ethereal-beetle'}
  if ($SourceMounts) {$liveArgs+='--source-mounts'}
  if ($CuSidhe) {$liveArgs+='--cu-sidhe'; if ($ActiveCuSidhe) {$liveArgs+='--cu-sidhe-active'}}
  if ($Hiryu) {$liveArgs+='--hiryu'; if ($ActiveHiryu) {$liveArgs+='--hiryu-active'}}
  if ($FireBeetle) {$liveArgs+='--fire-beetle'}
  if ($GiantBeetle) {$liveArgs+='--giant-beetle'}
  if ($SeaHorse) {$liveArgs+='--sea-horse'}
  if ($CreatureFamily) {$liveArgs+="--family=$CreatureFamily"}
  if ($preparedCreatureTrial) {$liveArgs+='--prepared'}
  if ($PreparedDesertOstardActions) {$liveArgs+='--candidate'}
  if ($ActiveJukaLord) {$liveArgs+='--active-route'}
  $started=[DateTime]::UtcNow
  [string[]]$liveDisplayArgs = if ($LiveGpu) {@('--position','30000,30000','--rendering-method','forward_plus')} else {'--headless'}
  $clientScriptError=$false
  if (!$CreatureFamily -and !$savageTrial) {
   $checkScript=if ($OrcBomb) {'res://Network/OrcBombLive.gd'} elseif ($DesertOstardActions) {'res://Network/DesertOstardLive.gd'} elseif ($PreparedSwampDragonActions) {'res://Network/SwampDragonActionsMountedLive.gd'} elseif ($PreparedFireBeetleRest) {'res://Network/FireBeetleRestLive.gd'} elseif ($PreparedGiantBeetleRest) {'res://Network/GiantBeetleRestLive.gd'} elseif ($Ostards -or $EquineCompletion -or $LlamaCompletion -or $Ethics -or $Bovines -or $SeaHorse -or $GiantBeetle -or $FireBeetle -or $Hiryu -or $CuSidhe -or $SourceMounts -or $EtherealBeetle) {'res://Network/OstardLive.gd'} elseif ($Equines) {'res://Network/EquineLive.gd'} else {'res://Network/HorseLive.gd'}
  }
  & $godot @liveDisplayArgs --path Viewer --script $checkScript -- @liveArgs 2>&1 | ForEach-Object {
   if ($_ -match 'SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script') {$clientScriptError=$true}
   Write-Output $_
  }
  if ($LASTEXITCODE -or $clientScriptError) { throw 'Native isolated integration test failed' }
  if ($OrcBomb) {
   $bombFolder=Join-Path $root 'outputs/creatures/bomber_ogre_rune_dopple_actions'
   $bombReport=Get-Item -LiteralPath "$bombFolder/bomb.json"
   if ($bombReport.LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Native bomb trial did not write fresh evidence'}
   @{
    report_sha256=(Get-FileHash -LiteralPath $bombReport.FullName).Hash.ToLowerInvariant()
    fixture_sha256=(Get-FileHash -LiteralPath "$root/Server/HorseIntegrationFixtures/OrcBombFixtures.cs").Hash.ToLowerInvariant()
    fixture_assembly_sha256=(Get-FileHash -LiteralPath "$runtime/Assemblies/BritanniaReborn.HorseIntegrationFixtures.dll").Hash.ToLowerInvariant()
    server_content_sha256=(Get-FileHash -LiteralPath "$runtime/Assemblies/UOContent.dll").Hash.ToLowerInvariant()
    scope='Actual two-client native OrcBomber.ThrowBomb from the disposable server. No production accounts or saves.'
   }|ConvertTo-Json|Set-Content -LiteralPath "$bombFolder/bomb-runtime.json"
  }
  if ($DesertOstardActions) {
   $reportName=if ($PreparedDesertOstardActions) {'candidate-live.json'} else {'live.json'}
   $report=Join-Path $root "outputs/creatures/desert_ostard_actions/$reportName"
   if (!(Test-Path $report) -or (Get-Item $report).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Desert Ostard native test did not write fresh evidence'}
   $desertReport=Get-Content $report -Raw|ConvertFrom-Json
   if ($desertReport.failures -ne 0 -or $desertReport.candidate -ne [bool]$PreparedDesertOstardActions) {throw 'Desert Ostard native evidence did not pass in the requested mode'}
  }
  if ($SavageRiders) {
   $riderFolder=Join-Path $root 'work/creatures/savage-riders'
   $riderReport=Get-Item "$riderFolder/native-tests.json"
   if ($riderReport.LastWriteTimeUtc -lt $started.AddSeconds(-1) -or (Get-Content $riderReport.FullName -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Savage Rider native evidence is not fresh and successful'}
   foreach ($relative in $savageBuildInputs.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $root $relative)).Hash.ToLowerInvariant() -ne $savageBuildInputs[$relative]) {throw 'Rider fixture source changed during build/run'}
   }
   foreach ($relative in $savageAssemblies.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $runtime $relative)).Hash.ToLowerInvariant() -ne $savageAssemblies[$relative]) {throw 'Rider runtime changed during run'}
   }
   @{runtime=$runtime;started_utc=$started.ToString('o');report_sha256=(Get-FileHash -LiteralPath $riderReport.FullName).Hash.ToLowerInvariant();build_inputs_sha256=$savageBuildInputs;assemblies_sha256=$savageAssemblies;reviewed_content_sha256=$receipt.assembly_sha256;scope='Fresh isolated loopback2594 native Rider constructors, mounted packets, dismount/remount and actual mount-deleting death. Production untouched.'}|ConvertTo-Json -Depth 5|Set-Content "$riderFolder/native-runtime.json"
   & python -B "$root/scripts/check-savage-riders.py"
   if ($LASTEXITCODE) {throw 'Exact native Savage Rider receipt failed'}
   $riderOutput=Join-Path $root 'outputs/creatures/savage_riders'
   New-Item -ItemType Directory -Force $riderOutput|Out-Null
   Copy-Item -LiteralPath $riderReport.FullName -Destination "$riderOutput/live.json" -Force
  }
  if ($Savages) {
   $report=Get-Item "$root/work/creatures/savages/native-tests.json"
   if ($report.LastWriteTimeUtc -lt $started.AddSeconds(-1) -or (Get-Content $report.FullName -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Savage native tests failed or did not write fresh evidence'}
   foreach ($relative in $savageBuildInputs.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $savageBuildInputs[$relative]) {throw 'Savage fixture source changed during build/run'}
   }
   foreach ($relative in $savageAssemblies.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $runtime $relative) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $savageAssemblies[$relative]) {throw 'Savage runtime assembly changed during run'}
   }
   @{runtime=$runtime;started_utc=$started.ToString('o');report_sha256=(Get-FileHash -LiteralPath $report.FullName -Algorithm SHA256).Hash.ToLowerInvariant();build_inputs_sha256=$savageBuildInputs;assemblies_sha256=$savageAssemblies;reviewed_content_sha256=$receipt.assembly_sha256;scope='Fresh isolated loopback2594 two-client world, built fixture sources and copied native assemblies unchanged through run; no production saves/accounts'}|ConvertTo-Json -Depth 5|Set-Content "$root/work/creatures/savages/native-runtime.json"
   & python -B "$root/scripts/check-savage-native.py"
   if ($LASTEXITCODE) {throw 'Savage exact native receipt or behaviour evidence failed'}
   $nativeSavage=Get-Content -LiteralPath $report.FullName -Raw|ConvertFrom-Json
   $savageOutput=Join-Path $root 'outputs/creatures/human_npcs'
   New-Item -ItemType Directory -Force $savageOutput|Out-Null
   @{checks=$nativeSavage.checks;failures=0;records=@($nativeSavage.records|Where-Object {$null -ne $_.native_class});source_report_sha256=(Get-FileHash -LiteralPath $report.FullName).Hash.ToLowerInvariant();source_report='work/creatures/savages/native-tests.json';scope='Positive human-NPC body/class witnesses from the fresh checked native Savage/Shaman two-client run. Controlled fixture, not autonomous AI or full-family certification.'}|ConvertTo-Json -Depth 18|Set-Content -LiteralPath "$savageOutput/live.json"
  }
  if ($LASTEXITCODE) { throw 'Native isolated horse integration test failed' }
  if ($CreatureFamily -eq 'dragon_daemon') {
   $breathStarted=[DateTime]::UtcNow
   & $godot --headless --path Viewer --script res://Network/DragonBreathLive.gd
   if ($LASTEXITCODE) {throw 'Native Dragon and Drake breath failed'}
   $breath=Get-Item "$root/outputs/creatures/dragon_daemon/breath.json"
   if ($breath.LastWriteTimeUtc -lt $breathStarted.AddSeconds(-1)) {throw 'Native breath evidence is stale'}
  }
  if ($CreatureFamily -eq 'mages') {
   & $godot --headless --path Viewer --script res://Network/MageBehaviourLive.gd
   if ($LASTEXITCODE) {throw 'Native mage spell/rummage behaviour failed'}
   & python -B "$root/scripts/check-source-mages.py" --native
   if ($LASTEXITCODE) {throw 'Exact native mage source/appearance/behaviour gate failed'}
  }
  if ($CreatureFamily -eq 'juka') {
   & $godot --headless --path Viewer --script res://Network/JukaBehaviourLive.gd
   if ($LASTEXITCODE) {throw 'Native Juka behaviour failed'}
   & python -B "$root/scripts/check-prepared-juka.py" --native
   if ($LASTEXITCODE) {throw 'Exact native Juka graphics/behaviour evidence failed'}
  }
  if ($CreatureFamily) {
   $reportFamily=if ($ActiveJukaLord) {'juka_lord_active'} else {$CreatureFamily}
   $report=Join-Path $root "outputs/creatures/$reportFamily/live.json"
   if (!(Test-Path $report) -or (Get-Item $report).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Creature native test did not write fresh evidence'}
   if ((Get-Content $report -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Creature native integration reported failures'}
   if ($recordCreatureTrial) {
    $native=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
    $candidates=Get-Content "$root/work/creatures/live-candidates.json" -Raw|ConvertFrom-Json
    if ([bool]$native.prepared_trial -ne [bool]$preparedCreatureTrial -or $native.records.Count -ne 2*$candidates.Count) {throw 'Native batch did not exercise every class and intended registry mode for both clients'}
    if ($native.candidate_sha256 -ne (Get-FileHash "$root/work/creatures/live-candidates.json").Hash.ToLowerInvariant()) {throw 'Prepared native input list changed'}
    foreach ($relative in $savageBuildInputs.Keys) {
     if ((Get-FileHash -LiteralPath (Join-Path $root $relative)).Hash.ToLowerInvariant() -ne $savageBuildInputs[$relative]) {throw 'Prepared native fixture source changed during build/run'}
    }
    foreach ($relative in $savageAssemblies.Keys) {
     if ((Get-FileHash -LiteralPath (Join-Path $runtime $relative)).Hash.ToLowerInvariant() -ne $savageAssemblies[$relative]) {throw 'Prepared native assembly changed during run'}
    }
    $stanceHash=$null
    if ($CreatureFamily -eq 'golem_raptor_juka_solen_actions') {
     $stanceStarted=[DateTime]::UtcNow
     $stanceScriptError=$false
     & $godot @liveDisplayArgs --path Viewer --script res://Network/CreatureCombatFlagsLive.gd 2>&1 | ForEach-Object {
      if ($_ -match 'SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script') {$stanceScriptError=$true}
      Write-Output $_
     }
     if ($LASTEXITCODE -or $stanceScriptError) {throw 'Native combat gait trial failed'}
     $stance=Get-Item -LiteralPath "$root/outputs/creatures/golem_raptor_juka_solen_actions/stance.json"
     if ($stance.LastWriteTimeUtc -lt $stanceStarted.AddSeconds(-1)) {throw 'Native combat gait evidence is stale'}
     $stanceHash=(Get-FileHash -LiteralPath $stance.FullName).Hash.ToLowerInvariant()
    }
    $nativeFolder=Join-Path $root "work/creatures/$CreatureFamily"
    New-Item -ItemType Directory -Force $nativeFolder|Out-Null
    Copy-Item -LiteralPath "$root/work/creatures/live-candidates.json" -Destination "$nativeFolder/candidates.json" -Force
    @{runtime=$runtime;started_utc=$started.ToString('o');report_sha256=(Get-FileHash -LiteralPath $report).Hash.ToLowerInvariant();candidate_sha256=$native.candidate_sha256;build_inputs_sha256=$savageBuildInputs;assemblies_sha256=$savageAssemblies;reviewed_content_sha256=$receipt.assembly_sha256;stance_sha256=$stanceHash;selector_sha256=(Get-FileHash "$root/scripts/prepare-creature-fixtures.py").Hash.ToLowerInvariant();runner_sha256=(Get-FileHash "$root/scripts/test-horses.ps1").Hash.ToLowerInvariant();scope='Fresh disposable loopback2594 native constructors, movement, actions and corpse packets observed by two real clients; prepared mode is recorded in the actual report; no production saves/accounts'}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "$nativeFolder/native-runtime.json"
   }
   if ($CreatureFamily -eq 'silver_serpents') {
    $behaviourStarted=[DateTime]::UtcNow
    & $godot --headless --path Viewer --script res://Network/SilverSerpentBehaviourLive.gd
    if ($LASTEXITCODE) {throw 'Native Silver charm, poison or immunity failed'}
    $behaviourReport=Join-Path $root 'outputs/creatures/silver_serpents/behaviour.json'
    if (!(Test-Path $behaviourReport) -or (Get-Item $behaviourReport).LastWriteTimeUtc -lt $behaviourStarted.AddSeconds(-1)) {throw 'Native Silver behaviour did not produce fresh evidence'}
    if ((Get-Content $behaviourReport -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Native Silver behaviour reported failures'}
    & python -B "$root/scripts/check-source-silver-serpent.py" --native
    if ($LASTEXITCODE) {throw 'Native Silver class/charm/poison evidence incomplete or stale'}
   }
   if ($CreatureFamily -eq 'fluid_elementals') {
    $behaviourStarted=[DateTime]::UtcNow
    & $godot --headless --path Viewer --script res://Network/FluidElementalBehaviourLive.gd
    if ($LASTEXITCODE) {throw 'Native fluid elemental spell, lethal poison or immunity failed'}
    $behaviourReport=Join-Path $root 'outputs/creatures/fluid_elementals/behaviour.json'
    if (!(Test-Path $behaviourReport) -or (Get-Item $behaviourReport).LastWriteTimeUtc -lt $behaviourStarted.AddSeconds(-1)) {throw 'Native fluid behaviour did not produce fresh evidence'}
    if ((Get-Content $behaviourReport -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Native fluid behaviour reported failures'}
    & python -B "$root/scripts/check-source-fluid-elementals.py" --native
    if ($LASTEXITCODE) {throw 'Native fluid source/class/behaviour evidence incomplete or stale'}
   }
   if ($CreatureFamily -eq 'solen_workers') {
    $behaviourStarted=[DateTime]::UtcNow
    & $godot --headless --path Viewer --script res://Network/SolenBehaviourLive.gd
    if ($LASTEXITCODE) {throw 'Native Solen friendship or direct/pet damage failed'}
    $behaviourReport=Join-Path $root 'outputs/creatures/solen_workers/friendship.json'
    if (!(Test-Path $behaviourReport) -or (Get-Item $behaviourReport).LastWriteTimeUtc -lt $behaviourStarted.AddSeconds(-1)) {throw 'Native Solen behaviour did not produce fresh evidence'}
    if ((Get-Content $behaviourReport -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Native Solen behaviour reported failures'}
    & python -B "$root/scripts/check-source-solen.py" --native
    if ($LASTEXITCODE) {throw 'Native Solen class/friendship/damage evidence incomplete or stale'}
   }
   if ($CreatureFamily -eq 'amorphous') {
    $lifecycleStarted=[DateTime]::UtcNow
    & $godot --path Viewer --script res://Network/PlagueLifecycleLive.gd
    if ($LASTEXITCODE) {throw 'Owned native PlagueSpawn forms or lifecycle failed'}
    $lifecycleReport=Join-Path $root 'outputs/creatures/plague_spawn/live.json'
    if (!(Test-Path $lifecycleReport) -or (Get-Item $lifecycleReport).LastWriteTimeUtc -lt $lifecycleStarted.AddSeconds(-1)) {throw 'Owned PlagueSpawn test did not produce fresh evidence'}
    if ((Get-Content $lifecycleReport -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Owned PlagueSpawn lifecycle reported failures'}
    & python -B "$root/scripts/check-source-amorphous.py" --native
    if ($LASTEXITCODE) {throw 'Owned PlagueSpawn/native class evidence is incomplete or stale'}
   }
  }
  if ($EquineCompletion -or $LlamaCompletion -or $Ostards -or $Ethics -or $Bovines -or $SeaHorse -or $GiantBeetle -or $FireBeetle -or $Hiryu -or $CuSidhe -or $SourceMounts -or $EtherealBeetle) {
   $reportName=if ($SourceMounts) {'source-mounts-live.json'} elseif ($ActiveCuSidhe) {'cu-sidhe-active-live.json'} elseif ($CuSidhe) {'cu-sidhe-live.json'} elseif ($ActiveHiryu) {'hiryu-active-live.json'} elseif ($Hiryu) {'hiryu-live.json'} elseif ($EtherealBeetle) {'ethereal-beetle-live.json'} elseif ($FireBeetle) {'fire-beetle-live.json'} elseif ($GiantBeetle) {'giant-beetle-live.json'} elseif ($SeaHorse) {'sea-horse-live.json'} elseif ($Bovines) {'bovine-live.json'} elseif ($Ethics) {'ethics-live.json'} elseif ($EquineCompletion) {'equine-completion-live.json'} elseif ($LlamaCompletion) {'llama-completion-live.json'} else {'live-validation.json'}
   $report=Join-Path $root "outputs/ostard-riding/$reportName"
   if (!(Test-Path $report) -or (Get-Item $report).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Live test did not write fresh evidence; inspect the Godot log.'}
   if ((Get-Content $report -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Live integration reported failures'}
  }
  if ($PreparedFireBeetleRest) {
   $beetleWork="$root/work/creatures/fire_beetle_rest"
   $beetleReport=Get-Item -LiteralPath "$root/outputs/ostard-riding/fire-beetle-rest-live.json"
   $beetleEvidence=Get-Content -LiteralPath $beetleReport.FullName -Raw | ConvertFrom-Json
   if ($beetleReport.LastWriteTimeUtc -lt $started.AddSeconds(-1) -or $beetleEvidence.failures -or
       $beetleEvidence.rest_records.Count -ne 6 -or ($beetleEvidence.rest_records.female | Sort-Object -Unique).Count -ne 2) {
    throw 'Fire Beetle rest did not write fresh evidence for both owners'
   }
   foreach ($relative in $savageBuildInputs.Keys) {
    if ((Get-FileHash -LiteralPath "$root/$relative").Hash.ToLowerInvariant() -ne $savageBuildInputs[$relative]) {throw "Fire Beetle fixture source changed: $relative"}
   }
   foreach ($relative in $savageAssemblies.Keys) {
    if ((Get-FileHash -LiteralPath "$runtime/$relative").Hash.ToLowerInvariant() -ne $savageAssemblies[$relative]) {throw "Fire Beetle fixture assembly changed: $relative"}
   }
   $previewSha=(Get-FileHash -LiteralPath "$beetleWork/preview.json").Hash.ToLowerInvariant()
   $wrapperSha=(Get-FileHash -LiteralPath "$root/Viewer/Network/FireBeetleRestLive.gd").Hash.ToLowerInvariant()
   if ($previewSha -ne $beetleEvidence.preview_sha256 -or $wrapperSha -ne $beetleEvidence.wrapper_sha256) {
    throw 'Fire Beetle preview or wrapper changed during the native trial'
   }
   @{report_sha256=(Get-FileHash -LiteralPath $beetleReport.FullName).Hash.ToLowerInvariant();preview_sha256=$previewSha;wrapper_sha256=$wrapperSha;build_inputs_sha256=$savageBuildInputs;assemblies_sha256=$savageAssemblies}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath "$beetleWork/native-runtime.json"
  }
  if ($PreparedGiantBeetleRest) {
   $beetleWork="$root/work/creatures/giant_beetle_rest"
   $beetleReport=Get-Item -LiteralPath "$root/outputs/ostard-riding/giant-beetle-rest-live.json"
   $beetleEvidence=Get-Content -LiteralPath $beetleReport.FullName -Raw | ConvertFrom-Json
   if ($beetleReport.LastWriteTimeUtc -lt $started.AddSeconds(-1) -or $beetleEvidence.failures -or $beetleEvidence.rest_records.Count -ne 2) {throw 'Giant Beetle rest did not write fresh evidence for both clients'}
   foreach ($relative in $savageBuildInputs.Keys) {
    if ((Get-FileHash -LiteralPath "$root/$relative").Hash.ToLowerInvariant() -ne $savageBuildInputs[$relative]) {throw "Beetle fixture source changed: $relative"}
   }
   foreach ($relative in $savageAssemblies.Keys) {
    if ((Get-FileHash -LiteralPath "$runtime/$relative").Hash.ToLowerInvariant() -ne $savageAssemblies[$relative]) {throw "Beetle fixture assembly changed: $relative"}
   }
   $previewSha=(Get-FileHash -LiteralPath "$beetleWork/preview.json").Hash.ToLowerInvariant()
   if ($previewSha -ne $beetleEvidence.prepared_package_sha256) {throw 'Beetle preview changed during the native trial'}
   @{report_sha256=(Get-FileHash -LiteralPath $beetleReport.FullName).Hash.ToLowerInvariant();preview_sha256=$previewSha;build_inputs_sha256=$savageBuildInputs;assemblies_sha256=$savageAssemblies}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath "$beetleWork/native-runtime.json"
  }
  if ($Ethics) {
   Stop-Process -Id $server.Id
   $server.WaitForExit()
   $server=Start-Process $dotnet -ArgumentList 'ModernUO.dll' -WorkingDirectory $runtime -WindowStyle Hidden -PassThru -RedirectStandardInput "$root/work/horse-session/decline-owner-prompt.txt" -RedirectStandardOutput "$root/work/horse-session/ethics-restart-server.log" -RedirectStandardError "$root/work/horse-session/ethics-restart-server-errors.log"
   $deadline=[DateTime]::UtcNow.AddSeconds(90)
   do {
    if ($server.HasExited) {throw 'Saved isolated ethics server exited on restart'}
    $ready=$false;$listener=[Net.Sockets.TcpClient]::new()
    try {$attempt=$listener.ConnectAsync('127.0.0.1',2594);$ready=$attempt.Wait(100) -and $listener.Connected} catch {} finally {$listener.Dispose()}
    if (!$ready) {Start-Sleep -Milliseconds 200}
   } while (!$ready -and [DateTime]::UtcNow -lt $deadline)
   if (!$ready) {throw 'Saved isolated ethics server readiness timeout'}
   $started=[DateTime]::UtcNow
   & $godot --headless --path Viewer --script res://Network/OstardLive.gd -- --ethics-resume
   if ($LASTEXITCODE) {throw 'Native ethics save/restart validation failed'}
   $report=Join-Path $root 'outputs/ostard-riding/ethics-restart.json'
   if (!(Test-Path $report) -or (Get-Item $report).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Restart validation did not write fresh evidence'}
   if ((Get-Content $report -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Restart validation reported failures'}
   @{runtime=$runtime;content_sha256=$receipt.assembly_sha256;scope='Disposable native world save/restart; production untouched'}|ConvertTo-Json|Set-Content "$root/outputs/ostard-riding/ethics-runtime.json"
  }
 } finally {
  # This exact process was created above for the disposable runtime. The
  # existing port-2593 world and its saves are never stopped or modified.
  if (!$server.HasExited) { Stop-Process -Id $server.Id }
 }
} finally { Pop-Location }
