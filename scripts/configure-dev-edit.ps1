# Enables the developer edit session in the local (ignored) server configuration
# and names exactly which accounts may edit. Defaults to the two local
# development accounts used by the tests (credentials.local.json user and user2);
# the user's own play account is never added implicitly. Restart the server
# gracefully afterwards. -Disable turns the session off again.
param([string[]]$Accounts,[string]$Session='britain-dev',[switch]$Disable)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $root 'Server/runtime'
if (!$Accounts) {
  $credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
  $Accounts = @($credentials.username, "$($credentials.username)2")
}
if ($Session -notmatch '^[a-z0-9-]{1,32}$') { throw 'Session names use 1-32 characters a-z, 0-9 or -' }
$configuration = Get-Content "$runtime/Configuration/modernuo.json" -Raw | ConvertFrom-Json
$configuration.settings | Add-Member -NotePropertyName 'ultimaClone.devEdit' -NotePropertyValue ($(if ($Disable) { 'False' } else { 'True' })) -Force
$configuration.settings | Add-Member -NotePropertyName 'ultimaClone.devEdit.accounts' -NotePropertyValue ($Accounts -join ',') -Force
$configuration.settings | Add-Member -NotePropertyName 'ultimaClone.devEdit.session' -NotePropertyValue $Session -Force
$configuration | ConvertTo-Json -Depth 12 | Set-Content "$runtime/Configuration/modernuo.json"
Write-Output "Developer edit session '$Session' $(if ($Disable) { 'disabled' } else { "enabled for $($Accounts.Count) account(s)" }). Restart the server gracefully to apply."
