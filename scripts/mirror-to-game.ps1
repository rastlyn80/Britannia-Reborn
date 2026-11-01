# Claude Code Stop hook: mirrors Claude's latest reply into the game, as an
# answer on the newest in-game ask, so the developer in the world sees where
# the work stands. Reads the hook JSON (transcript_path) on stdin; writes one
# "answer <id> <text>" line to the dev edit bridge inbox. Does nothing when
# the bridge has no ask yet. Answers hold at most 8 x 110 characters.
$ErrorActionPreference = 'Stop'
# The automatic responder posts its own answers.
if ($env:UC_RESPONDER -eq '1') { exit 0 }
$root = Split-Path $PSScriptRoot -Parent
$folder = Join-Path $root 'work/dev-edit-bridge'
$inbox = Join-Path $folder 'inbox.txt'
$outbox = Join-Path $folder 'outbox.jsonl'
if (!(Test-Path $inbox) -or !(Test-Path $outbox)) { exit 0 }
$hook = [Console]::In.ReadToEnd() | ConvertFrom-Json
if (!$hook.transcript_path -or !(Test-Path $hook.transcript_path)) { exit 0 }

# The last assistant message with text.
$text = ''
foreach ($line in [IO.File]::ReadAllLines($hook.transcript_path)) {
  if ($line -notmatch '"type":"assistant"') { continue }
  $entry = $line | ConvertFrom-Json
  $parts = @($entry.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text })
  if ($parts.Count) { $text = $parts -join ' ' }
}
if (!$text.Trim()) { exit 0 }

# The newest in-game ask the bridge reported.
$id = 0
$status = ''
foreach ($line in [IO.File]::ReadAllLines($outbox)) {
  if ($line -match '"event":"conversation".*"id":(\d+)') {
    $id = [int]$Matches[1]
    $status = if ($line -match '"status":"([a-z]+)"') { $Matches[1] } else { '' }
  }
}
# A closed ask (accepted or cancelled) gets no more mirrored replies.
if ($id -le 0 -or $status -in 'applied','declined') { exit 0 }

# Plain one-line text: no markdown, tables, code ticks or line breaks.
$plain = $text -replace '```[\s\S]*?```', ' ' -replace '[*`#|]', '' -replace '\[([^\]]+)\]\([^)]+\)', '$1' -replace '\s+', ' '
$plain = $plain.Trim()
$limit = 8 * 110 - 40
if ($plain.Length -gt $limit) { $plain = $plain.Substring(0, $limit).TrimEnd() + '... (full reply in Claude Code)' }
[IO.File]::AppendAllText($inbox, "answer $id [Claude Code] $plain`n", (New-Object Text.UTF8Encoding $false))
