# Starts the in-game assistant if it is not running: the dev edit bridge
# (Claude's connection to the session) and the automatic responder (answers
# asks with headless Claude Code when no interactive session is watching).
# Both run hidden and survive this window; Start-Server.cmd calls this.
$ErrorActionPreference = 'Stop'
$running = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'powershell*' -and $_.CommandLine }
if (!($running | Where-Object { $_.CommandLine -like '*dev-edit-bridge.ps1*' })) { & "$PSScriptRoot/dev-edit-bridge.ps1" -Detached }
else { Write-Output 'Bridge already running.' }
if (!($running | Where-Object { $_.CommandLine -like '*claude-responder.ps1*' })) { & "$PSScriptRoot/claude-responder.ps1" -Detached }
else { Write-Output 'Responder already running.' }
