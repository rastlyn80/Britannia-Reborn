# Builds the private friends' test package (owner decision, 1 November 2026:
# for the owner's own test group only, including the baked Trammel and the UO
# data files; never published). Output: work/release/BritanniaReborn (a ready
# folder) and, with -Zip, work/release/BritanniaReborn-test.zip.
#  - The client (Viewer with its import cache, Godot), the baked Trammel
#    (outputs/trammel), the server (a clean copy of Server/runtime: no saves,
#    accounts, logs or dev-edit state) with its .NET runtime, the UO data.
#  - The world is prepared here on port 2594 (not the running server): the
#    owner account "admin" with a random password (created by OwnerBootstrap
#    from a one-time file, as a hidden server cannot answer ModernUO's console
#    prompt), its character "Tester", the whole Trammel population, saved.
#  - Play.cmd, Stop Server.cmd and README.txt (scripts/release-kit).
#   scripts/package-friends.ps1 [-Zip] [-SkipCopy]
# -SkipCopy reuses an existing copy and only prepares the world again.
param([switch]$Zip, [string]$Character = 'Tester', [switch]$SkipCopy)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'work\release'
$stage = Join-Path $out 'BritanniaReborn'
$runtime = Join-Path $stage 'Server\runtime'
if ((Test-Path $stage) -and !$SkipCopy) { throw "$stage exists; remove it first, or use -SkipCopy" }
New-Item -ItemType Directory -Force $stage | Out-Null
$config = Get-Content (Join-Path $root 'Server\runtime\Configuration\modernuo.json') -Raw | ConvertFrom-Json
$uo = @($config.dataDirectories)[0]

function Mirror($from, $to, [string[]]$excludeDirs = @(), [string[]]$excludeFiles = @()) {
  $arguments = @($from, $to, '/E', '/MT:16', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
  if ($excludeDirs.Count) { $arguments += '/XD'; $arguments += $excludeDirs }
  if ($excludeFiles.Count) { $arguments += '/XF'; $arguments += $excludeFiles }
  & robocopy @arguments | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "Copy failed: $from" }
}

