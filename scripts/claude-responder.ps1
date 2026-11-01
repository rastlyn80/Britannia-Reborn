# Automatic responder: answers in-game asks without an open Claude Code
# window. It watches the dev edit bridge's outbox; for each new ask from a
# developer it runs Claude Code headless (claude -p, the owner's account) with
# scripts/claude-responder.md, the recent conversation, where the asker stands
# and their screenshot, then posts the ANSWER and PROPOSE lines back through
# the bridge inbox (a proposal is applied by the asker's own client, with
# Undo). HANDOVER lines go to work/dev-edit-bridge/handover.md for a full
# session. While an interactive session watches (interactive.heartbeat newer
# than 3 minutes) it stays out of the way. Create responder.stop to end it.
# Code changes (owner request, 1 November 2026): a CODE line from the owner's
# ask starts a second Claude run with editing tools in a sandbox copy of the
# client (scripts/code-preview.ps1 -New, checked by scripts/bridge-check.ps1).
# Nothing reaches the game until the owner types "apply N" in the chat; then
# the changed files are copied into Viewer/ (the previous ones kept for
# "undo N") and the client must be restarted. "discard N" drops a job. Owner
# characters are listed in work/dev-edit-bridge/owners.txt.
#   scripts/claude-responder.ps1 [-Detached]
param([switch]$Detached, [int]$TimeoutSeconds = 240, [int]$CodeTimeoutSeconds = 1200)
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
$codeTemplate = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'claude-responder-code.md'))
$ownersFile = Join-Path $folder 'owners.txt'
if (!(Test-Path $ownersFile)) { [IO.File]::WriteAllText($ownersFile, "Rastlyn`n", (New-Object Text.UTF8Encoding $false)) }
$owners = @(Get-Content $ownersFile | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$jobsFile = Join-Path $folder 'code-jobs.json'
$undoRoot = Join-Path $folder 'undo'
$viewer = Join-Path $root 'Viewer'
$claude = (Get-Command claude -ErrorAction Stop).Source
$utf8 = New-Object Text.UTF8Encoding $false
Remove-Item $stop -ErrorAction SilentlyContinue
function Log($text) { [IO.File]::AppendAllText($log, "$((Get-Date).ToString('s')) $text`n", $utf8) }
function Send($line) { [IO.File]::AppendAllText($inbox, $line + "`n", $utf8) }
function Jobs { if (Test-Path $jobsFile) { $map = @{}; (Get-Content $jobsFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $map[$_.Name] = $_.Value }; $map } else { @{} } }
function SaveJobs($map) { [IO.File]::WriteAllText($jobsFile, ($map | ConvertTo-Json -Depth 6), $utf8) }
function Preview([string[]]$arguments) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'code-preview.ps1') @arguments 2>&1 | ForEach-Object { "$_" } }
function Changed($name) { @(Preview @('-Id', $name, '-Status') | Where-Object { $_ -match '^(added|modified): Viewer/' } | ForEach-Object { $_ }) }

