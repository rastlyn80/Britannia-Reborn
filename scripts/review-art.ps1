param([string]$DataDir,[switch]$SkipCapture,[switch]$Compatibility,[switch]$NoOpen)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (!$DataDir -and (Test-Path "$root/Server/runtime/Configuration/modernuo.json")) {
 $config=Get-Content "$root/Server/runtime/Configuration/modernuo.json" -Raw | ConvertFrom-Json
 $DataDir=@($config.dataDirectories)[0]
}
if (!$DataDir) { $DataDir="$env:USERPROFILE/OneDrive/Electronic Arts/Ultima Online Classic" }
if (!(Test-Path -LiteralPath (Join-Path $DataDir 'artLegacyMUL.uop'))) { throw 'Supply -DataDir for your own compatible UO artwork installation.' }
$out=Join-Path $root 'outputs/art-review'
New-Item -ItemType Directory -Force $out | Out-Null
& "$root/scripts/import-reviewed-art.ps1" -VerifyOnly
& "$root/scripts/prepare-surfaces.ps1" -VerifyOnly
& "$root/scripts/prepare-streaming.ps1"
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
$mode=@();if ($Compatibility) { $mode=@('--rendering-method','gl_compatibility') }
& $godot --headless --path "$root/Viewer" --script res://Presentation/ContactAudit.gd
if ($LASTEXITCODE) { throw 'Source contact audit failed' }
$review=Get-Content "$root/Viewer/Presentation/reviewed-catalog.json" -Raw | ConvertFrom-Json
$ids=@($review.entries.PSObject.Properties.Name | ForEach-Object { [int]$_ })
$snapshot="$root/Server/runtime/Data/UltimaClonePreview/audit.local.json"
if (Test-Path $snapshot) { $ids+=@((Get-Content $snapshot -Raw | ConvertFrom-Json).items.id) }
$env:DOTNET_CLI_HOME=Join-Path $root '.dotnet-home'
& "$root/.tools/dotnet/dotnet.exe" "$root/Converter/bin/Release/net8.0/Converter.dll" item-art $DataDir "$out/original-art.local.json" (($ids | Sort-Object -Unique) -join ',')
if ($LASTEXITCODE) { throw 'Local original-art extraction failed' }
if (!$SkipCapture) {
 & $godot @mode --path "$root/Viewer" --script res://Presentation/CandidateCapture.gd
 if ($LASTEXITCODE) { throw 'Model turntables failed' }
 & $godot @mode --path "$root/Viewer" --script res://Presentation/ArtBlockCapture.gd -- --city --label=after --hide-ui
 if ($LASTEXITCODE) { throw 'Reference-block captures failed' }
}
python "$root/scripts/audit-art.py"
if ($LASTEXITCODE) { throw 'Catalogue report failed' }
if (!$NoOpen) { Invoke-Item -LiteralPath "$out/review.html" }
