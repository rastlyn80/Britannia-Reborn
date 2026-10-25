# Authoring tool: creates explicit, editable ID rules for the audited play crop.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$world = Get-Content "$root/Viewer/play-world.json" -Raw | ConvertFrom-Json
$rules = [ordered]@{}
$axisY = @(8,15,27,31,32,301,308,311,313,315,317,320,323,331,2148,2912,2974)
$corner = @(26,295,309)
$slopes = @{1430=@(-1,0);1431=@(1,0);1433=@(-1,0);1434=@(1,0);1442=@(0,-1);1443=@(0,1);1460=@(-1,0);1461=@(1,0);1475=@(-1,0);1476=@(1,0);1487=@(0,-1);1488=@(0,1)}
foreach ($property in $world.staticData.PSObject.Properties) {
  $id = [int]$property.Name; $name = $property.Value.name.ToLower(); $height = [int]$property.Value.height
  $kind=''; $asset=''; $confidence='semantic-substitute'
  if ($id -in $corner) { $kind='corner'; $asset='Village/Wall_Plaster_Straight.gltf' }
  elseif ($id -in @(9,29,298,4758)) { $kind='post'; $asset='Village/Prop_Support.gltf' }
  elseif ($id -in @(330,331)) { $kind='gable'; $asset='Village/Wall_Plaster_Straight.gltf' }
  elseif ($name -match 'wall') { $kind=if($height -lt 15){'trim'}else{'wall'}; $asset=if($name -match 'stone'){'Village/Wall_UnevenBrick_Straight.gltf'}elseif($name -match 'wooden'){'Village/Wall_Plaster_WoodGrid.gltf'}else{'Village/Wall_Plaster_Straight.gltf'} }
  elseif ($name -eq 'window') { $kind='window'; $asset='Village/Wall_Plaster_Window_Wide_Flat.gltf' }
  elseif ($name -eq 'archway') { $kind='arch'; $asset='Village/Wall_Arch.gltf' }
  elseif ($name -eq 'wooden beam') { $kind='beam'; $asset='Village/Prop_ExteriorBorder_Straight1.gltf' }
  elseif ($name -eq 'wooden boards') { $kind='floor'; $asset='Village/Floor_WoodDark.gltf' }
  elseif ($name -match 'roof|shingle') { $kind='roof'; $asset='procedural:continuous-roof-with-kit-material' }
  elseif ($name -eq 'wooden door') { $kind='door'; $asset='Village/Door_1_Flat.gltf' }
  elseif ($name -match 'stairs') { $kind='stairs'; $asset='procedural:source-step-module' }
  elseif ($id -in @(1824,1848,1872)) { $kind='landing'; $asset='Village/Floor_WoodDark.gltf' }
  elseif ($name -eq 'wooden fence') { $kind='fence'; $asset='Village/Prop_WoodenFence_Single.gltf' }
  elseif ($name -eq 'bed') { $kind='bed'; $asset='Kenney/bedSingle.glb' }
  elseif ($id -ge 2769 -and $id -le 2786) { $kind='carpet'; $asset='procedural:woven-carpet-module' }
  elseif ($name -eq 'counter') { $kind='counter'; $asset='Kenney/cabinetBed.glb' }
  elseif ($name -eq 'bench') { $kind='bench'; $asset='Kenney/bench.glb' }
  elseif ($name -eq 'table') { $kind='table'; $asset='Kenney/table.glb' }
  elseif ($name -eq 'metal signpost') { $kind='sign'; $asset='procedural:wrought-sign-bracket' }
  elseif ($name -match 'leaves|needles') { $kind='canopy'; $asset='group:matching-tree-crown' }
  elseif ($name -match 'tree|sapling') { $kind='tree'; $asset=if($name -match 'cedar'){'Nature/Pine_1.gltf'}elseif($name -match 'willow'){'Nature/TwistedTree_1.gltf'}elseif($name -match 'sapling'){'Nature/CommonTree_2.gltf'}else{'Nature/CommonTree_1.gltf'} }
  elseif ($name -match 'flower') { $kind='flower'; $asset=if($id%2){'Nature/Flower_3_Group.gltf'}else{'Nature/Flower_4_Group.gltf'} }
  elseif ($name -eq 'grasses') { $kind='grass'; $asset=if($id%2){'Nature/Grass_Common_Tall.gltf'}else{'Nature/Grass_Wispy_Short.gltf'} }
  elseif ($name -eq 'fallen log') { $kind='log'; $asset='Village/Roof_Log.gltf' }
  elseif ($name -match 'mushroom') { $kind='mushroom'; $asset='Nature/Mushroom_Common.gltf' }
  elseif ($name -eq 'brambles') { $kind='bush'; $asset='Nature/Bush_Common.gltf' }
  elseif ($name -eq 'painting') { $kind='painting'; $asset='procedural:framed-landscape' }
  elseif ($name -eq 'rock') { $kind='rock'; $asset='Nature/Rock_Medium_1.gltf' }
  elseif ($name -eq 'water') { $kind='water'; $asset='procedural:animated-water-surface' }
  if (!$kind) { throw ('Unaudited tile 0x{0:X4}: {1}' -f $id,$name) }
  $axis=if($id -in $axisY){'y'}else{'x'}
  $entry=[ordered]@{kind=$kind;asset=$asset;axis=$axis;confidence=$confidence}
  if ($kind -in @('wall','window','corner','trim','arch','post','fence','beam')) { $entry.confidence='reference-shape-and-axis; modern-style-substitute' }
  if ($kind -eq 'corner') { $entry.asset=if($id -eq 26){'Village/Wall_UnevenBrick_Straight.gltf'}else{'Village/Wall_Plaster_Straight.gltf'} }
  if ($id -eq 29) { $entry.asset='Village/Wall_UnevenBrick_Straight.gltf' }
  if ($id -eq 4758) { $entry.confidence='metadata-only; original silhouette needs further review' }
  if ($kind -eq 'roof') {
    $entry.anchorOffset=@(-1,-1)
    $entry.material=if($name -match 'slate'){'slate'}elseif($name -match 'tile roof'){'clay'}else{'shingle'}
    $entry.rise=if($slopes.ContainsKey($id)){$slopes[$id]}else{@(0,0)}
    $entry.ridgeAxis=if($id -in @(1429,1437,1459,1474)){'y'}else{'x'}
    $entry.confidence='reference-family; source-elevation slope'
  }
  if ($kind -eq 'stairs') { $entry.rise=if($id -eq 1850){@(1,0)}elseif($id -eq 1852){@(-1,0)}else{@(0,-1)} }
  $rules[[string]$id]=$entry
}
@{version=2;scope='Audited Britain crop IDs; no source positions or art payload';rules=$rules} | ConvertTo-Json -Depth 8 | Set-Content "$root/Viewer/Presentation/static-catalog.json"
Write-Output "$($rules.Count) explicit static ID rules authored."
