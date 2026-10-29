# Publishes one committed world edit (a change file written by the in-game
# Commit) to Git: a branch world-edits/<id> on top of origin/main adding
# Viewer/DevEdit/overrides/<id>.overrides.json, plus a pull request when a
# GitHub credential is available (otherwise the compare link to open one).
# Only client-side edits go here (statics, placed objects, terrain, rules);
# the ModernUO session journal stays with the server. The working tree, index
# and current branch are not touched, so it is safe while other work is open.
# Writes <change>.publish.json with the outcome; -DryRun builds the commit
# without pushing.
param([Parameter(Mandatory)][string]$Change,[switch]$DryRun)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$result = [ordered]@{ change = $Change }
function Finish($code) {
  # No byte-order mark: the game parses this file.
  [IO.File]::WriteAllText("$Change.publish.json",($result | ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding $false))
  $result | ConvertTo-Json -Depth 4
  exit $code
}
function Invoke-Git { $out = & git -C $root @args 2>&1; if ($LASTEXITCODE) { throw "git $($args -join ' '): $out" }; $out }
$tempIndex = Join-Path ([IO.Path]::GetTempPath()) ("world-edit-" + [guid]::NewGuid() + '.index')
try {
  $data = Get-Content -LiteralPath $Change -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($data.format -ne 'britannia-reborn-overrides' -or !$data.id) { throw 'Not a world edit change file' }
  $id = [string]$data.id
  if ($id -notmatch '^[0-9TZ]+-[a-z0-9._-]+$') { throw "Unexpected change id: $id" }
  $count = { param($o) if ($o) { @($o.PSObject.Properties).Count } else { 0 } }
  $summary = '{0} static(s), {1} placed, {2} terrain sample(s), {3} rule(s)' -f (& $count $data.statics),(& $count $data.placed),(& $count $data.terrain),@($data.rules).Count
  $authors = @()
  foreach ($group in @($data.statics,$data.placed,$data.terrain)) { if ($group) { foreach ($p in $group.PSObject.Properties) { $authors += [string]@($p.Value)[-1] } } }
  foreach ($rule in @($data.rules)) { if ($rule) { $authors += [string]$rule.author } }
  $authors = @($authors | Where-Object { $_ } | Sort-Object -Unique)
  $branch = "world-edits/$id"
  $path = "Viewer/DevEdit/overrides/$id.overrides.json"
  Invoke-Git fetch --quiet origin main | Out-Null
  $base = (Invoke-Git rev-parse origin/main).Trim()
  $env:GIT_INDEX_FILE = $tempIndex
  Invoke-Git read-tree $base | Out-Null
  $blob = (Invoke-Git hash-object -w -- $Change).Trim()
  Invoke-Git update-index --add --cacheinfo "100644,$blob,$path" | Out-Null
  $tree = (Invoke-Git write-tree).Trim()
  Remove-Item Env:GIT_INDEX_FILE
  $message = "World edit $id by $($authors -join ', '): $summary`n`nCommitted in game (developer edit mode). Client presentation only:`ncollision and gameplay stay as ModernUO has them.`n"
  $messageFile = "$tempIndex.msg"
  [IO.File]::WriteAllText($messageFile,$message,(New-Object Text.UTF8Encoding $false))
  $commit = (Invoke-Git commit-tree $tree -p $base -F $messageFile).Trim()
  $result.branch = $branch; $result.commit = $commit; $result.file = $path; $result.summary = $summary
  if ($DryRun) { $result.dryRun = $true; Finish 0 }
  $env:GIT_TERMINAL_PROMPT = '0'; $env:GCM_INTERACTIVE = 'never'
  Invoke-Git push --quiet origin "${commit}:refs/heads/$branch" | Out-Null
  $remote = (Invoke-Git remote get-url origin).Trim()
  if ($remote -notmatch 'github\.com[/:]([^/]+)/([^/]+?)(\.git)?$') { $result.note = 'pushed; origin is not GitHub, open a pull request there'; Finish 0 }
  $repo = "$($Matches[1])/$($Matches[2])"
  $result.compare = "https://github.com/$repo/compare/main...$($branch)?expand=1"
  # A pull request through the GitHub API with the credential git already uses.
  $token = $null
  $fill = "protocol=https`nhost=github.com`n`n" | & git credential fill 2>$null
  foreach ($line in $fill) { if ($line -like 'password=*') { $token = $line.Substring(9) } }
  if (!$token) { $result.note = 'pushed; no GitHub credential for the API, open the compare link'; Finish 0 }
  $body = @{ title = "World edit by $($authors -join ', '): $summary"; head = $branch; base = 'main'
    body = "Committed in game with the developer edit mode (``$path``).`n`n- $summary`n- Authors: $($authors -join ', ')`n`nClient presentation only: collision and gameplay stay as ModernUO has them. Merge to give every collaborator these edits; their next launch rebakes only the districts they touch." } | ConvertTo-Json
  try {
    $pr = Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/$repo/pulls" -Headers @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'britannia-reborn-world-edit' } -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json'
    $result.pr = $pr.html_url
  } catch { $result.note = "pushed; pull request not created ($($_.Exception.Message)), open the compare link" }
  $token = $null
  Finish 0
} catch {
  $result.error = $_.Exception.Message
  Finish 1
} finally {
  Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $tempIndex,"$tempIndex.msg" -ErrorAction SilentlyContinue
}
