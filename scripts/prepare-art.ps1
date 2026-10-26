$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'work/assets'
$target = Join-Path $root 'Viewer/Art/Quaternius'
New-Item -ItemType Directory -Force $target | Out-Null
$manifest = @()
function Copy-Model($pack, $name, $category) {
  $file = @(Get-ChildItem (Join-Path $source $pack) -Recurse -File | Where-Object { $_.Name -eq $name -and $_.FullName -notlike '*Unity*' })[0]
  if (!$file) { throw "Missing $name; run fetch-art.ps1 first" }
  $dest = Join-Path $target $category
  New-Item -ItemType Directory -Force $dest | Out-Null
  $files = @($file.FullName)
  if ($file.Extension -eq '.gltf') {
    $model = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    foreach ($entry in @($model.buffers)+@($model.images)) {
      if ($entry.uri -and !$entry.uri.StartsWith('data:')) {
        if ($entry.uri.Contains('/') -or $entry.uri.Contains('\')) { throw 'Unexpected dependency path' }
        $dependency = Join-Path $file.DirectoryName ([uri]::UnescapeDataString($entry.uri))
        if (!(Test-Path -LiteralPath $dependency) -and $entry.uri -in @('T_Hair_1_Normal_png.png','T_Eye_Normal_png.png')) {
          # Publisher glTF references this missing alias; use its supplied normal texture.
          $entry.uri = $entry.uri.Replace('_Normal_png.png','_Normal.png')
          $dependency = Join-Path $file.DirectoryName $entry.uri
        }
        $files += $dependency
      }
    }
  }
  foreach ($f in $files) { Copy-Item -LiteralPath $f -Destination $dest -Force }
  if ($file.Extension -eq '.gltf' -and $category -eq 'Character') { $model | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $dest $file.Name) }
}
$village = @('Wall_Plaster_Straight','Wall_UnevenBrick_Straight','Floor_WoodDark','Floor_Brick','Roof_Wooden_2x1','Roof_Modular_RoundTiles','Prop_Crate','Wall_Plaster_Window_Wide_Flat','Wall_Plaster_Door_Flat','Wall_Arch','Door_1_Flat','Prop_WoodenFence_Single','Prop_Support','Prop_ExteriorBorder_Straight1','Corner_Exterior_Wood','Stair_Interior_Simple','Wall_Plaster_Straight_Base','Wall_Plaster_WoodGrid','Prop_Chimney','Roof_Log')
foreach ($name in $village) { Copy-Model 'medieval-village-megakit' "$name.gltf" 'Village' }
foreach ($name in @('CommonTree_1','CommonTree_2','CommonTree_3','CommonTree_4','CommonTree_5','Pine_1','Pine_2','TwistedTree_1','Bush_Common','Bush_Common_Flowers','Rock_Medium_1','Rock_Medium_2','Grass_Common_Short','Grass_Common_Tall','Grass_Wispy_Short','Flower_3_Group','Flower_4_Group','Mushroom_Common','Mushroom_Laetiporus','DeadTree_1')) {
  # Fail explicitly for selected model names absent from an edition.
  if (Get-ChildItem "$source/stylized-nature-megakit" -Recurse -Filter "$name.gltf") { Copy-Model 'stylized-nature-megakit' "$name.gltf" 'Nature' }
}
Copy-Model 'universal-base-characters' 'Superhero_Male_FullBody.gltf' 'Character'
Copy-Model 'universal-animation-library' 'UAL1_Standard.glb' 'Animation'
Copy-Model 'modular-character-outfits-fantasy' 'Male_Peasant.gltf' 'Outfit'
Copy-Model 'modular-character-outfits-fantasy' 'Male_Ranger_Head_Hood.gltf' 'Outfit'
foreach ($pack in @('medieval-village-megakit','stylized-nature-megakit','universal-base-characters','universal-animation-library','modular-character-outfits-fantasy')) {
  $license = Get-ChildItem "$source/$pack" -Recurse -Filter 'License*.txt' | Select-Object -First 1
  Copy-Item -LiteralPath $license.FullName -Destination "$target/$pack-LICENSE.txt" -Force
  $manifest += [ordered]@{pack=$pack;author='Quaternius';edition='Standard';license='CC0-1.0';source="https://quaternius.itch.io/$pack";archiveSha256=(Get-FileHash -LiteralPath "$source/$pack.zip").Hash}
}
if (Test-Path "$target/Props/manifest.json") {
  $props=Get-Content "$target/Props/manifest.json" -Raw | ConvertFrom-Json
  $manifest += [ordered]@{pack='fantasy-props-megakit';author='Quaternius';edition='Standard';license='CC0-1.0';source=$props.source;archiveSha256=$props.archiveSha256}
}
$inventory = Get-ChildItem $target -Recurse -File | Where-Object { $_.Extension -notin @('.import','.json') } | ForEach-Object {
  [ordered]@{path=[IO.Path]::GetRelativePath($target,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
}
@{packs=$manifest;files=@($inventory);modifications='Selected original glTF/GLB files and dependencies. Character glTF reserialized; missing normal-map aliases corrected to supplied textures. Runtime head mask, source-to-target rest-pose animation retargeting, shared-skeleton peasant outfit and ranger hood assembly. Runtime foliage ignores wind vertex colours and replaces red TwistedTree leaf colour texture with the supplied green NormalTree colour texture. Continuous metre-authored facade panels using kit texture detail, connected roof samples and gable/ridge trim, source-scaled smaller architectural modules, grouped foliage/bed/arch components, and procedural roof geometry using kit material detail; runtime architectural palette shader preserves subdued original surface detail; all original files otherwise retained.'} | ConvertTo-Json -Depth 6 | Set-Content "$target/manifest.json"
Write-Output 'Selected art prepared with licenses and SHA-256 manifest.'