if (!$SkipCopy) {
  Write-Output 'Copying the client...'
  Mirror (Join-Path $root 'Viewer') (Join-Path $stage 'Viewer') @((Join-Path $root 'Viewer\zz_probe'), (Join-Path $root 'Viewer\zz_scratch'))
  Write-Output 'Copying the baked Trammel...'
  Mirror (Join-Path $root 'outputs\trammel') (Join-Path $stage 'outputs\trammel') @((Join-Path $root 'outputs\trammel\bake-logs'))
  Write-Output 'Copying the tools...'
  New-Item -ItemType Directory -Force (Join-Path $stage '.tools\godot') | Out-Null
  Copy-Item (Join-Path $root '.tools\godot\Godot_v4.7.2-stable_win64.exe') (Join-Path $stage '.tools\godot\')
  Mirror (Join-Path $root '.tools\dotnet-server') (Join-Path $stage '.tools\dotnet-server')
  Write-Output 'Copying the server...'
  Mirror (Join-Path $root 'Server\runtime') $runtime @('Saves', 'Saves.previous*', 'Backups', 'Archives', 'Logs', 'DevEdit', 'temp') @('*.log', 'Crash*', '.server.lock', 'no-input.txt')
  Write-Output 'Copying the UO data...'
  Mirror $uo (Join-Path $stage 'UO')
  Copy-Item (Join-Path $root 'launch.ps1') $stage
}
foreach ($file in 'Play.ps1', 'Play.cmd', 'Stop Server.cmd') { Copy-Item (Join-Path $PSScriptRoot "release-kit\$file") $stage }
# A fresh world each time: no saves or crash leftovers from an earlier attempt.
Remove-Item (Join-Path $runtime 'Saves'), (Join-Path $runtime 'Backups'), (Join-Path $runtime 'Logs') -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $runtime -Filter 'Crash*' -ErrorAction SilentlyContinue | Remove-Item -Force

# The server: this package's data, port 2594 while it is prepared, dev tools
# for the package's own admin only, and the current extension build
# (installing into the running server is blocked).
$password = -join ((48..57) + (97..122) | Get-Random -Count 12 | ForEach-Object { [char]$_ })
$serverConfig = Join-Path $runtime 'Configuration\modernuo.json'
$settings = Get-Content $serverConfig -Raw | ConvertFrom-Json
$settings.dataDirectories = @((Join-Path $stage 'UO'))
$settings.listeners = @('127.0.0.1:2594')
$settings.settings.'ultimaClone.devEdit.accounts' = 'admin'
$settings | ConvertTo-Json -Depth 12 | Set-Content $serverConfig -Encoding UTF8
Copy-Item (Join-Path $root 'Server\PreviewTools\bin\Release\net10.0\UltimaClone.PreviewTools.dll') (Join-Path $runtime 'Assemblies\') -Force
$ownerFile = Join-Path $runtime 'Data\ultimaclone-owner.json'
[IO.File]::WriteAllText($ownerFile, (@{ username = 'admin'; password = $password } | ConvertTo-Json))
$empty = Join-Path $out 'no-input.txt'
Set-Content -LiteralPath $empty -Value '' -NoNewline

Write-Output 'Preparing the world (owner account, character, Trammel population)...'
$dotnet = Join-Path $stage '.tools\dotnet-server\dotnet.exe'
$env:DOTNET_ROOT = Split-Path $dotnet
$serverLog = Join-Path $out 'prepare-server.log'
$server = Start-Process -FilePath $dotnet -ArgumentList '.\ModernUO.dll' -WorkingDirectory $runtime -WindowStyle Hidden -RedirectStandardInput $empty -RedirectStandardOutput $serverLog -RedirectStandardError ($serverLog + '.err') -PassThru
try {
  $deadline = (Get-Date).AddMinutes(5)
  while (!(Select-String -LiteralPath $serverLog -Pattern 'Listening: 127.0.0.1:2594' -Quiet -ErrorAction SilentlyContinue)) {
    if ($server.HasExited -or (Get-Date) -gt $deadline) { throw "The package server did not start; see $serverLog" }
    Start-Sleep -Seconds 2
  }
  $env:APPDATA = Join-Path $root '.godot-user'
  $env:LOCALAPPDATA = $env:APPDATA
  $env:UO_DEV_USER = 'admin'
  $env:UO_DEV_PASSWORD = $password
  $env:UO_DEV_PORT = '2594'
  $env:UO_DEV_CHARACTER = $Character
  $godot = (Get-ChildItem "$root\.tools\godot\*console.exe" | Select-Object -First 1).FullName
  $populate = Get-Content -LiteralPath $empty | & $godot --headless --path (Join-Path $root 'Viewer') --script res://Network/TrammelLive.gd 2>&1 | Out-String
  if ($populate -notmatch 'TRAMMEL LIVE PASS') { throw "World preparation failed:`n$populate" }
  ($populate -split "`r?`n" | Where-Object { $_ -match '^TRAMMEL:' }) | Write-Output
} finally {
  Remove-Item Env:\UO_DEV_USER, Env:\UO_DEV_PASSWORD, Env:\UO_DEV_PORT, Env:\UO_DEV_CHARACTER -ErrorAction SilentlyContinue
  if (!$server.HasExited) { Stop-Process -Id $server.Id -Force }
  Remove-Item $ownerFile -ErrorAction SilentlyContinue
}
# Back to the normal port; the friends' launcher fills in their own paths.
$settings.listeners = @('127.0.0.1:2593')
$settings | ConvertTo-Json -Depth 12 | Set-Content $serverConfig -Encoding UTF8
Remove-Item (Join-Path $runtime 'Backups'), (Join-Path $runtime 'Logs') -Recurse -Force -ErrorAction SilentlyContinue
# Remembered sign-in for the launcher, and the README with it.
New-Item -ItemType Directory -Force (Join-Path $stage 'Server') | Out-Null
[IO.File]::WriteAllText((Join-Path $stage 'Server\credentials.local.json'), (@{ username = 'admin'; password = $password } | ConvertTo-Json))
$readme = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'release-kit\README.txt')).Replace('{USERNAME}', 'admin').Replace('{PASSWORD}', $password)
[IO.File]::WriteAllText((Join-Path $stage 'README.txt'), $readme)
$size = (Get-ChildItem $stage -Recurse -File | Measure-Object Length -Sum).Sum / 1GB
Write-Output ("Package ready: {0} ({1:N1} GB)" -f $stage, $size)
if ($Zip) {
  $zipPath = Join-Path $out 'BritanniaReborn-test.zip'
  Remove-Item $zipPath -ErrorAction SilentlyContinue
  & tar.exe -a -c -f $zipPath -C $out 'BritanniaReborn'
  if ($LASTEXITCODE) { throw 'Zip failed' }
  Write-Output ("Zip ready: {0} ({1:N1} GB)" -f $zipPath, ((Get-Item $zipPath).Length / 1GB))
}
