param([switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$art=Join-Path $root 'Viewer/Art/Quaternius'
$props=Get-Content "$art/Props/manifest.json" -Raw | ConvertFrom-Json
if (!$VerifyOnly) {
 if (!(Test-Path "$root/work/assets/fantasy-props-megakit.zip")) { & "$root/scripts/fetch-art.ps1" -Packs @('fantasy-props-megakit') }
 if ((Get-FileHash "$root/work/assets/fantasy-props-megakit.zip").Hash.ToLowerInvariant() -ne $props.archiveSha256) { throw 'Fantasy Props archive differs from reviewed source' }
 if (!(Get-ChildItem "$root/work/assets/fantasy-props-megakit" -Recurse -Filter '*.gltf' -ErrorAction SilentlyContinue)) {
  Expand-Archive -LiteralPath "$root/work/assets/fantasy-props-megakit.zip" -DestinationPath "$root/work/assets/fantasy-props-megakit"
 }
 $selections=@(
  @{pack='fantasy-props-megakit';category='Props';models=@($props.models)},
  @{pack='medieval-village-megakit';category='Village';models=@('Window_Wide_Flat1','WindowShutters_Wide_Flat_Open','Prop_Vine1','Door_2_Flat')}
 )
 foreach ($selection in $selections) {
  foreach ($name in $selection.models) {
   $file=Get-ChildItem "$root/work/assets/$($selection.pack)" -Recurse -Filter "$name.gltf" | Select-Object -First 1
   if (!$file) { throw "Missing reviewed model $name" }
   $model=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
   $dependencies=@($file.FullName)
   foreach ($entry in @($model.buffers)+@($model.images)) {
    if (!$entry.uri -or $entry.uri.StartsWith('data:')) { continue }
    if ([IO.Path]::GetFileName($entry.uri) -ne $entry.uri) { throw 'Unsafe model dependency path' }
    $dependencies+=Join-Path $file.DirectoryName $entry.uri
   }
   foreach ($dependency in $dependencies) { Copy-Item -LiteralPath $dependency -Destination "$art/$($selection.category)" -Force }
  }
 }
 $license=Get-ChildItem "$root/work/assets/fantasy-props-megakit" -Recurse -Filter 'License*.txt' | Select-Object -First 1
 Copy-Item -LiteralPath $license.FullName -Destination "$art/Props/LICENSE.txt" -Force
}
foreach ($file in $props.files) {
 if ([IO.Path]::GetFileName($file.path) -ne $file.path) { throw 'Unsafe reviewed asset path' }
 if ((Get-FileHash -LiteralPath "$art/Props/$($file.path)").Hash.ToLowerInvariant() -ne $file.sha256.ToLowerInvariant()) { throw "Reviewed asset checksum mismatch: $($file.path)" }
}
Write-Output "Verified $($props.models.Count) reviewed-library CC0 models and $($props.files.Count) pinned source files."
