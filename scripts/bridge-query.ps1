# Runs one bridge command (e.g. "inspect 1602 1591 4", "status", "asks") and
# prints the bridge's JSON reply: the automatic responder's eyes on the world.
# Only read-only commands are accepted here; changes go through proposals.
param([Parameter(Mandatory)][string]$Command, [int]$Seconds = 20)
$ErrorActionPreference = 'Stop'
$verb = ($Command.Trim() -split '\s+')[0].ToLowerInvariant()
if ($verb -notin 'inspect', 'status', 'list', 'asks', 'interpret') { throw "Read-only bridge commands only: inspect, status, list, asks, interpret" }
$folder = Join-Path (Split-Path $PSScriptRoot -Parent) 'work/dev-edit-bridge'
$inbox = Join-Path $folder 'inbox.txt'
$outbox = Join-Path $folder 'outbox.jsonl'
$start = (Get-Item $outbox).Length
[IO.File]::AppendAllText($inbox, $Command.Trim() + "`n", (New-Object Text.UTF8Encoding $false))
$needle = '"command":' + (ConvertTo-Json $Command.Trim() -Compress)
$deadline = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 300
  $stream = [IO.File]::Open($outbox, 'Open', 'Read', 'ReadWrite')
  try {
    $stream.Position = $start
    $text = (New-Object IO.StreamReader($stream)).ReadToEnd()
  } finally { $stream.Dispose() }
  foreach ($line in $text -split "`n") { if ($line.Contains($needle)) { Write-Output $line.Trim(); exit 0 } }
}
throw "No reply from the bridge within $Seconds s (is scripts/dev-edit-bridge.ps1 running?)"
