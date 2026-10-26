param([string[]]$Packs = @('medieval-village-megakit','stylized-nature-megakit','universal-base-characters','universal-animation-library','modular-character-outfits-fantasy'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $root 'work/assets'
$expected = @{
  'fantasy-props-megakit'='8B6F7E806D222E585478F0E1BDC6B271BBC7BC6F84DD6AF8CA703A7C64F0CB1E'
  'medieval-village-megakit'='E60DEA67C10F30DCCCCFBFF92A7933F5EA5CFE99BE0E2A0FA5118CCEABEEC5C4'
  'stylized-nature-megakit'='298F6732B872E4CF7B30E6E7ABF9641C7F6DC6B326DF37AC089533ED7E3D58C9'
  'universal-base-characters'='FDBF1804C90DFC1EA03E992BFF7DA2DFD1A79318E13270A660180F9308455F40'
  'universal-animation-library'='CC73FC4E495B82958207316596317A3F40B9FA38065BDE1027937452DA537724'
  'modular-character-outfits-fantasy'='C3468B18871CC8C8F05AB14DF7712BAF22CB9F389CBD870BABF130E595187F70'
}
New-Item -ItemType Directory -Force $destination | Out-Null
foreach ($slug in $Packs) {
  if ($slug -notin @('fantasy-props-megakit','medieval-village-megakit','stylized-nature-megakit','universal-base-characters','universal-animation-library','modular-character-outfits-fantasy')) { throw 'Unknown pack' }
  $archive = Join-Path $destination "$slug.zip"
  if (!(Test-Path $archive)) {
    $page = Invoke-WebRequest "https://quaternius.itch.io/$slug/purchase" -SessionVariable downloadSession
    $token = [regex]::Match($page.Content,'name="csrf_token" value="([^"]+)"').Groups[1].Value
    if (!$token) { throw 'Publisher page changed: missing request token' }
    $link = Invoke-RestMethod "https://quaternius.itch.io/$slug/download_url" -Method Post -WebSession $downloadSession -Body @{csrf_token=$token}
    $download = Invoke-WebRequest $link.url -WebSession $downloadSession
    # The zero-price page exposes only the freely downloadable edition. Never submit a payment.
    $upload = [regex]::Match($download.Content,'data-upload_id="(\d+)"').Groups[1].Value
    $token = [regex]::Match($download.Content,'name="csrf_token" value="([^"]+)"').Groups[1].Value
    if (!$upload -or !$token) { throw 'Publisher page changed: free upload not found' }
    $file = Invoke-RestMethod "https://quaternius.itch.io/$slug/file/$upload" -Method Post -WebSession $downloadSession -Body @{csrf_token=$token}
    if (!$file.url) { throw 'Publisher did not return a free download' }
    Invoke-WebRequest $file.url -OutFile "$archive.partial"
    Move-Item -LiteralPath "$archive.partial" -Destination $archive
  }
  if ((Get-FileHash -LiteralPath $archive).Hash -ne $expected[$slug]) { throw "Archive changed for $slug; review publisher update before importing" }
  Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $destination $slug) -Force
  Write-Output "$slug $((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash)"
}

