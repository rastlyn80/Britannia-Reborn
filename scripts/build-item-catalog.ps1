param([string]$DataDir,[switch]$NoOpen)
# Local art-direction catalogue of every original item graphic, ranked by world
# placements. Output (outputs/item-catalog) holds proprietary artwork: never commit.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (!$DataDir -and (Test-Path "$root/Server/runtime/Configuration/modernuo.json")) {
 $DataDir=@((Get-Content "$root/Server/runtime/Configuration/modernuo.json" -Raw | ConvertFrom-Json).dataDirectories)[0]
}
if (!$DataDir) { $DataDir="$env:USERPROFILE/OneDrive/Electronic Arts/Ultima Online Classic" }
if (!(Test-Path -LiteralPath (Join-Path $DataDir 'artLegacyMUL.uop'))) { throw 'Supply -DataDir for your own UO installation.' }
$britain='1280,1536,704,512'
$regionsPath="$root/Server/runtime/Data/regions.json"
if (Test-Path $regionsPath) {
 $city=@(Get-Content $regionsPath -Raw | ConvertFrom-Json | Where-Object { $_.Name -eq 'Britain' -and $_.Map -eq 'Trammel' -and !$_.Parent })
 if ($city.Count -eq 1) {
  $a=$city[0].Area;$x=($a.x1|Measure-Object -Minimum).Minimum;$y=($a.y1|Measure-Object -Minimum).Minimum
  $britain="$x,$y,$((($a.x2|Measure-Object -Maximum).Maximum)-$x),$((($a.y2|Measure-Object -Maximum).Maximum)-$y)"
 }
}
$env:DOTNET_CLI_HOME=Join-Path $root '.dotnet-home'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1'
$dotnet="$root/.tools/dotnet/dotnet.exe"
& $dotnet build "$root/Converter" -c Release --configfile "$root/NuGet.Config" --nologo -v q
if ($LASTEXITCODE) { throw 'Converter build failed' }
$out="$root/outputs/item-catalog"
& $dotnet "$root/Converter/bin/Release/net8.0/Converter.dll" item-catalog $DataDir $out "$root/Server/runtime/Data/Decoration" $britain "$root/Viewer/Presentation/reviewed-catalog.json" "$root/Viewer/item-colors.local.json"
if ($LASTEXITCODE) { throw 'Item catalogue extraction failed' }
# Label what the client draws today for each graphic (kit, owner packs, code, nothing).
$env:APPDATA=Join-Path $root '.godot-user';$env:LOCALAPPDATA=$env:APPDATA
$godot=(Get-ChildItem "$root/.tools/godot/*console.exe" | Select-Object -First 1).FullName
& $godot --headless --path "$root/Viewer" --script res://Presentation/ArtProvenance.gd -- "--catalog=$out/catalog.js" "--out=$out/current.js" "--open=$out/open-work.json"
if ($LASTEXITCODE) { throw 'Current-look labelling failed' }
Copy-Item "$root/scripts/item-catalog.html" "$out/index.html" -Force
Write-Host "Open $out/index.html (local reference only; do not redistribute)."
if (!$NoOpen) { Start-Process "$out/index.html" }
