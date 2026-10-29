param([switch]$Live,[switch]$SkipContact,[switch]$Gpu)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
Push-Location $root
try {
 & "$PSScriptRoot/prepare-horses.ps1" -VerifyOnly
 & $godot --headless --path Viewer --editor --import
 if ($LASTEXITCODE) { throw 'Horse import failed' }
 if (!$SkipContact) {
  & $godot --headless --path Viewer --script res://Presentation/HorseTests.gd
  if ($LASTEXITCODE) { throw 'Horse contact/playback checks failed' }
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
 $runtime=Join-Path $root 'work/horse-session/server'
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
 $dotnet="$root/.tools/dotnet-server/dotnet.exe"
 $env:DOTNET_CLI_HOME=Join-Path $root '.dotnet-home'
 Push-Location "$root/Server/HorseIntegrationFixtures"
 try { & $dotnet build -c Release --ignore-failed-sources } finally { Pop-Location }
 if ($LASTEXITCODE) { throw 'Isolated fixture extension build failed' }
 Copy-Item "$root/Server/HorseIntegrationFixtures/bin/Release/net10.0/BritanniaReborn.HorseIntegrationFixtures.dll" "$runtime/Assemblies/" -Force
 ConvertTo-Json -InputObject @('UOContent.dll','BritanniaReborn.HorseIntegrationFixtures.dll')|Set-Content "$runtime/Data/assemblies.json"
 $existing=Get-Content "$root/Server/runtime/Configuration/modernuo.json" -Raw|ConvertFrom-Json
 @{assemblyDirectories=@('Assemblies');dataDirectories=@($existing.dataDirectories);listeners=@('127.0.0.1:2594');settings=@{
  'serverListing.serverName'='Britannia Reborn isolated horse tests';'serverListing.address'='127.0.0.1';'serverListing.autoDetect'='False';'network.encryptionMode'='Unencrypted';'accountHandler.enableAutoAccountCreation'='True';'accountHandler.maxAccountsPerIP'='6';'pathfinding.prebakeMaps'='False';'autosave.enabled'='False';'world.savePath'=(Join-Path $runtime 'Saves');'britanniaReborn.isolatedHorseTests'='True'
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
  & $godot --headless --path Viewer --script res://Network/HorseLive.gd
  if ($LASTEXITCODE) { throw 'Native isolated horse integration test failed' }
 } finally {
  # This exact process was created above for the disposable runtime. The
  # existing port-2593 world and its saves are never stopped or modified.
  if (!$server.HasExited) { Stop-Process -Id $server.Id }
 }
} finally { Pop-Location }
