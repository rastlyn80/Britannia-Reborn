param([switch]$BuildIfNeeded)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$receiptPath=Join-Path $root 'work/server-fixes/build-manifest.json'
$recipe=Join-Path $root 'Server/fixes/ethics-registry.json'
$built=Join-Path $root 'Server/ModernUO/Distribution/Assemblies/UOContent.dll'
$runtime=Join-Path $root 'Server/runtime'
$installed=Join-Path $runtime 'Assemblies/UOContent.dll'
& python -B "$PSScriptRoot/prepare-server-fixes.py" --verify-only
if ($LASTEXITCODE) {throw 'Server overlay source audit failed'}
$valid=$false
if ((Test-Path $receiptPath) -and (Test-Path $built)) {
 $receipt=Get-Content $receiptPath -Raw|ConvertFrom-Json
 $valid=$receipt.recipe_sha256 -eq (Get-FileHash $recipe -Algorithm SHA256).Hash.ToLowerInvariant() -and $receipt.assembly_sha256 -eq (Get-FileHash $built -Algorithm SHA256).Hash.ToLowerInvariant()
}
if (!$valid) {
 if (!$BuildIfNeeded) {throw 'Run scripts/build-server.ps1 to prepare the reviewed server fix'}
 & "$PSScriptRoot/build-server.ps1"
 if ($LASTEXITCODE) {throw 'Server fix build failed'}
 $receipt=Get-Content $receiptPath -Raw|ConvertFrom-Json
}
if (!(Test-Path $installed)) {throw 'Configure the local server runtime before installing its content update'}
$status=@{assembly_sha256=$receipt.assembly_sha256;installed=$false;pending_restart=$false}
$lock=$null
try {
 try {$lock=[IO.File]::Open((Join-Path $runtime '.server.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
 catch {$status.pending_restart=$true}
 if ($lock) {
  $probe=[Net.Sockets.TcpClient]::new()
  try {
   $attempt=$probe.ConnectAsync('127.0.0.1',2593)
   if ($attempt.Wait(500) -and $probe.Connected) {$status.pending_restart=$true}
  } catch [AggregateException] {
   if ($_.Exception.InnerException.SocketErrorCode -eq 'AccessDenied') {throw 'Local listener access is required to check that the server is stopped'}
  } finally {$probe.Dispose()}
  if (!$status.pending_restart) {
   if ((Get-FileHash $installed -Algorithm SHA256).Hash.ToLowerInvariant() -ne $receipt.assembly_sha256) {
    $temporary=$installed+'.pending'
    Copy-Item -LiteralPath $built -Destination $temporary -Force
    [IO.File]::Move($temporary,$installed,$true)
   }
   $status.installed=$true
  }
 }
} finally {if ($lock) {$lock.Dispose()}}
$status|ConvertTo-Json|Set-Content (Join-Path $root 'work/server-fixes/install-status.json')
if ($status.pending_restart) {Write-Output 'Verified server fix prepared; the running world is untouched. The next normal server start installs it.'}
else {Write-Output 'Verified server fix installed. Existing settings, accounts and saves are preserved.'}
