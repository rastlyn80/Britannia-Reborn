# Connects Claude Code (or any assistant) to the live developer edit session.
# Joins as the assistant "Claude" through a development account and stays
# connected: every request, answer, proposal and edit is appended as JSON to
# -Outbox; every line appended to -Inbox is executed (answer/propose/edits,
# grammar in Viewer/DevEdit/DevEditCli.gd). In a Claude Code session, ask
# Claude to "watch the dev edit bridge"; it monitors the outbox and replies
# through the inbox. It reconnects by itself after a server restart. Write
# "quit" to the inbox (or delete it) to stop. -Detached starts it in its own
# hidden process, so it outlives the shell that launched it.
param([string]$Inbox,[string]$Outbox,[ValidateSet('1','2')][string]$Account = '2',[switch]$AsEditor,[switch]$Detached)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$folder = Join-Path $root 'work/dev-edit-bridge'
New-Item -ItemType Directory -Force $folder | Out-Null
if (!$Inbox) { $Inbox = Join-Path $folder 'inbox.txt' }
if (!$Outbox) { $Outbox = Join-Path $folder 'outbox.jsonl' }
if ($Detached) {
  $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Inbox',$Inbox,'-Outbox',$Outbox,'-Account',$Account)
  if ($AsEditor) { $arguments += '-AsEditor' }
  $process = Start-Process powershell.exe -ArgumentList ($arguments | ForEach-Object { if ($_ -match ' ') { '"' + $_ + '"' } else { $_ } }) -WindowStyle Hidden -PassThru
  Write-Output "Bridge running detached (process $($process.Id)). Stop it by writing quit to $Inbox"
  return
}
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
$extra = @("--account=$Account","--serve=$Inbox","--outbox=$Outbox")
if (!$AsEditor) { $extra += '--assistant' }
Write-Output "Inbox: $Inbox"
Write-Output "Outbox: $Outbox"
# Only a "quit" written after this launch stops it (an old one stays in the file).
$started = if (Test-Path $Inbox) { (Get-Item $Inbox).Length } else { 0 }
function Stopping {
  if (!(Test-Path $Inbox)) { return $true }
  $bytes = [IO.File]::ReadAllBytes($Inbox)
  if ($bytes.Length -le $started) { return $false }
  $fresh = [Text.Encoding]::UTF8.GetString($bytes, $started, $bytes.Length - $started)
  return @($fresh -split "`n" | ForEach-Object { $_.Trim() }) -contains 'quit'
}
try {
  while ($true) {
    & $godot --headless --path "$root/Viewer" --script res://DevEdit/DevEditCli.gd -- @extra | Out-Null
    if (Stopping) { break }
    # Disconnected (server restart, login refused): retry shortly.
    Start-Sleep 10
  }
}
finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
