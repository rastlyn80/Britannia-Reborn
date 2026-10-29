# Rolls committed developer edits back and rebakes only the districts that
# change. Without -To the committed overrides are removed (original converted
# world); -To <history file name> restores that earlier commit. Every commit
# leaves a copy in outputs/<region>/overrides/history/. -List shows them.
param([string]$Region = 'britain',[string]$To,[switch]$List,[switch]$Modern,[switch]$Classic)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$folder = Join-Path $root "outputs/$Region/overrides"
$committed = Join-Path $folder 'committed.overrides.json'
if ($List) { Get-ChildItem (Join-Path $folder 'history') -Filter *.overrides.json | Sort-Object Name | ForEach-Object { $_.Name }; return }
if ($To) {
  $source = Join-Path (Join-Path $folder 'history') $To
  if (!(Test-Path -LiteralPath $source)) { throw "No such commit: $To (use -List)" }
  Copy-Item -LiteralPath $source -Destination $committed -Force
  Write-Output "Restored committed overrides from $To"
} elseif (Test-Path -LiteralPath $committed) {
  Move-Item -LiteralPath $committed -Destination (Join-Path (Join-Path $folder 'history') ("reverted-" + (Get-Date -Format 'yyyyMMddTHHmmss') + '.overrides.json')) -Force
  Write-Output 'Committed overrides removed (kept in history).'
}
# Hashtable splatting passes switches as switches (an array would pass text).
$mode = @{}
if ($Modern) { $mode.Modern = $true } elseif ($Classic) { $mode.Classic = $true }
& "$PSScriptRoot/prepare-streaming.ps1" -Dataset (Join-Path $root "outputs/$Region") @mode
