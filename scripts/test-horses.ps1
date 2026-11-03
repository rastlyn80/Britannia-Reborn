param([switch]$Live,[switch]$SkipContact,[switch]$Gpu,[switch]$Equines,[switch]$Ostards,[switch]$EquineCompletion,[switch]$LlamaCompletion,[switch]$Ethics,[switch]$Bovines,[switch]$SeaHorse,[switch]$GiantBeetle,[switch]$FireBeetle,[switch]$EtherealBeetle,[switch]$Savages,[switch]$SavageRiders,[string]$CreatureFamily='', [switch]$PreparedQueen)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
if ($PreparedQueen -and $CreatureFamily -ne 'solen_queens') {throw 'PreparedQueen requires the solen_queens family'}
$preparedCreatureTrial=$PreparedQueen -or $CreatureFamily -in @('mummies','solen_warriors','ice_elementals','candidate_batch')
$recordCreatureTrial=$preparedCreatureTrial -or $CreatureFamily -eq 'recent_batch'
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
  $checkScript=if ($SavageRiders) {'res://Network/SavageRiderLive.gd'} elseif ($Savages) {'res://Network/SavageLive.gd'} elseif ($CreatureFamily -eq 'mages') {'res://Network/SourceMageLive.gd'} elseif ($CreatureFamily -eq 'juka') {'res://Network/SourceJukaLive.gd'} else {'res://Network/CreatureLive.gd'}
  & $godot --headless --path Viewer --script $checkScript --check-only
  if ($LASTEXITCODE) {throw 'Native client script parse failed before server startup'}
 }
 $runtime=Join-Path $root 'work/horse-session/server'
 if ($Ethics) {$runtime=Join-Path $root ('work/ethics-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($CreatureFamily -or $savageTrial) {$runtime=Join-Path $root ('work/creature-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($EtherealBeetle) {$runtime=Join-Path $root ('work/ethereal-beetle-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($FireBeetle) {$runtime=Join-Path $root ('work/fire-beetle-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($GiantBeetle) {$runtime=Join-Path $root ('work/giant-beetle-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
 if ($SeaHorse) {$runtime=Join-Path $root ('work/sea-horse-session/'+[Guid]::NewGuid().ToString('N')+'/server')}
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
  if ($preparedCreatureTrial -or $CreatureFamily -in @('mages','juka')) {& python -B "$root/scripts/prepare-creature-fixtures.py" $CreatureFamily --prepared --runtime $runtime}
  else {& python -B "$root/scripts/prepare-creature-fixtures.py" $CreatureFamily --runtime $runtime}
  if ($LASTEXITCODE) {throw 'Creature native constructor allow-list preparation failed'}
 }
 $dotnet="$root/.tools/dotnet-server/dotnet.exe"
 $env:DOTNET_CLI_HOME=Join-Path $root '.dotnet-home'
 $savageBuildInputs=@{}
 if ($savageTrial -or $recordCreatureTrial) {
  Get-ChildItem "$root/Server/HorseIntegrationFixtures" -File | Where-Object {$_.Extension -in @('.cs','.csproj')} | ForEach-Object {
   $savageBuildInputs[('Server/HorseIntegrationFixtures/'+$_.Name)]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
 }
 Push-Location "$root/Server/HorseIntegrationFixtures"
 try { & $dotnet build -c Release --ignore-failed-sources } finally { Pop-Location }
 if ($LASTEXITCODE) { throw 'Isolated fixture extension build failed' }
 Copy-Item "$root/Server/HorseIntegrationFixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll" "$runtime/Assemblies/" -Force
 $savageAssemblies=@{}
 if ($savageTrial -or $recordCreatureTrial) {
  foreach ($relative in @('ModernUO.dll','Server.dll','Assemblies/UOContent.dll','Assemblies/BritanniaReborn.HorseIntegrationFixtures.dll')) {
   $savageAssemblies[$relative]=(Get-FileHash -LiteralPath (Join-Path $runtime $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
  }
 }
 ConvertTo-Json -InputObject @('UOContent.dll','BritanniaReborn.HorseIntegrationFixtures.dll')|Set-Content "$runtime/Data/assemblies.json"
 $existing=Get-Content "$root/Server/runtime/Configuration/modernuo.json" -Raw|ConvertFrom-Json
 @{assemblyDirectories=@('Assemblies');dataDirectories=@($existing.dataDirectories);listeners=@('127.0.0.1:2594');settings=@{
  'serverListing.serverName'='Britannia Reborn isolated horse tests';'serverListing.address'='127.0.0.1';'serverListing.autoDetect'='False';'network.encryptionMode'='Unencrypted';'accountHandler.enableAutoAccountCreation'='True';'accountHandler.maxAccountsPerIP'='6';'pathfinding.prebakeMaps'='False';'autosave.enabled'='False';'world.savePath'=(Join-Path $runtime 'Saves');'britanniaReborn.isolatedHorseTests'='True';'britanniaReborn.isolatedPlagueTests'=$(if ($CreatureFamily -eq 'amorphous') {'True'} else {'False'});'britanniaReborn.isolatedSolenTests'=$(if ($CreatureFamily -eq 'solen_workers') {'True'} else {'False'});'britanniaReborn.isolatedFluidElementalTests'=$(if ($CreatureFamily -eq 'fluid_elementals') {'True'} else {'False'});'britanniaReborn.isolatedJukaTests'=$(if ($CreatureFamily -eq 'juka') {'True'} else {'False'});'britanniaReborn.isolatedMageTests'=$(if ($CreatureFamily -eq 'mages') {'True'} else {'False'});'britanniaReborn.isolatedSilverSerpentTests'=$(if ($CreatureFamily -eq 'silver_serpents') {'True'} else {'False'});'ethics.enable'=$(if ($Ethics -or $EquineCompletion) {'True'} else {'False'});'factions.enabled'=$(if ($Ethics -or $EquineCompletion) {'True'} else {'False'});'pingServer.enabled'='False'
  'britanniaReborn.isolatedSavageTests'=$(if ($savageTrial) {'True'} else {'False'})
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
  if ($EtherealBeetle) {$liveArgs+='--ethereal-beetle'}
  if ($FireBeetle) {$liveArgs+='--fire-beetle'}
  if ($GiantBeetle) {$liveArgs+='--giant-beetle'}
  if ($SeaHorse) {$liveArgs+='--sea-horse'}
  if ($CreatureFamily) {$liveArgs+="--family=$CreatureFamily"}
  if ($preparedCreatureTrial) {$liveArgs+='--prepared'}
  $started=[DateTime]::UtcNow
  & $godot --headless --path Viewer --script $(if ($SavageRiders) {'res://Network/SavageRiderLive.gd'} elseif ($Savages) {'res://Network/SavageLive.gd'} elseif ($CreatureFamily -eq 'mages') {'res://Network/SourceMageLive.gd'} elseif ($CreatureFamily -eq 'juka') {'res://Network/SourceJukaLive.gd'} elseif ($CreatureFamily) {'res://Network/CreatureLive.gd'} elseif ($Ostards -or $EquineCompletion -or $LlamaCompletion -or $Ethics -or $Bovines -or $SeaHorse -or $GiantBeetle -or $FireBeetle -or $EtherealBeetle) {'res://Network/OstardLive.gd'} elseif ($Equines) {'res://Network/EquineLive.gd'} else {'res://Network/HorseLive.gd'}) -- @liveArgs
  if ($LASTEXITCODE) { throw 'Native isolated integration test failed' }
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
   $report=Join-Path $root "outputs/creatures/$CreatureFamily/live.json"
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
    $nativeFolder=Join-Path $root "work/creatures/$CreatureFamily"
    New-Item -ItemType Directory -Force $nativeFolder|Out-Null
    Copy-Item -LiteralPath "$root/work/creatures/live-candidates.json" -Destination "$nativeFolder/candidates.json" -Force
    @{runtime=$runtime;started_utc=$started.ToString('o');report_sha256=(Get-FileHash -LiteralPath $report).Hash.ToLowerInvariant();candidate_sha256=$native.candidate_sha256;build_inputs_sha256=$savageBuildInputs;assemblies_sha256=$savageAssemblies;reviewed_content_sha256=$receipt.assembly_sha256;selector_sha256=(Get-FileHash "$root/scripts/prepare-creature-fixtures.py").Hash.ToLowerInvariant();runner_sha256=(Get-FileHash "$root/scripts/test-horses.ps1").Hash.ToLowerInvariant();scope='Fresh disposable loopback2594 native constructors, movement, actions and corpse packets observed by two real clients; prepared mode is recorded in the actual report; no production saves/accounts'}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "$nativeFolder/native-runtime.json"
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
  if ($EquineCompletion -or $LlamaCompletion -or $Ostards -or $Ethics -or $Bovines -or $SeaHorse -or $GiantBeetle -or $FireBeetle -or $EtherealBeetle) {
   $reportName=if ($EtherealBeetle) {'ethereal-beetle-live.json'} elseif ($FireBeetle) {'fire-beetle-live.json'} elseif ($GiantBeetle) {'giant-beetle-live.json'} elseif ($SeaHorse) {'sea-horse-live.json'} elseif ($Bovines) {'bovine-live.json'} elseif ($Ethics) {'ethics-live.json'} elseif ($EquineCompletion) {'equine-completion-live.json'} elseif ($LlamaCompletion) {'llama-completion-live.json'} else {'live-validation.json'}
   $report=Join-Path $root "outputs/ostard-riding/$reportName"
   if (!(Test-Path $report) -or (Get-Item $report).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw 'Live test did not write fresh evidence; inspect the Godot log.'}
   if ((Get-Content $report -Raw|ConvertFrom-Json).failures -ne 0) {throw 'Live integration reported failures'}
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
