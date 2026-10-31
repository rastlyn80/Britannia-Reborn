param([string[]]$Families=@('bruins'),[int]$Jobs=3,[switch]$Capture,[switch]$Live)
$ErrorActionPreference='Stop'
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
 $started=[DateTime]::UtcNow
 $arguments='--path "'+$root+'/Viewer" --script res://Presentation/CreatureAppearanceTests.gd -- --family='+$family
 $process=Start-Process $godot -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/$family-gpu.log" -RedirectStandardError "$logs/$family-gpu-errors.log"
 $null=$process.Handle
 $process.WaitForExit();$path="$root/outputs/creatures/$family/appearance.json"
 if ($process.ExitCode -ne 0 -or !(Test-Path $path) -or (Get-Item $path).LastWriteTimeUtc -lt $started.AddSeconds(-1)) {throw "Creature GPU test failed or did not produce fresh evidence: $family"}
 & python -B "$root/scripts/accept-creatures.py" $family
 if ($LASTEXITCODE) {throw "Creature asset hash/acceptance check failed: $family"}
 if ($Capture) {
  $preparation=Get-Content "$root/Viewer/local-art/creatures/$family/preparation.json" -Raw|ConvertFrom-Json
  foreach ($model in $preparation.models) {
   if ($model.status -ne 'prepared') {continue}
   $arguments='--path "'+$root+'/Viewer" --script res://Presentation/CreatureReview.gd -- --capture --family='+$family+' --kind='+$model.kind
   $process=Start-Process $godot -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/$($model.kind)-capture.log" -RedirectStandardError "$logs/$($model.kind)-capture-errors.log"
   $null=$process.Handle
   $process.WaitForExit()
   if ($process.ExitCode -ne 0) {throw "Creature review capture failed: $($model.kind)"}
  }
 }
 if ($Live) {
  & "$PSScriptRoot/test-horses.ps1" -Live -SkipContact -CreatureFamily $family *> "$logs/$family-native.log"
  if ($LASTEXITCODE) {throw "Creature native integration failed: $family"}
 }
 } catch {
  Write-Warning "Creature batch needs follow-up: $family / $_"
  $failed.Add($family)
 }
}
if ($failed.Count) {throw ('Creature families still failing: '+($failed -join ', '))}
