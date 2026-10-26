param([string]$DataDir="$env:USERPROFILE/OneDrive/Electronic Arts/Ultima Online Classic")
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$regionsPath=Join-Path $root 'Server/runtime/Data/regions.json'
$regions=Get-Content -LiteralPath $regionsPath -Raw | ConvertFrom-Json
$city=@($regions | Where-Object { $_.Name -eq 'Britain' -and $_.Map -eq 'Trammel' -and !$_.Parent })
if ($city.Count -ne 1 -or !$city[0].Area) { throw 'Expected one native Trammel Britain town region' }
$area=$city[0].Area
$x=[int]([Math]::Floor(($area.x1 | Measure-Object -Minimum).Minimum/64)*64)
$y=[int]([Math]::Floor(($area.y1 | Measure-Object -Minimum).Minimum/64)*64)
$endX=[int]([Math]::Ceiling(($area.x2 | Measure-Object -Maximum).Maximum/64)*64)
$endY=[int]([Math]::Ceiling(($area.y2 | Measure-Object -Maximum).Maximum/64)*64)
$env:DOTNET_CLI_HOME=Join-Path $root '.dotnet-home'
& "$root/.tools/dotnet/dotnet.exe" build "$root/Converter" -c Release --configfile "$root/NuGet.Config"
if ($LASTEXITCODE) { throw 'Converter build failed' }
$output=Join-Path $root 'outputs/britain'
& "$root/.tools/dotnet/dotnet.exe" "$root/Converter/bin/Release/net8.0/Converter.dll" atlas $DataDir $output $x $y ($endX-$x) ($endY-$y) --halo
if ($LASTEXITCODE) { throw 'Britain conversion failed' }
$path=Join-Path $output 'atlas.json'
$manifest=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
$manifest | Add-Member -NotePropertyName displayName -NotePropertyValue 'Britain' -Force
$manifest | Add-Member -NotePropertyName scope -NotePropertyValue 'city' -Force
$manifest | Add-Member -NotePropertyName nativeRegion -NotePropertyValue @{ map='Trammel'; name='Britain'; area=$area; sourceSha256=(Get-FileHash -LiteralPath $regionsPath -Algorithm SHA256).Hash } -Force
[IO.File]::WriteAllText($path,($manifest | ConvertTo-Json -Depth 15 -Compress),[Text.UTF8Encoding]::new($false))
Write-Output "Britain city: X=$x..$($endX-1), Y=$y..$($endY-1); $($manifest.chunks.Count) chunks"

& "$PSScriptRoot/bake-britain.ps1"
