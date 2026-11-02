param([string[]]$Families=@('bruins'),[int]$Jobs=3,[switch]$Capture,[switch]$Live)
$ErrorActionPreference='Stop'
if ($args.Count) {throw "Unexpected arguments: $args. Pass multiple families as -Families @('ettins','deer','orcs')."}
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
if ($Jobs -lt 1 -or $Jobs -gt 4) {throw 'Use one to four independent pose workers'}
foreach ($family in $Families) {if ($family -notmatch '^[a-z][a-z0-9_]*$') {throw 'Invalid creature family name'}}
$logs=Join-Path $root 'work/creature-checks';New-Item -ItemType Directory -Force $logs|Out-Null
& python -B "$root/scripts/configure-creature-imports.py" @Families
if ($LASTEXITCODE -notin @(0,3)) {throw 'Creature animation import configuration failed'}
& $godot --headless --path "$root/Viewer" --editor --import *> "$logs/import.log"
if ($LASTEXITCODE) {throw 'Creature resource import failed'}
& python -B "$root/scripts/configure-creature-imports.py" @Families
if ($LASTEXITCODE -eq 3) {
 & $godot --headless --path "$root/Viewer" --editor --import *> "$logs/import-precision.log"
 if ($LASTEXITCODE) {throw 'Creature precision-preserving resource import failed'}
} elseif ($LASTEXITCODE -ne 0) {throw 'Creature animation import configuration failed'}
& $godot --headless --path "$root/Viewer" --script res://Presentation/CreatureReview.gd --check-only *> "$logs/review-parse.log"
if ($LASTEXITCODE) {throw 'Creature review script validation failed'}
$pending=[Collections.Generic.Queue[string]]::new()
foreach ($family in $Families) {
 & python -B "$root/scripts/check-creature-evidence.py" $family
 if ($LASTEXITCODE) {$pending.Enqueue($family)}
}
$running=[Collections.Generic.List[object]]::new()
$failed=[Collections.Generic.List[string]]::new()
while ($pending.Count -or $running.Count) {
 while ($pending.Count -and $running.Count -lt $Jobs) {
  $family=$pending.Dequeue();$started=[DateTime]::UtcNow
  $arguments='--headless --path "'+$root+'/Viewer" --script res://Presentation/CreatureTests.gd -- --family='+$family
  $process=Start-Process $godot -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/$family-poses.log" -RedirectStandardError "$logs/$family-poses-errors.log"
  $null=$process.Handle
  $running.Add(@{family=$family;process=$process;started=$started})
 }
 foreach ($job in @($running.ToArray())) {
  if (!$job.process.HasExited) {continue}
  $job.process.WaitForExit();$path="$root/outputs/creatures/$($job.family)/validation.json"
  if ($job.process.ExitCode -ne 0 -or !(Test-Path $path) -or (Get-Item $path).LastWriteTimeUtc -lt $job.started.AddSeconds(-1)) {
   Write-Warning "Creature pose test failed or did not produce fresh evidence: $($job.family); exit=$($job.process.ExitCode)"
   $failed.Add($job.family);$running.Remove($job)|Out-Null;continue
  }
  $result=Get-Content $path -Raw|ConvertFrom-Json
  if ($result.failures -ne 0) {throw "Creature skin validation failed: $($job.family)"}
  $receipt="$root/outputs/creatures/$($job.family)/pose-inputs.json"
  if (Test-Path $receipt) {Remove-Item -LiteralPath $receipt}
  & python -B "$root/scripts/check-creature-evidence.py" $job.family
  if ($LASTEXITCODE) {throw "Creature pose inputs changed during validation: $($job.family)"}
  Write-Output "CREATURE POSES VERIFIED: $($job.family) / $($result.checks) checks"
  $running.Remove($job)|Out-Null
 }
 if ($running.Count) {Start-Sleep -Milliseconds 200}
}
foreach ($family in $Families) {
 if ($failed.Contains($family)) {continue}
 try {
 if ($family -eq 'dragons') {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/CreatureContactTests.gd -- "--family=$family" *> "$logs/$family-contact.log"
  if ($LASTEXITCODE) {throw 'Animated dragon sole/contact checks failed'}
 }
 if ($family -in @('gazers','genies')) {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/FloatingCreatureTests.gd -- "--family=$family" *> "$logs/$family-hover.log"
  if ($LASTEXITCODE) {throw 'Floating creature avatar/support checks failed'}
 }
 if ($family -in @('krakens','sea','dolphins')) {
  & $godot --path "$root/Viewer" --script res://Presentation/AquaticPresentationTests.gd -- "--family=$family" *> "$logs/$family-aquatic.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/$family-aquatic.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw 'Aquatic waterline/material/corpse checks failed'}
 }
 if ($family -eq 'krakens') {
  & $godot --path "$root/Viewer" --script res://Presentation/CephalopodGestureTests.gd *> "$logs/krakens-gestures.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/krakens-gestures.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw 'Measured cephalopod strike/casting checks failed'}
 }
 if ($family -eq 'elementals') {
  & $godot --path "$root/Viewer" --script res://Presentation/MineralAppearanceTests.gd *> "$logs/$family-minerals.log"
  if ($LASTEXITCODE) {throw 'Mineral PBR map/tangent/material response checks failed'}
 }
 if ($family -in @('orcs','ettins')) {
  & $godot --path "$root/Viewer" --script res://Presentation/CreatureGestureTests.gd -- "--family=$family" *> "$logs/$family-gestures.log"
  if ($LASTEXITCODE) {throw 'Authored orc gesture, stance, grip and GPU response checks failed'}
 }
 if ($family -eq 'deer') {
  & $godot --path "$root/Viewer" --script res://Presentation/CervidActionTests.gd *> "$logs/deer-gestures.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/deer-gestures.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw 'Cervid muzzle, hoof, skin and finite terrain checks failed'}
 }
 if ($family -eq 'walking' -and (Test-Path "$root/Viewer/local-art/creatures/walking_dead_zombie-modern.gltf")) {
  & $godot --path "$root/Viewer" --script res://Presentation/ZombiePresentationTests.gd *> "$logs/walking-zombie-avatar.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/walking-zombie-avatar.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw 'Actual zombie avatar, short-step support, hues or native corpse checks failed'}
 }
 $measuredPreparation=Get-Content "$root/Viewer/local-art/creatures/$family/preparation.json" -Raw|ConvertFrom-Json
 foreach ($model in @($measuredPreparation.models|Where-Object {$_.status -eq 'prepared' -and $_.contact_kind -eq 'measured_limbs'})) {
  $limbTest=if ($family -eq 'mages') {'SourceMagePresentationTests'} else {'MeasuredCreaturePresentationTests'}
  & $godot --path "$root/Viewer" --script "res://Presentation/$limbTest.gd" -- "--kind=$($model.kind)" *> "$logs/$($model.kind)-avatar.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/$($model.kind)-avatar.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw "Measured source limb/skin/terrain/corpse proof failed: $($model.kind)"}
 }
 if ($family -eq 'mages') {
  foreach ($mageTest in @('SourceMageActionTests','SourceMageTransitionTests','SourceMageMixedTerrainTests','SourceMageEquipmentTests')) {
   & $godot --path "$root/Viewer" --script "res://Presentation/$mageTest.gd" -- --output=res://../outputs/creatures/mages/equipment *> "$logs/$mageTest.log"
   if ($LASTEXITCODE -or (Select-String -Path "$logs/$mageTest.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Source mage graphics/equipment/transition proof failed: $mageTest"}
  }
 }
 if ($family -eq 'silver_serpents') {
  foreach ($test in @('SourceSilverSerpentActionTests','SourceSilverSerpentTransitionTests','SourceSilverSerpentPresentationTests')) {
   & $godot --path "$root/Viewer" --script "res://Presentation/$test.gd" *> "$logs/$test.log"
   if ($LASTEXITCODE -or (Select-String -Path "$logs/$test.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original Silver source/rig/whole-skin/terrain/colour/corpse proof failed: $test"}
  }
 }
 if ($family -eq 'fluid_elementals') {
  foreach ($kind in @('elementals_acid_elemental','elementals_poison_elemental')) {
   foreach ($test in @('SourceFluidElementalActionTests','SourceFluidElementalPresentationTests','SourceFluidElementalTransitionTests')) {
    & $godot --path "$root/Viewer" --script "res://Presentation/$test.gd" -- "--kind=$kind" *> "$logs/$kind-$test.log"
    if ($LASTEXITCODE -or (Select-String -Path "$logs/$kind-$test.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original fluid elemental source/gel/terrain/clock/corpse/mixed skin proof failed: $kind/$test"}
   }
  }
 }
 if ($family -eq 'solen_workers') {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/SourceSolenActionTests.gd *> "$logs/source-solen-actions.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/source-solen-actions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original Solen source/action/Attack2 holdouts or second fidget failed'}
  foreach ($kind in @('fire_ant_worker','black_ant_worker')) {
   & $godot --path "$root/Viewer" --script res://Presentation/SourceSolenPresentationTests.gd -- "--kind=$kind" *> "$logs/$kind-avatar.log"
   if ($LASTEXITCODE -or (Select-String -Path "$logs/$kind-avatar.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original Solen six-leg/whole-skin/UV/hue/picking/corpse proof failed: $kind"}
   & $godot --path "$root/Viewer" --script res://Presentation/SourceSolenTransitionTests.gd -- "--kind=$kind" *> "$logs/$kind-transitions.log"
   if ($LASTEXITCODE -or (Select-String -Path "$logs/$kind-transitions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original Solen mixed gait/action/protected torso/ground support failed: $kind"}
  }
 }
 if ($family -eq 'amorphous') {
  foreach ($test in @('SourcePoseSubdivisionTests','SourceAmorphousActionTests','SourcePoseSubdivisionGpuTests')) {
   & $godot --path "$root/Viewer" --script "res://Presentation/$test.gd" *> "$logs/$test.log"
   if ($LASTEXITCODE -or (Select-String -Path "$logs/$test.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original amorphous source/subdivision/action proof failed: $test"}
  }
  foreach ($kind in @('plague_beast','slimes_slime')) {
   foreach ($test in @('SourceAmorphousPresentationTests','SourceAmorphousTransitionTests')) {
    & $godot --path "$root/Viewer" --script "res://Presentation/$test.gd" -- "--kind=$kind" *> "$logs/$kind-$test.log"
    if ($LASTEXITCODE -or (Select-String -Path "$logs/$kind-$test.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original amorphous actual avatar/terrain/hues/corpse/blend failed: $kind/$test"}
   }
  }
 }
 if ($family -eq 'frogs') {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/SourceFrogActionTests.gd *> "$logs/source-frogs-actions.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/source-frogs-actions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original frog joint/hop/tongue/Hit holdouts or native action timing failed'}
  foreach ($kind in @('frogs_bullfrog','frogs_frog_giant')) {
   & $godot --path "$root/Viewer" --script res://Presentation/SourceFrogPresentationTests.gd -- "--kind=$kind" *> "$logs/$kind-avatar.log"
   if ($LASTEXITCODE -or (Select-String -Path "$logs/$kind-avatar.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original frog actual avatar/material/hues/terrain/corpse failed: $kind"}
   & $godot --path "$root/Viewer" --script res://Presentation/SourceFrogTransitionTests.gd -- "--kind=$kind" *> "$logs/$kind-transitions.log"
   if ($LASTEXITCODE -or (Select-String -Path "$logs/$kind-transitions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw "Original frog mixed skins/feeding/death/hops/picking failed: $kind"}
  }
 }
 if ($family -eq 'snow_elementals') {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/SourceElementalActionTests.gd *> "$logs/source-snow-actions.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/source-snow-actions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original Snow skins, vertical run, source hierarchy or repeated native actions failed'}
  & $godot --path "$root/Viewer" --script res://Presentation/SourceElementalPresentationTests.gd *> "$logs/source-snow-avatar.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/source-snow-avatar.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original Snow actual avatar/material, source lift, finite terrain or corpse failed'}
  & $godot --path "$root/Viewer" --script res://Presentation/SourceElementalTransitionTests.gd *> "$logs/source-snow-transitions.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/source-snow-transitions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original Snow mixed skins, death blend, slope soles or actual picking failed'}
 }
 if ($family -eq 'liches') {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/LichActionTests.gd *> "$logs/liches-actions.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/liches-actions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Original Lich source/grip/limb/corpse checks failed'}
  & $godot --path "$root/Viewer" --script res://Presentation/LichPresentationTests.gd *> "$logs/liches-avatar.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/liches-avatar.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Actual Lich avatar/material/render-stage support/picking/corpse checks failed'}
 }
 if ($family -eq 'ice_serpents') {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/IceSerpentTransitionTests.gd *> "$logs/ice-serpents-transitions.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/ice-serpents-transitions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Ice serpent mixed poses, finite-plane transitions or native action duration failed'}
  & $godot --headless --path "$root/Viewer" --script res://Presentation/IceSerpentActionTests.gd *> "$logs/ice-serpents-actions.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/ice-serpents-actions.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Ice serpent retained-source skins, jaw amendment, shared floor curves or action routing failed'}
  & $godot --path "$root/Viewer" --script res://Presentation/IceSerpentPresentationTests.gd *> "$logs/ice-serpents-avatar.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/ice-serpents-avatar.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {throw 'Ice serpent actual avatar, PBR/hues, off-grid terrain, weighted bounds or corpse failed'}
 }
 if ($family -eq 'small_snakes') {
  & $godot --headless --path "$root/Viewer" --script res://Presentation/SmallSnakeActionTests.gd *> "$logs/small-snakes-actions.log"
  if ($LASTEXITCODE) {throw 'Small-snake dynamic skin envelope and gait selection failed'}
  & $godot --path "$root/Viewer" --script res://Presentation/SmallSnakePresentationTests.gd *> "$logs/small-snakes-avatar.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/small-snakes-avatar.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw 'Actual small-snake scaled skin, terrain, hues, bounds or corpse checks failed'}
 }
 if ($family -eq 'serpents' -and (Test-Path "$root/Viewer/local-art/creatures/serpents_snake_giant-modern.gltf")) {
  & $godot --path "$root/Viewer" --script res://Presentation/SerpentPresentationTests.gd *> "$logs/serpents-avatar.log"
  if ($LASTEXITCODE -or (Select-String -Path "$logs/serpents-avatar.log" -Pattern 'SCRIPT ERROR:' -Quiet)) {throw 'Actual serpent weighted-skin support, native hues, selection or final death/corpse checks failed'}
 }
 $started=[DateTime]::UtcNow
 $arguments='--path "'+$root+'/Viewer" --script res://Presentation/CreatureAppearanceTests.gd -- --family='+$family
 $process=Start-Process $godot -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/$family-gpu.log" -RedirectStandardError "$logs/$family-gpu-errors.log"
 $null=$process.Handle
 $process.WaitForExit();$path="$root/outputs/creatures/$family/appearance.json"
 if ($process.ExitCode -ne 0 -or !(Test-Path $path) -or (Get-Item $path).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw "Creature GPU test failed or did not produce fresh evidence: $family"}
 if ($family -eq 'spirits') {
  & $godot --path "$root/Viewer" --script res://Presentation/CreatureFlashTests.gd *> "$logs/$family-death-effect.log"
  if ($LASTEXITCODE) {throw 'Recovered spirit death effect checks failed'}
 }
 if ($Live -and $family -eq 'mages') {
  & "$PSScriptRoot/test-horses.ps1" -Live -SkipContact -CreatureFamily $family *> "$logs/$family-native.log"
  if ($LASTEXITCODE) {throw 'Prepared native mage source/appearance/behaviour integration failed'}
 }
 & python -B "$root/scripts/accept-creatures.py" $family
 if ($LASTEXITCODE) {throw "Creature asset hash/acceptance check failed: $family"}
 if ($Capture) {
  $preparation=Get-Content "$root/Viewer/local-art/creatures/$family/preparation.json" -Raw|ConvertFrom-Json
  foreach ($model in $preparation.models) {
   if ($model.status -ne 'prepared') {continue}
   $captureStarted=[DateTime]::UtcNow
   $arguments='--path "'+$root+'/Viewer" --script res://Presentation/CreatureReview.gd -- --capture --family='+$family+' --kind='+$model.kind
   $process=Start-Process $godot -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/$($model.kind)-capture.log" -RedirectStandardError "$logs/$($model.kind)-capture-errors.log"
   $null=$process.Handle
   $process.WaitForExit()
   if ($process.ExitCode -ne 0) {throw "Creature review capture failed: $($model.kind)"}
   $fresh=@(Get-ChildItem "$root/outputs/creatures/$family/$($model.kind)" -File -Filter '*.png' | Where-Object {$_.LastWriteTimeUtc -ge $captureStarted.AddSeconds(-1)})
   if ($fresh.Count -ne 16) {throw "Creature review did not produce 16 fresh core frames: $($model.kind)"}
  }
 }
 if ($Live -and $family -ne 'mages') {
  & "$PSScriptRoot/test-horses.ps1" -Live -SkipContact -CreatureFamily $family *> "$logs/$family-native.log"
  if ($LASTEXITCODE) {throw "Creature native integration failed: $family"}
 }
 } catch {
  Write-Warning "Creature batch needs follow-up: $family / $_"
  $failed.Add($family)
 }
}
if ($failed.Count) {throw ('Creature families still failing: '+($failed -join ', '))}
# Every accepted body, including future additions, must also have a static
# corpse and an entry in the graphic-ID/body variant browser.
& "$PSScriptRoot/build-corpse-catalogue.ps1" -Render *> "$logs/corpses.log"
if ($LASTEXITCODE) {throw 'Static corpse coverage failed'}