# One unattended Claude run with the given prompt, tools and folder; returns its text.
function RunClaude($prompt, $tools, $directory, $seconds) {
  $info = New-Object Diagnostics.ProcessStartInfo
  $info.FileName = $claude
  $info.Arguments = "-p --output-format text --allowedTools `"$tools`""
  $info.WorkingDirectory = $directory
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
  if (!$run.WaitForExit($seconds * 1000)) { $run.Kill(); return $null }
  return $reading.Result
}

# A client code change in a sandbox copy; offered to the owner, not applied.
function CodeJob($id, $job, $ask, $where) {
  $name = "bridge-ask-$id"
  if (Test-Path (Join-Path $root "work/code-previews/$name")) { Preview @('-Id', $name, '-Discard') | Out-Null }
  Preview @('-Id', $name, '-New') | Out-Null
  $copyRoot = Join-Path $root "work/code-previews/$name"
  if (!(Test-Path (Join-Path $copyRoot 'Viewer'))) { Send "answer $id Sorry, I could not prepare a sandbox copy of the code."; Log "ask $id code: no sandbox"; return }
  Send "answer $id Working on it in a sandbox copy of the client code. This can take a few minutes; nothing changes in your game until you say apply $id."
  Log "ask $id code job: $job"
  $prompt = "$codeTemplate`n`nCopy id: $name`n$($ask.author) is $where and said: $($ask.text)`nThe job: $job"
  $tools = "Read Edit Write Grep Glob Bash(powershell -NoProfile -ExecutionPolicy Bypass -File ../../../scripts/bridge-check.ps1:*)"
  $reply = RunClaude $prompt $tools $copyRoot $CodeTimeoutSeconds
  if ($null -eq $reply) {
    Preview @('-Id', $name, '-Discard') | Out-Null
    Send "answer $id Sorry, that change took too long to make here; I have added it to the list for a full session."
    [IO.File]::AppendAllText($handover, "- $((Get-Date).ToString('s')) ask $id ($($ask.author) $where): code job timed out: $job`n", $utf8)
    Log "ask $id code job timed out"
    return
  }
  $summary = (@($reply -split "`r?`n" | Where-Object { $_ -match '^\s*SUMMARY:' } | ForEach-Object { ($_ -replace '^\s*SUMMARY:\s*', '').Trim() }) -join ' ')
  if (!$summary) { $summary = (($reply -replace '\s+', ' ').Trim()) }
  if ($summary.Length -gt 600) { $summary = $summary.Substring(0, 597) + '...' }
  $files = @(Changed $name)
  if ($files.Count -eq 0) {
    Preview @('-Id', $name, '-Discard') | Out-Null
    Send "answer $id I did not change anything: $summary"
    Log "ask $id code job: no change"
    return
  }
  $check = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'bridge-check.ps1') $name 2>&1 | Out-String
  if ($check -notmatch 'CHECK PASS') {
    Preview @('-Id', $name, '-Discard') | Out-Null
    Send "answer $id My change did not pass the code check, so I dropped it and added it to the list for a full session."
    [IO.File]::AppendAllText($handover, "- $((Get-Date).ToString('s')) ask $id ($($ask.author) $where): code job failed its check: $job`n", $utf8)
    Log "ask $id code job failed check"
    return
  }
  $list = ($files | ForEach-Object { ($_ -replace '^(added|modified): Viewer/', '') }) -join ', '
  $map = Jobs
  $map["$id"] = [ordered]@{ name = $name; job = $job; summary = $summary; files = $files; state = 'ready'; author = $ask.author }
  SaveJobs $map
  Send "answer $id Ready: $summary Changed: $list. Say apply $id to put it in your game (then restart the client), or discard $id."
  Log "ask $id code job ready: $list"
}

