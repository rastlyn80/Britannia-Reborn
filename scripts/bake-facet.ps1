# Bakes a whole converted facet (e.g. outputs/trammel from the converter's
# atlas command) into the compact streaming cache, out of core: the facet is
# split into windows of districts, each baked in its own Godot process with a
# one-district ring of context (joined walls and roofs meet across windows),
# several at a time; then --finalize writes the regional horizon and the
# index. Districts carry stamps, so an interrupted bake resumes where it
# stopped and a repeat bakes nothing. See docs/COMPACT_STREAMING.md.
#   scripts/bake-facet.ps1 -Dataset outputs/trammel -Modern
param(
  [string]$Dataset = 'outputs/trammel',
  [int]$WindowTiles = 512,
  [int]$Parallel = 4,
  [switch]$Modern,
  [switch]$Classic
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:APPDATA = Join-Path $root '.godot-user'
$env:LOCALAPPDATA = $env:APPDATA
$godot = (Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$data = (Resolve-Path (Join-Path $root $Dataset)).Path
$atlas = Get-Content (Join-Path $data 'atlas.json') -Raw | ConvertFrom-Json
# Mountain relief (docs/MOUNTAINS.md), recomputed when the conversion is newer.
$relief = Join-Path $data 'relief.u8'
if (!(Test-Path $relief) -or (Get-Item $relief).LastWriteTime -lt (Get-Item (Join-Path $data 'atlas.json')).LastWriteTime) {
  & "$root/.tools/dotnet/dotnet.exe" "$root/Converter/bin/Release/net8.0/Converter.dll" relief $data
  if ($LASTEXITCODE) { throw 'Mountain relief failed' }
}
$mode = @()
if ($Modern) { $mode = @('--modern-britain') } elseif ($Classic) { $mode = @('--classic-britain') }
$logs = Join-Path $data 'bake-logs'
New-Item -ItemType Directory -Force $logs | Out-Null
# An empty standard input: a script error then ends the process (headless
# Godot otherwise waits in its debugger for input forever).
$noInput = Join-Path $logs 'no-input.txt'
Set-Content -LiteralPath $noInput -Value '' -NoNewline
$windows = @()
for ($y = [int]$atlas.originY; $y -lt [int]$atlas.originY + [int]$atlas.height; $y += $WindowTiles) {
  for ($x = [int]$atlas.originX; $x -lt [int]$atlas.originX + [int]$atlas.width; $x += $WindowTiles) {
    $windows += ,@($x, $y, [Math]::Min($WindowTiles, [int]$atlas.originX + [int]$atlas.width - $x), [Math]::Min($WindowTiles, [int]$atlas.originY + [int]$atlas.height - $y))
  }
}
Write-Output "Baking $($windows.Count) windows of up to $WindowTiles tiles, $Parallel at a time."
$started = Get-Date
$running = @()
$failed = @()
$next = 0
while ($next -lt $windows.Count -or $running.Count -gt 0) {
  while ($running.Count -lt $Parallel -and $next -lt $windows.Count) {
    $w = $windows[$next]; $next++
    $tag = "$($w[0])_$($w[1])"
    # One quoted string: Start-Process does not quote list arguments, and the
    # project path contains a space.
    $arguments = "--headless --path `"$root/Viewer`" --script res://Presentation/BakeStreaming.gd -- `"--dataset=$data`" --window=$($w[0]),$($w[1]),$($w[2]),$($w[3]) $($mode -join ' ')"
    $process = Start-Process -FilePath $godot -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardInput $noInput -RedirectStandardOutput (Join-Path $logs "$tag.log") -RedirectStandardError (Join-Path $logs "$tag.err")
    $running += ,@($process, $tag)
  }
  Start-Sleep -Seconds 2
  $still = @()
  foreach ($entry in $running) {
    if ($entry[0].HasExited) {
      $entry[0].WaitForExit()
      if ($entry[0].ExitCode -ne 0) { $failed += $entry[1]; Write-Output "Window $($entry[1]) FAILED (exit $($entry[0].ExitCode)); see $logs" }
      else { Write-Output ("Window {0} done ({1}/{2}, {3:N0} min)" -f $entry[1], ($next - $running.Count + 1), $windows.Count, ((Get-Date) - $started).TotalMinutes) }
    } else { $still += ,$entry }
  }
  $running = $still
}
if ($failed.Count) { throw "$($failed.Count) window(s) failed: $($failed -join ', '). Rerun to resume." }
# Publishing plans nothing, so it has no district limit (FinalizeFacet.gd).
Get-Content -LiteralPath $noInput | & $godot --headless --path "$root/Viewer" --script res://Presentation/FinalizeFacet.gd -- "--dataset=$data" @mode
if ($LASTEXITCODE) { throw 'Finalize (index and horizon) failed' }
Write-Output ("Facet bake complete in {0:N0} min." -f ((Get-Date) - $started).TotalMinutes)
