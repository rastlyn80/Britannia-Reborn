# Connects Claude Code (or any assistant) to the live developer edit session.
# Joins as the assistant "Claude" through a development account and stays
# connected: every request, answer, proposal and edit is appended as JSON to
# -Outbox; every line appended to -Inbox is executed (answer/propose/edits,
# grammar in Viewer/DevEdit/DevEditCli.gd). In a Claude Code session, ask
# Claude to "watch the dev edit bridge"; it monitors the outbox and replies
# through the inbox. Write "quit" to the inbox (or delete it) to stop.
param([string]$Inbox,[string]$Outbox,[ValidateSet('1','2')][string]$Account = '2',[switch]$AsEditor)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$folder = Join-Path $root 'work/dev-edit-bridge'
New-Item -ItemType Directory -Force $folder | Out-Null
if (!$Inbox) { $Inbox = Join-Path $folder 'inbox.txt' }
if (!$Outbox) { $Outbox = Join-Path $folder 'outbox.jsonl' }
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
try { & $godot --headless --path "$root/Viewer" --script res://DevEdit/DevEditCli.gd -- @extra | Out-Null }
finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
