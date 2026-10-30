param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$pins=Get-Content "$root/scripts/human-coverage-inputs.json" -Raw | ConvertFrom-Json
$destination=Join-Path $root 'work/human-coverage-session'
New-Item -ItemType Directory -Force $destination | Out-Null
$archive=Join-Path $destination 'kaykit-free1.1.zip'
if (!$VerifyOnly) {
 if (!(Test-Path -LiteralPath $archive)) {
  $source=$pins.publisher
  $page=Invoke-WebRequest "$source/purchase" -SessionVariable coverageSession
  $token=[regex]::Match($page.Content,'name="csrf_token" value="([^"]+)"').Groups[1].Value
  if (!$token) { throw 'Publisher request token unavailable' }
  $link=Invoke-RestMethod "$source/download_url" -Method Post -WebSession $coverageSession -Body @{csrf_token=$token}
  $download=Invoke-WebRequest $link.url -WebSession $coverageSession
  if ($download.Content -notmatch ('data-upload_id="'+$pins.upload_id+'"')) { throw 'Pinned free edition unavailable; do not substitute a paid tier' }
  $token=[regex]::Match($download.Content,'name="csrf_token" value="([^"]+)"').Groups[1].Value
  $file=Invoke-RestMethod "$source/file/$($pins.upload_id)" -Method Post -WebSession $coverageSession -Body @{csrf_token=$token}
  Invoke-WebRequest $file.url -OutFile "$archive.partial"
  if ((Get-FileHash -LiteralPath "$archive.partial").Hash.ToLowerInvariant() -ne $pins.archive_sha256) { throw 'Changed publisher archive; review before use' }
  Move-Item -LiteralPath "$archive.partial" -Destination $archive
 }
 if ((Get-FileHash -LiteralPath $archive).Hash.ToLowerInvariant() -ne $pins.archive_sha256) { throw 'Changed free archive' }
 # Static extraction only. Never run archive programs or import .blend scripts.
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=[IO.Compression.ZipFile]::OpenRead($archive)
 try {
  $extract=[IO.Path]::GetFullPath((Join-Path $destination 'kaykit'))
  foreach ($entry in $zip.Entries) {
   if ([IO.Path]::GetExtension($entry.FullName) -notin @('.glb','.gltf','.bin','.txt','.json')) { continue }
   $target=[IO.Path]::GetFullPath((Join-Path $extract $entry.FullName))
   if (!$target.StartsWith($extract+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe archive member' }
   New-Item -ItemType Directory -Force ([IO.Path]::GetDirectoryName($target)) | Out-Null
   [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$true)
  }
 } finally { $zip.Dispose() }
}
foreach ($file in $pins.animation_files.PSObject.Properties) {
 if ((Get-FileHash -LiteralPath "$root/$($file.Name)").Hash.ToLowerInvariant() -ne $file.Value) { throw "Changed motion input $($file.Name)" }
}
Push-Location $root
try {
 & python -B scripts/build-human-coverage-registry.py
 if ($LASTEXITCODE) { throw 'Category registry build failed' }
 if (!$VerifyOnly) {
  $blender=(Get-ChildItem "$root/.tools/blender/*/blender.exe"|Select-Object -First 1).FullName
  foreach ($sex in @('male','female')) {
   $argsForSex=@();if ($sex -eq 'female') { $argsForSex=@('--','--female') }
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-coverage-motion.py @argsForSex
   if ($LASTEXITCODE) { throw "$sex motion extension failed" }
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-coverage-gear.py @argsForSex
   if ($LASTEXITCODE) { throw "$sex equipment build failed" }
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-workwear.py @argsForSex
   if ($LASTEXITCODE) { throw "$sex workwear build failed" }
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-frontier.py @argsForSex
   if ($LASTEXITCODE) { throw "$sex frontier equipment build failed" }
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-wardrobe50.py @argsForSex
   if ($LASTEXITCODE) { throw "$sex 50-percent wardrobe build failed" }
   & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-wardrobe65.py @argsForSex
   if ($LASTEXITCODE) { throw "$sex 65-percent wardrobe build failed" }
  }
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-hand-masks.py
  if ($LASTEXITCODE) { throw 'Glove wrist masks failed' }
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-hair-layers.py
  if ($LASTEXITCODE) { throw 'Updated wardrobe hair fitting failed' }
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-coif-hair.py
  if ($LASTEXITCODE) { throw 'Coif hair layering failed' }
 }
 & python -B scripts/validate-human-coverage.py
 if ($LASTEXITCODE) { throw 'Coverage export validation failed' }
 & python -B scripts/validate-human-motion.py
 if ($LASTEXITCODE) { throw 'Human motion validation failed' }
} finally {Pop-Location}
