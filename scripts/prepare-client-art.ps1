param([string]$DataDir,[int[]]$GumpIds = @())
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$DataDir) {
 $candidates = @("$env:USERPROFILE/OneDrive/Electronic Arts/Ultima Online Classic","${env:ProgramFiles(x86)}/Electronic Arts/Ultima Online Classic")
 $DataDir = $candidates | Where-Object { Test-Path "$_/gumpartLegacyMUL.uop" } | Select-Object -First 1
}
if (!$DataDir) { throw 'Supply -DataDir pointing to your own UO client installation.' }
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$dotnet = Join-Path $root '.tools/dotnet/dotnet.exe'
& $dotnet build "$root/Converter" -c Release --configfile "$root/NuGet.Config" --nologo
if ($LASTEXITCODE) { throw 'Converter build failed' }
$dll = Join-Path $root 'Converter/bin/Release/net8.0/Converter.dll'
$signs = @(2995,3011,3012,4761,4766)
$catalog = "$root/Viewer/item-definitions.local.json"
if (Test-Path $catalog) {
 $definitions = Get-Content $catalog -Raw | ConvertFrom-Json
 $signs += $definitions.PSObject.Properties | ForEach-Object { [int]$_.Name }
}
$itemRequests = "$root/Viewer/item-art-requests.local.json"
if (Test-Path $itemRequests) { $signs += Get-Content $itemRequests -Raw | ConvertFrom-Json }
$signs += @(0xe75,0xeed,0x1f03,0xf51,0xefa)
python "$root/scripts/prepare-hues.py" $DataDir
if ($LASTEXITCODE) { throw 'Local hue preparation failed' }
& $dotnet $dll item-art $DataDir "$root/Viewer/item-art.local.json" (($signs | Sort-Object -Unique) -join ',')
if ($LASTEXITCODE) { throw 'Local sign artwork extraction failed' }
$GumpIds += @(2600..2608)+@(2072,2073,5540,5541)
$requests = "$root/Viewer/gump-art-requests.local.json"
if (Test-Path $requests) { $GumpIds += Get-Content $requests -Raw | ConvertFrom-Json }
& $dotnet $dll gump-art $DataDir "$root/Viewer/gump-art.local.json" (($GumpIds | Sort-Object -Unique) -join ',')
if ($LASTEXITCODE) { throw 'Local gump artwork extraction failed' }
Write-Host 'Local sign and gump artwork prepared. Restart the viewer. Do not redistribute these local files.'
