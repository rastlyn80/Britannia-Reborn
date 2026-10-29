# Code fix previews: a converter change is seen in the world before it becomes
# a permanent code change.
#   -New      copies Viewer to work/code-previews/<Id>/Viewer (code and text
#             files copied, the ~9 GB of art hard-linked, so it is instant and
#             the main project is untouched); Claude edits the copy.
#   -Bake     bakes -Districts "x,y;x,y" with the copy's code into
#             outputs/<region>/previews/<Id>/<classic|modern>/ (the published
#             cache and its index are untouched).
#   -Publish  writes preview.json (-Title, -Description, -Examples
#             "x,y,z,label;...") that the F9 panel reads for "codepreview <Id>".
#   -Status   lists the files the fix changes.
#   -Accept   after the owner approves in game: copies the changed files into
#             the main project (refuses if a file changed there meanwhile).
#             Tests, commit and the real rebake follow.
#   -Discard  removes the copy and its preview bake.
# Never edit binary (hard-linked) files in the copy: they are the main ones.
param([Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{2,40}$')][string]$Id,
  [switch]$New,[switch]$Bake,[switch]$Publish,[switch]$Status,[switch]$Accept,[switch]$Discard,
  [string]$Districts,[string]$Title,[string]$Description,[string]$Examples,[string]$Region = 'britain',[switch]$Modern,[switch]$Classic)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$main = Join-Path $root 'Viewer'
$copyRoot = Join-Path $root "work/code-previews/$Id"
$copy = Join-Path $copyRoot 'Viewer'
$dataset = Join-Path $root "outputs/$Region"
$previews = Join-Path $dataset "previews/$Id"
$textTypes = '.gd','.gdshader','.gdshaderinc','.json','.tscn','.tres','.cfg','.godot','.import','.uid','.md','.txt','.csv'
function Relative($path, $base) { $path.Substring($base.Length + 1).Replace('\', '/') }
function TextFiles($base) {
  Get-ChildItem $base -Recurse -File -Force | Where-Object { $textTypes -contains $_.Extension.ToLower() -and $_.FullName -notmatch '[\\/]\.godot[\\/]' }
}

if ($New) {
  if (Test-Path $copyRoot) { throw "Preview $Id already exists (use -Discard first)" }
  Add-Type -Namespace Native -Name Link -MemberDefinition '[DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] public static extern bool CreateHardLink(string link,string target,IntPtr security);'
  $base = [ordered]@{}
  $linked = 0; $copied = 0
  foreach ($file in Get-ChildItem $main -Recurse -File -Force) {
    $rel = Relative $file.FullName $main
    $dest = Join-Path $copy $rel
    $dir = Split-Path $dest -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $inGodot = $rel.StartsWith('.godot/')
    $text = $textTypes -contains $file.Extension.ToLower()
    if (($inGodot -and $rel.StartsWith('.godot/imported/')) -or (!$inGodot -and !$text)) {
      if (![Native.Link]::CreateHardLink($dest, $file.FullName, [IntPtr]::Zero)) { throw "Hard link failed: $rel" }
      $linked++
    } else {
      [IO.File]::Copy($file.FullName, $dest)
      $copied++
      if (!$inGodot) { $base[$rel] = (Get-FileHash $file.FullName).Hash }
    }
  }
  $state = [ordered]@{ id = $Id; created = (Get-Date).ToString('s'); commit = (git -C $root rev-parse HEAD).Trim(); files = $base }
  [IO.File]::WriteAllText((Join-Path $copyRoot 'base.json'), ($state | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
  Write-Output "Preview copy ready: $copy ($copied files copied, $linked hard-linked). Edit code there, then -Bake."
}

if ($Bake) {
  if (!(Test-Path $copy)) { throw "No preview copy $Id (use -New)" }
  if (!$Districts) { throw '-Districts "x,y;x,y" is required' }
  $env:APPDATA = Join-Path $root '.godot-user'
  $env:LOCALAPPDATA = $env:APPDATA
  $godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
  $pending = Join-Path $previews 'pending'
  Remove-Item $pending -Recurse -Force -ErrorAction SilentlyContinue
  $mode = @()
  if ($Modern) { $mode = @('--modern-britain') } elseif ($Classic) { $mode = @('--classic-britain') }
  & $godot --headless --path $copy --script res://Presentation/BakeStreaming.gd -- "--dataset=$dataset" "--preview-output=$pending" "--districts=$Districts" @mode
  if ($LASTEXITCODE -or !(Test-Path (Join-Path $pending 'baked.json'))) { throw 'Preview bake failed' }
  $baked = Get-Content (Join-Path $pending 'baked.json') -Raw | ConvertFrom-Json
  $target = Join-Path $previews $baked.mode
  # Batches add up: districts baked earlier stay, rebaked ones are replaced.
  New-Item -ItemType Directory -Force $target | Out-Null
  $all = @{}
  $report = Join-Path $target 'baked.json'
  if (Test-Path $report) { foreach ($d in (Get-Content $report -Raw | ConvertFrom-Json).districts) { $all["$($d[0]),$($d[1])"] = @([int]$d[0], [int]$d[1]) } }
  foreach ($d in $baked.districts) { $all["$($d[0]),$($d[1])"] = @([int]$d[0], [int]$d[1]) }
  Get-ChildItem $pending -Filter *.res | Move-Item -Destination $target -Force
  $merged = [ordered]@{ districts = @($all.Values); mode = $baked.mode; seconds = $baked.seconds }
  [IO.File]::WriteAllText($report, ($merged | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
  Remove-Item $pending -Recurse -Force
  Write-Output ("Preview baked: {0} district(s) in this batch, {1} in total, {2} graphics, {3:N0} s -> {4}" -f @($baked.districts).Count, $all.Count, $baked.mode, $baked.seconds, $target)
}

if ($Publish) {
  $districtsSeen = @{}
  foreach ($mode in 'classic','modern') {
    $report = Join-Path $previews "$mode/baked.json"
    if (Test-Path $report) { foreach ($d in (Get-Content $report -Raw | ConvertFrom-Json).districts) { $districtsSeen["$($d[0]),$($d[1])"] = @([int]$d[0], [int]$d[1]) } }
  }
  if ($districtsSeen.Count -eq 0) { throw 'Nothing baked yet (use -Bake)' }
  $list = @()
  if ($Examples) {
    foreach ($e in $Examples.Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
      $f = $e.Split(',', 4)
      $list += [ordered]@{ x = [int]$f[0]; y = [int]$f[1]; z = [int]$f[2]; label = $(if ($f.Count -gt 3) { $f[3] } else { '' }) }
    }
  }
  $manifest = [ordered]@{ id = $Id; title = $Title; description = $Description; districts = @($districtsSeen.Values | Sort-Object { $_[0] }, { $_[1] } | ForEach-Object { ,[int[]]@($_[0], $_[1]) }); examples = $list; created = (Get-Date).ToString('s') }
  [IO.File]::WriteAllText((Join-Path $previews 'preview.json'), ($manifest | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
  Write-Output "Published preview $Id; propose it in game with: codepreview $Id"
}

function Changes {
  $state = Get-Content (Join-Path $copyRoot 'base.json') -Raw | ConvertFrom-Json
  $base = @{}
  foreach ($p in $state.files.PSObject.Properties) { $base[$p.Name] = $p.Value }
  $out = @()
  foreach ($file in TextFiles $copy) {
    $rel = Relative $file.FullName $copy
    $hash = (Get-FileHash $file.FullName).Hash
    if (!$base.ContainsKey($rel)) { $out += [pscustomobject]@{ path = $rel; change = 'added'; base = $null } }
    elseif ($base[$rel] -ne $hash) { $out += [pscustomobject]@{ path = $rel; change = 'modified'; base = $base[$rel] } }
  }
  $out
}

if ($Status) {
  $changes = @(Changes)
  if ($changes.Count -eq 0) { Write-Output 'No code changes in this preview yet.' }
  foreach ($c in $changes) { Write-Output "$($c.change): Viewer/$($c.path)" }
}

if ($Accept) {
  $changes = @(Changes)
  if ($changes.Count -eq 0) { throw 'The preview changes no files' }
  foreach ($c in $changes) {
    $target = Join-Path $main $c.path
    if ($c.change -eq 'modified' -and (Get-FileHash $target).Hash -ne $c.base) { throw "Viewer/$($c.path) changed in the main project since the preview was made; merge by hand" }
    if ($c.change -eq 'added' -and (Test-Path $target)) { throw "Viewer/$($c.path) now exists in the main project; merge by hand" }
  }
  foreach ($c in $changes) {
    $target = Join-Path $main $c.path
    New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
    Copy-Item (Join-Path $copy $c.path) $target -Force
    Write-Output "applied: Viewer/$($c.path)"
  }
  Write-Output 'Next: run the tests, commit, and rebake (Launch.cmd or scripts/prepare-streaming.ps1); then -Discard.'
}

if ($Discard) {
  # Removing hard links never touches the main project's files.
  if (Test-Path $copyRoot) { Remove-Item $copyRoot -Recurse -Force }
  if (Test-Path $previews) { Remove-Item $previews -Recurse -Force }
  Write-Output "Discarded preview $Id"
}
