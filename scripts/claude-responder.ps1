# Automatic responder: answers in-game asks without an open Claude Code
# window. It watches the dev edit bridge's outbox; for each new ask from a
# developer it runs Claude Code headless (claude -p, the owner's account) with
# scripts/claude-responder.md, the recent conversation, where the asker stands
# and their screenshot, then posts the ANSWER and PROPOSE lines back through
# the bridge inbox (a proposal is applied by the asker's own client, with
# Undo). HANDOVER lines go to work/dev-edit-bridge/handover.md for a full
# session. While an interactive session watches (interactive.heartbeat newer
# than 3 minutes) it stays out of the way. Create responder.stop to end it.
#   scripts/claude-responder.ps1 [-Detached]
param([switch]$Detached, [int]$TimeoutSeconds = 240)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$folder = Join-Path $root 'work/dev-edit-bridge'
if ($Detached) {
  $process = Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"" -WindowStyle Hidden -PassThru
  Write-Output "Responder running detached (process $($process.Id)); stop it by creating $folder\responder.stop"
  return
}
$inbox = Join-Path $folder 'inbox.txt'
$outbox = Join-Path $folder 'outbox.jsonl'
$log = Join-Path $folder 'responder.log'
$stop = Join-Path $folder 'responder.stop'
$heartbeat = Join-Path $folder 'interactive.heartbeat'
$handover = Join-Path $folder 'handover.md'
$template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'claude-responder.md'))
$claude = (Get-Command claude -ErrorAction Stop).Source
$utf8 = New-Object Text.UTF8Encoding $false
Remove-Item $stop -ErrorAction SilentlyContinue
function Log($text) { [IO.File]::AppendAllText($log, "$((Get-Date).ToString('s')) $text`n", $utf8) }
function Send($line) { [IO.File]::AppendAllText($inbox, $line + "`n", $utf8) }

# Read only what the bridge appends from now on.
$offset = if (Test-Path $outbox) { (Get-Item $outbox).Length } else { 0 }
$asks = @{}      # id -> latest conversation event
$first = @{}     # id -> when its open event arrived
$done = @{}      # "id|text" -> handled
Log 'responder started'
while (!(Test-Path $stop)) {
  Start-Sleep -Milliseconds 800
  if (!(Test-Path $outbox)) { continue }
  $length = (Get-Item $outbox).Length
  if ($length -lt $offset) { $offset = 0 }
  if ($length -gt $offset) {
    $stream = [IO.File]::Open($outbox, 'Open', 'Read', 'ReadWrite')
    try {
      $stream.Position = $offset
      $text = (New-Object IO.StreamReader($stream, $utf8)).ReadToEnd()
    } finally { $stream.Dispose() }
    $complete = $text.LastIndexOf("`n")
    if ($complete -ge 0) {
      $offset += $utf8.GetByteCount($text.Substring(0, $complete + 1))
      foreach ($line in $text.Substring(0, $complete) -split "`n") {
        if ($line -notmatch '"event":"conversation"') { continue }
        try { $event = $line | ConvertFrom-Json } catch { continue }
        $asks[[int]$event.id] = $event
        if ($event.status -eq 'open' -and !$first.ContainsKey([int]$event.id)) { $first[[int]$event.id] = Get-Date }
      }
    }
  }
  # An interactive session is answering: leave the asks to it.
  if ((Test-Path $heartbeat) -and ((Get-Date) - (Get-Item $heartbeat).LastWriteTime).TotalMinutes -lt 3) { continue }
  foreach ($id in @($asks.Keys | Sort-Object)) {
    $ask = $asks[$id]
    $key = "$id|$($ask.text)"
    if ($done.ContainsKey($key) -or $ask.author -eq 'Claude' -or $ask.status -notin 'open', 'answered') { continue }
    if (!$first.ContainsKey($id)) { continue }
    # Only the bridge's instant acknowledgement so far, and the position (or 4 s).
    $real = @($ask.answers | Where-Object { $_ -notmatch "Got it, I'm on it" })
    if ($real.Count -gt 0) { $done[$key] = $true; continue }
    $hasAt = $ask.at -and $ask.at.PSObject.Properties.Count -gt 0
    if (!$hasAt -and ((Get-Date) - $first[$id]).TotalSeconds -lt 4) { continue }
    $done[$key] = $true
    Start-Sleep -Milliseconds 700  # let the screenshot finish writing
    $history = @()
    foreach ($other in @($asks.Keys | Where-Object { $_ -lt $id } | Sort-Object | Select-Object -Last 6)) {
      $o = $asks[$other]
      $history += "- $($o.author): $($o.text)"
      foreach ($a in $o.answers) { if ($a -notmatch "Got it, I'm on it") { $history += "  $a" } }
    }
    $where = if ($hasAt) { "at $($ask.at.x), $($ask.at.y), Z $($ask.at.z) on $($ask.at.map), facing $($ask.at.facing) (0 north, 2 east, 4 south, 6 west)" } else { 'position unknown' }
    $shot = if ($ask.shot -and (Test-Path $ask.shot)) { "Their screenshot: $($ask.shot)" } else { 'No screenshot.' }
    $prompt = "$template`n`nRecent conversation:`n$(if ($history) { $history -join "`n" } else { '(none)' })`n`nNow $($ask.author) is $where.`n$shot`nThey say: $($ask.text)"
    $promptFile = Join-Path $folder 'responder-prompt.txt'
    [IO.File]::WriteAllText($promptFile, $prompt, $utf8)
    Log "ask $id from $($ask.author): $($ask.text)"
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $claude
    $info.Arguments = '-p --output-format text --allowedTools "Read Grep Glob Bash(powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bridge-query.ps1:*)"'
    $info.WorkingDirectory = $root
    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = $utf8
    # The project's mirror hook (scripts/mirror-to-game.ps1) must not echo this run.
    $info.EnvironmentVariables['UC_RESPONDER'] = '1'
    $run = [Diagnostics.Process]::Start($info)
    $run.StandardInput.Write($prompt)
    $run.StandardInput.Close()
    $reading = $run.StandardOutput.ReadToEndAsync()
    if (!$run.WaitForExit($TimeoutSeconds * 1000)) {
      $run.Kill()
      Send "answer $id Sorry, that took too long for me to work out here. A full Claude Code session can take it on."
      Log "ask $id timed out"
      continue
    }
    $reply = $reading.Result
    $answers = @(); $proposal = ''; $jobs = @()
    foreach ($line in $reply -split "`r?`n") {
      if ($line -match '^\s*ANSWER:\s*(.+)$') { $answers += $Matches[1].Trim() }
      elseif ($line -match '^\s*PROPOSE:\s*(.+)$' -and !$proposal) { $proposal = $Matches[1].Trim() }
      elseif ($line -match '^\s*HANDOVER:\s*(.+)$') { $jobs += $Matches[1].Trim() }
    }
    if ($answers.Count -eq 0 -and $reply.Trim()) { $answers = @(($reply -replace '\s+', ' ').Trim()) }
    $said = ($answers -join ' ') -replace '\s+', ' '
    if ($said.Length -gt 860) { $said = $said.Substring(0, 857) + '...' }
    if ($said) { Send "answer $id $said" }
    if ($proposal) { Send "propose $id $proposal" }
    foreach ($job in $jobs) { [IO.File]::AppendAllText($handover, "- $((Get-Date).ToString('s')) ask $id ($($ask.author) $where): $job`n", $utf8) }
    Log "ask $id answered$(if ($proposal) { "; proposed $proposal" })$(if ($jobs) { "; handover: $($jobs -join ' | ')" })"
  }
}
Log 'responder stopped'
