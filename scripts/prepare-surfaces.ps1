param([switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$target = Join-Path $root 'Viewer/Art/Surfaces'
$manifest = Get-Content "$target/manifest.json" -Raw | ConvertFrom-Json
$checked = 0
foreach ($set in $manifest.sets) {
 foreach ($map in $set.maps) {
  if ([IO.Path]::GetFileName($map.file) -ne $map.file) { throw 'Unsafe manifest path' }
  $path = Join-Path $target $map.file
  if (!(Test-Path -LiteralPath $path)) {
   if ($VerifyOnly) { throw "Missing surface: $($map.file). Run scripts/prepare-surfaces.ps1." }
   Invoke-WebRequest $map.url -Headers @{'User-Agent'='UltimaClone-local-world-viewer/0.1'} -OutFile $path
  }
  if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $map.sha256) { throw "Surface checksum mismatch: $($map.file)" }
  $checked++
 }
}
Write-Output "Verified $checked pinned CC0 surface maps."
