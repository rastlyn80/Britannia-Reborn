param([switch]$Capture,[switch]$Sequence,[switch]$Validate,[switch]$MaterialTest,[switch]$Compatibility)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe"|Select-Object -First 1).FullName
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
foreach ($treatment in @('original','rounded','modern')) {
 if (!(Test-Path "$root/Viewer/local-art/ostards/desert-$treatment.gltf")) { throw 'Run scripts/prepare-third-dawn-ostard.py with the local archive and modern atlas first.' }
}
if (([int]$Capture.IsPresent+[int]$Sequence.IsPresent+[int]$MaterialTest.IsPresent) -gt 1) { throw 'Capture, Sequence and MaterialTest are separate runs.' }
& $godot --headless --path "$root/Viewer" --editor --import
if ($LASTEXITCODE) { throw 'Ostard import failed' }
$options=@('--path',"$root/Viewer")
if ($Compatibility) { $options+=@('--rendering-method','gl_compatibility') }
if ($Validate) {
 & $godot --headless --path "$root/Viewer" --script res://Presentation/OstardTests.gd
 if ($LASTEXITCODE) { throw 'Ostard deformation checks failed' }
 if (!$Capture -and !$Sequence -and !$MaterialTest) { return }
}
$out=Join-Path $root 'outputs/ostard-trial';New-Item -ItemType Directory -Force $out|Out-Null
$userOptions=@()
if ($Capture) { $userOptions+="--capture-dir=$out" }
if ($MaterialTest) { $userOptions+="--material-test=$out/material-$(if ($Compatibility) {'compatibility'} else {'forward'}).json" }
if ($Sequence) {
 $frames=Join-Path $out 'frames';New-Item -ItemType Directory -Force $frames|Out-Null
 $userOptions+="--sequence-dir=$frames"
}
& $godot @options --script res://Presentation/OstardReview.gd -- @userOptions
if ($LASTEXITCODE) { throw 'Ostard review failed' }
