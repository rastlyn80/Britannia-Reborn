param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$pins=Get-Content "$root/scripts/human-motion-inputs.json" -Raw | ConvertFrom-Json
$destination=Join-Path $root 'work/human-motion'
New-Item -ItemType Directory -Force $destination | Out-Null
$archive=Join-Path $destination 'ual2.zip'
if (!$VerifyOnly) {
  if (!(Test-Path $archive)) {
    $source=$pins.source
    $page=Invoke-WebRequest "$source/purchase" -SessionVariable animationSession
    $token=[regex]::Match($page.Content,'name="csrf_token" value="([^"]+)"').Groups[1].Value
    if (!$token) { throw 'Missing publisher request token' }
    $link=Invoke-RestMethod "$source/download_url" -Method Post -WebSession $animationSession -Body @{csrf_token=$token}
    $download=Invoke-WebRequest $link.url -WebSession $animationSession
    if ($download.Content -notmatch ('data-upload_id="'+$pins.upload_id+'"')) { throw 'Pinned free publisher edition unavailable' }
    $token=[regex]::Match($download.Content,'name="csrf_token" value="([^"]+)"').Groups[1].Value
    $file=Invoke-RestMethod "$source/file/$($pins.upload_id)" -Method Post -WebSession $animationSession -Body @{csrf_token=$token}
    Invoke-WebRequest $file.url -OutFile "$archive.partial"
    if ((Get-FileHash -LiteralPath "$archive.partial").Hash.ToLowerInvariant() -ne $pins.archive_sha256) { throw 'Changed free animation archive; review before importing' }
    Move-Item -LiteralPath "$archive.partial" -Destination $archive
  }
  if ((Get-FileHash -LiteralPath $archive).Hash.ToLowerInvariant() -ne $pins.archive_sha256) { throw 'Changed animation archive' }
  Expand-Archive -LiteralPath $archive -DestinationPath "$destination/ual2" -Force
  $rm=@($pins.files.PSObject.Properties.Name | Where-Object { $_ -like '*UAL1_Standard_RM.glb' })[0]
  if (!(Test-Path -LiteralPath "$root/$rm")) { & "$root/scripts/fetch-art.ps1" -Packs @('universal-animation-library') }
}
foreach ($file in $pins.files.PSObject.Properties) {
  if ((Get-FileHash -LiteralPath "$root/$($file.Name)").Hash.ToLowerInvariant() -ne $file.Value) { throw "Changed animation input $($file.Name)" }
}
Push-Location $root
try {
  if (!$VerifyOnly) {
    $blender=(Get-ChildItem "$root/.tools/blender/*/blender.exe" | Select-Object -First 1).FullName
    & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-motion.py
    if ($LASTEXITCODE) { throw 'Male motion preparation failed' }
    & $blender --background --factory-startup --python-exit-code 1 --python scripts/prepare-human-motion.py -- --female
    if ($LASTEXITCODE) { throw 'Female motion preparation failed' }
  }
  & python -B -X utf8 scripts/validate-human-motion.py
  if ($LASTEXITCODE) { throw 'Prepared motion validation failed' }
  $blender=(Get-ChildItem "$root/.tools/blender/*/blender.exe" | Select-Object -First 1).FullName
  & $blender --background --factory-startup --python-exit-code 1 --python scripts/validate-expanded-skirts.py -- --motion
  if ($LASTEXITCODE) { throw 'Prepared garment-motion validation failed' }
} finally { Pop-Location }
