param(
 [string[]]$Preparation=@('mummies/preparation.json','solen_warriors/preparation.json','ice_elementals/candidate.json'),
 [string]$Output='work/creatures/batch-review',
 [string[]]$Clips=@('Idle','Walk','Run','Attack','Death'),
 [switch]$AppearanceOnly
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$outputRoot=[IO.Path]::GetFullPath((Join-Path $root $Output))
if (!$outputRoot.StartsWith(($root+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)) {throw 'Keep review outputs inside the workspace'}
New-Item -ItemType Directory -Force $outputRoot|Out-Null
$results=@()
foreach ($relative in $Preparation) {
 $path=[IO.Path]::GetFullPath((Join-Path "$root/Viewer/local-art/creatures" $relative))
 if (!$path.StartsWith([IO.Path]::GetFullPath("$root/Viewer/local-art/creatures/"),[StringComparison]::OrdinalIgnoreCase)) {throw 'Preparation must be inside local creature art'}
 $prepared=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 foreach ($record in $prepared.models|Where-Object {$_.status -eq 'prepared'}) {
  $folder=Join-Path $outputRoot $record.kind
  New-Item -ItemType Directory -Force $folder|Out-Null
  $options=@("--family=$($record.family)","--kind=$($record.kind)","--preparation=$path","--output=$folder")
  $appearanceLog=Join-Path $folder 'appearance.log'
  & $godot --path "$root/Viewer" --script res://Presentation/CreatureAppearanceTests.gd -- @options *> $appearanceLog
  if ($LASTEXITCODE -or (Select-String -LiteralPath $appearanceLog -Pattern 'SCRIPT ERROR:|SHADER ERROR:|ERROR:' -Quiet)) {throw "GPU appearance failed: $($record.kind); see $appearanceLog"}
  $appearance=Get-Content "$folder/appearance.json" -Raw|ConvertFrom-Json
  if ($appearance.failures -or $appearance.renderer -ne 'forward_plus' -or !$appearance.samples.Count) {throw "Incomplete GPU appearance: $($record.kind)"}
  if (!$AppearanceOnly) {
   $captureLog=Join-Path $folder 'capture.log'
   & $godot --path "$root/Viewer" --script res://Presentation/CreatureReview.gd -- @options --capture "--clips=$($Clips -join ',')" *> $captureLog
   if ($LASTEXITCODE -or (Select-String -LiteralPath $captureLog -Pattern 'SCRIPT ERROR:|SHADER ERROR:|ERROR:' -Quiet)) {throw "GPU capture failed: $($record.kind); see $captureLog"}
   foreach ($clip in $Clips) {foreach ($angle in @('three-quarter','side')) {
    if (!(Test-Path -LiteralPath (Join-Path $folder ($clip.ToLowerInvariant()+'-'+$angle+'.png')))) {throw "Missing $clip/$angle frame for $($record.kind)"}
   }}
  }
  $results+=@{kind=$record.kind;preparation=$relative;preparation_sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant();appearance_sha256=(Get-FileHash "$folder/appearance.json").Hash.ToLowerInvariant();checks=$appearance.checks;renderer=$appearance.renderer;captures=(!$AppearanceOnly)}
  Write-Output "GPU reviewed: $($record.kind) / $($appearance.checks) checks"
 }
}
@{models=$results;scope='Candidate GPU appearance and source/refined/modern pose captures only; no acceptance-index change or native-server claim'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath "$outputRoot/batch.json"
