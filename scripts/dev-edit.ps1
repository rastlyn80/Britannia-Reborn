# Claude Code / scripted bridge into the live developer edit session.
# Joins as an authorized development account (default: the second one, so the
# in-game client can stay logged in with the first) and runs the same textual
# commands the in-game panel uses, printing one JSON line per command.
#   ./scripts/dev-edit.ps1 -Commands 'inspect 1602 1591 2; place 4153 1604 1588 20 30; list'
# See Viewer/DevEdit/DevEditCli.gd for the verbs. Requires the running local
# server with scripts/configure-dev-edit.ps1 applied.
param([string]$Commands = 'status',[string]$File,[ValidateSet('1','2')][string]$Account = '2')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
$env:UO_DEV_USER = $credentials.username
$env:UO_DEV_PASSWORD = $credentials.password
$extra = @("--account=$Account","--commands=$Commands")
if ($File) { $extra += "--file=$((Resolve-Path $File).Path)" }
try {
 & $godot --headless --path "$root/Viewer" --script res://DevEdit/DevEditCli.gd -- @extra | Where-Object { $_ -like 'DEVEDIT *' } | ForEach-Object { $_.Substring(8) }
 if ($LASTEXITCODE) { exit $LASTEXITCODE }
} finally { Remove-Item Env:\UO_DEV_USER,Env:\UO_DEV_PASSWORD -ErrorAction SilentlyContinue }
