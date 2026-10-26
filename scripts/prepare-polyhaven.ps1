param([switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$target = Join-Path $root 'Viewer/Art/PolyHaven'
$manifest = Get-Content "$target/manifest.json" -Raw | ConvertFrom-Json
$checked = 0
foreach ($asset in $manifest.assets) {
 foreach ($file in $asset.files) {
  $parts = $file.path -split '/'
  if ($parts -contains '..' -or [IO.Path]::IsPathRooted($file.path)) { throw 'Unsafe manifest path' }
  $path = Join-Path $target $file.path
  if (!(Test-Path -LiteralPath $path)) {
   if ($VerifyOnly) { throw "Missing Poly Haven file: $($file.path). Run scripts/prepare-polyhaven.ps1." }
   New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
   Invoke-WebRequest $file.url -Headers @{'User-Agent'='UltimaClone-local-world-viewer/0.1'} -OutFile $path
  }
  if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.sha256) { throw "Poly Haven checksum mismatch: $($file.path)" }
  $checked++
 }
}
Write-Output "Verified $($manifest.assets.Count) pinned CC0 Poly Haven models and $checked files."