# The owner's answer to a code job: apply, discard or undo.
function CodeCommand($id, $verb, $number) {
  $map = Jobs
  $entry = $map["$number"]
  if ($null -eq $entry) { Send "answer $id There is no code change number $number."; return }
  $name = $entry.name
  switch ($verb) {
    'discard' {
      if ($entry.state -eq 'ready') { Preview @('-Id', $name, '-Discard') | Out-Null }
      $entry.state = 'discarded'
      Send "answer $id Dropped code change $number; nothing in your game changed."
    }
    'apply' {
      if ($entry.state -ne 'ready') { Send "answer $id Code change $number is $($entry.state), not waiting to be applied."; return }
      $undo = Join-Path $undoRoot "$number"
      New-Item -ItemType Directory -Force $undo | Out-Null
      $applied = @{}
      foreach ($line in @(Changed $name)) {
        $rel = $line -replace '^(added|modified): Viewer/', ''
        $target = Join-Path $viewer $rel
        if (Test-Path $target) { New-Item -ItemType Directory -Force (Split-Path (Join-Path $undo $rel) -Parent) | Out-Null; Copy-Item $target (Join-Path $undo $rel) -Force }
        $applied[$rel] = if ($line.StartsWith('added')) { 'added' } else { 'modified' }
      }
      $result = Preview @('-Id', $name, '-Accept') | Out-String
      if ($result -notmatch 'applied:') { Send "answer $id I could not apply it: a file it changes was edited meanwhile. A full session can merge it."; Log "ask $id apply $number refused: $result"; return }
      $hashes = @{}
      foreach ($rel in $applied.Keys) { $hashes[$rel] = (Get-FileHash (Join-Path $viewer $rel)).Hash }
      $entry.state = 'applied'
      $entry | Add-Member -NotePropertyName applied -NotePropertyValue $applied -Force
      $entry | Add-Member -NotePropertyName hashes -NotePropertyValue $hashes -Force
      Preview @('-Id', $name, '-Discard') | Out-Null
      [IO.File]::AppendAllText($handover, "- $((Get-Date).ToString('s')) applied bridge code change $number ($($entry.summary)) to $($applied.Keys -join ', '): run scripts/verify.ps1 and commit`n", $utf8)
      Send "answer $id Applied code change $number. Restart the client (close it and run Launch.cmd) to use it. Say undo $number to take it back."
    }
    'undo' {
      if ($entry.state -ne 'applied') { Send "answer $id Code change $number is not applied."; return }
      $undo = Join-Path $undoRoot "$number"
      $kept = @()
      foreach ($p in $entry.applied.PSObject.Properties) {
        $target = Join-Path $viewer $p.Name
        if ((Test-Path $target) -and (Get-FileHash $target).Hash -ne $entry.hashes.($p.Name)) { $kept += $p.Name; continue }
        if ($p.Value -eq 'added') { Remove-Item $target -ErrorAction SilentlyContinue }
        else { Copy-Item (Join-Path $undo $p.Name) $target -Force }
      }
      $entry.state = 'undone'
      Send "answer $id Took back code change $number$(if ($kept) { "; except $($kept -join ', '), which changed since" }). Restart the client to see the previous behaviour."
    }
  }
  $map["$number"] = $entry
  SaveJobs $map
  Log "ask $id $verb $number"
}

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
    if ($ask.text -match '^\s*(apply|discard|undo)\s+(\d+)\s*\.?\s*$') {
      if ($owners -contains $ask.author) { CodeCommand $id $Matches[1].ToLowerInvariant() ([int]$Matches[2]) }
      else { Send "answer $id Only the owner can apply or undo code changes." }
      continue
    }
    Start-Sleep -Milliseconds 700  # let the screenshot finish writing
    $history = @()
    foreach ($other in @($asks.Keys | Where-Object { $_ -lt $id } | Sort-Object | Select-Object -Last 6)) {
      $o = $asks[$other]
      $history += "- $($o.author): $($o.text)"
      foreach ($a in $o.answers) { if ($a -notmatch "Got it, I'm on it") { $history += "  $a" } }
    }
    $where = if ($hasAt) { "at $($ask.at.x), $($ask.at.y), Z $($ask.at.z) on $($ask.at.map), facing $($ask.at.facing) (0 north, 2 east, 4 south, 6 west)" } else { 'position unknown' }
    $shot = if ($ask.shot -and (Test-Path $ask.shot)) { "Their screenshot: $($ask.shot)" } else { 'No screenshot.' }
    $prompt = "$template`n`nThe owner's characters: $($owners -join ', ').`n`nRecent conversation:`n$(if ($history) { $history -join "`n" } else { '(none)' })`n`nNow $($ask.author) is $where.`n$shot`nThey say: $($ask.text)"
    $promptFile = Join-Path $folder 'responder-prompt.txt'
    [IO.File]::WriteAllText($promptFile, $prompt, $utf8)
    Log "ask $id from $($ask.author): $($ask.text)"
    $reply = RunClaude $prompt "Read Grep Glob Bash(powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bridge-query.ps1:*)" $root $TimeoutSeconds
    if ($null -eq $reply) {
      Send "answer $id Sorry, that took too long for me to work out here. A full Claude Code session can take it on."
      Log "ask $id timed out"
      continue
    }
    $answers = @(); $proposal = ''; $jobs = @(); $code = ''
    foreach ($line in $reply -split "`r?`n") {
      if ($line -match '^\s*ANSWER:\s*(.+)$') { $answers += $Matches[1].Trim() }
      elseif ($line -match '^\s*PROPOSE:\s*(.+)$' -and !$proposal) { $proposal = $Matches[1].Trim() }
      elseif ($line -match '^\s*HANDOVER:\s*(.+)$') { $jobs += $Matches[1].Trim() }
      elseif ($line -match '^\s*CODE:\s*(.+)$' -and !$code) { $code = $Matches[1].Trim() }
    }
    if ($answers.Count -eq 0 -and $reply.Trim()) { $answers = @(($reply -replace '\s+', ' ').Trim()) }
    $said = ($answers -join ' ') -replace '\s+', ' '
    if ($said.Length -gt 860) { $said = $said.Substring(0, 857) + '...' }
    if ($said) { Send "answer $id $said" }
    if ($proposal) { Send "propose $id $proposal" }
    foreach ($job in $jobs) { [IO.File]::AppendAllText($handover, "- $((Get-Date).ToString('s')) ask $id ($($ask.author) $where): $job`n", $utf8) }
    Log "ask $id answered$(if ($proposal) { "; proposed $proposal" })$(if ($jobs) { "; handover: $($jobs -join ' | ')" })"
    if ($code) {
      if ($owners -contains $ask.author) { CodeJob $id $code $ask $where }
      else { [IO.File]::AppendAllText($handover, "- $((Get-Date).ToString('s')) ask $id ($($ask.author) $where): $code`n", $utf8) }
    }
  }
}
Log 'responder stopped'
