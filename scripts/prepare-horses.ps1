param([switch]$VerifyOnly,[string]$Archive='')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$pins=Get-Content "$root/scripts/horse-inputs.json" -Raw|ConvertFrom-Json
$work=Join-Path $root 'work/horse-session'
$art=Join-Path $root 'Viewer/local-art/horses'
New-Item -ItemType Directory -Force $work,$art|Out-Null
if (!$Archive) { $Archive=Join-Path $work $pins.archive_name }
if (!$VerifyOnly) {
 if (!(Test-Path -LiteralPath $Archive)) {
  try {
   $source=$pins.publisher
   $page=Invoke-WebRequest "$source/purchase" -SessionVariable horseSession
   $token=[regex]::Match($page.Content,'name="csrf_token" value="([^"]+)"').Groups[1].Value
   if (!$token) { throw 'Publisher request token unavailable' }
   $link=Invoke-RestMethod "$source/download_url" -Method Post -WebSession $horseSession -Body @{csrf_token=$token}
   $download=Invoke-WebRequest $link.url -WebSession $horseSession
   if ($download.Content -notmatch ('data-upload_id="'+$pins.upload_id+'"')) { throw 'Pinned free horse unavailable' }
   $token=[regex]::Match($download.Content,'name="csrf_token" value="([^"]+)"').Groups[1].Value
   $file=Invoke-RestMethod "$source/file/$($pins.upload_id)" -Method Post -WebSession $horseSession -Body @{csrf_token=$token}
   Invoke-WebRequest $file.url -OutFile "$Archive.partial"
   if ((Get-FileHash -LiteralPath "$Archive.partial").Hash.ToLowerInvariant() -ne $pins.archive_sha256) { throw 'Changed archive; review the publisher update before use' }
   Move-Item -LiteralPath "$Archive.partial" -Destination $Archive
  } catch { throw "Publisher download unavailable. Use its free download page, then run -Archive PATH_TO_ZIP. No purchase is needed. $($_.Exception.Message)" }
 }
 if ((Get-FileHash -LiteralPath $Archive).Hash.ToLowerInvariant() -ne $pins.archive_sha256) { throw 'Unexpected horse archive version' }
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
 try {
  $names=@{'Warhorse_Lite/Warhorse_Lite.glb'='warhorse.glb';'Warhorse_Lite/LICENSE.txt'='LICENSE-Warhorse.txt';'Warhorse_Lite/README.md'='SOURCE-README.md'}
  foreach ($file in $pins.files.PSObject.Properties) {
   $entry=$zip.GetEntry($file.Name)
   if (!$entry -or $entry.Length -gt 64MB) { throw 'Missing or oversized pinned member' }
   # Only the three explicitly named static-data/text members are extracted.
   $target=Join-Path $art $names[$file.Name]
   [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$true)
   if ((Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -ne $file.Value) { throw "Changed horse member $($file.Name)" }
  }
 } finally { $zip.Dispose() }
 $blender=(Get-ChildItem "$root/.tools/blender/*/blender.exe"|Select-Object -First 1).FullName
 & $blender --background --factory-startup --python-exit-code 1 --python "$root/scripts/prepare-horse-regions.py"
 if ($LASTEXITCODE) { throw 'Horse coat/tack region preparation failed' }
 if (Test-Path "$root/Viewer/local-art/free-equipment-female/expansion/kilt.glb") {
  $blender=(Get-ChildItem "$root/.tools/blender/*/blender.exe"|Select-Object -First 1).FullName
  & $blender --background --factory-startup --python-exit-code 1 --python "$root/scripts/prepare-riding-clothes.py"
  if ($LASTEXITCODE) { throw 'Riding garment fitting failed' }
 }
}
Push-Location $root
try {
 & python -B scripts/validate-horses.py
 if ($LASTEXITCODE) { throw 'Horse source/rig checks failed' }
} finally { Pop-Location }
