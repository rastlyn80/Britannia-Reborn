# Converts a streamed region covering several native Trammel town regions
# (their union, snapped to 64-tile districts) from the owned UO data into
# outputs/<Name>: atlas, source chunks and halo. Bake it with
#   scripts/prepare-streaming.ps1 -Dataset outputs/<Name> -Modern
# and play it with the client argument --region=<Name>.
# Example: scripts/prepare-region.ps1 -Name britain-trinsic -Towns Britain,Trinsic
param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string[]]$Towns,[string]$DataDir="$env:USERPROFILE/OneDrive/Electronic Arts/Ultima Online Classic")
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if ($Name -notmatch '^[a-z0-9-]+$') { throw 'Region name: lower-case letters, digits and dashes' }
$regionsPath=Join-Path $root 'Server/runtime/Data/regions.json'
$regions=Get-Content -LiteralPath $regionsPath -Raw | ConvertFrom-Json
$areas=@()
foreach ($town in $Towns) {
  $found=@($regions | Where-Object { $_.Name -eq $town -and $_.Map -eq 'Trammel' -and !$_.Parent })
  if ($found.Count -ne 1 -or !$found[0].Area) { throw "Expected one native Trammel town region named $town" }
  $areas+=$found[0].Area
}
$x=[int]([Math]::Floor(($areas.x1 | Measure-Object -Minimum).Minimum/64)*64)
$y=[int]([Math]::Floor(($areas.y1 | Measure-Object -Minimum).Minimum/64)*64)
$endX=[int]([Math]::Ceiling(($areas.x2 | Measure-Object -Maximum).Maximum/64)*64)
$endY=[int]([Math]::Ceiling(($areas.y2 | Measure-Object -Maximum).Maximum/64)*64)
$env:DOTNET_CLI_HOME=Join-Path $root '.dotnet-home'
& "$root/.tools/dotnet/dotnet.exe" build "$root/Converter" -c Release --configfile "$root/NuGet.Config"
if ($LASTEXITCODE) { throw 'Converter build failed' }
$output=Join-Path $root "outputs/$Name"
& "$root/.tools/dotnet/dotnet.exe" "$root/Converter/bin/Release/net8.0/Converter.dll" atlas $DataDir $output $x $y ($endX-$x) ($endY-$y) --halo
if ($LASTEXITCODE) { throw "$Name conversion failed" }
$path=Join-Path $output 'atlas.json'
$manifest=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
$manifest | Add-Member -NotePropertyName displayName -NotePropertyValue ($Towns -join ' to ') -Force
$manifest | Add-Member -NotePropertyName scope -NotePropertyValue 'region' -Force
$manifest | Add-Member -NotePropertyName nativeRegions -NotePropertyValue @{ map='Trammel'; towns=$Towns; sourceSha256=(Get-FileHash -LiteralPath $regionsPath -Algorithm SHA256).Hash } -Force
[IO.File]::WriteAllText($path,($manifest | ConvertTo-Json -Depth 15 -Compress),[Text.UTF8Encoding]::new($false))
Write-Output "$Name : X=$x..$($endX-1), Y=$y..$($endY-1); $($manifest.chunks.Count) districts"
