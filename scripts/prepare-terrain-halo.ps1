param(
  [Parameter(Mandatory=$true)][string]$WorldPath,
  [string]$DataDir = "$env:USERPROFILE\OneDrive\Electronic Arts\Ultima Online Classic"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$world = Get-Content -LiteralPath $WorldPath -Raw | ConvertFrom-Json
$x = [Math]::Max(0,[int]$world.originX-2)
$y = [Math]::Max(0,[int]$world.originY-2)
$width = [int]$world.width+[int]$world.originX-$x+2
$height = [Math]::Min(4096-$y,[int]$world.height+[int]$world.originY-$y+2)
if ($width -gt 256 -or $height -gt 256) { throw 'Two-cell halo extraction currently requires a crop of at most 252 cells per axis.' }
$scratch = Join-Path $root 'work/terrain-halo-source.json'
New-Item -ItemType Directory -Force (Split-Path $scratch -Parent) | Out-Null
& "$root/.tools/dotnet/dotnet.exe" "$root/Converter/bin/Release/net8.0/Converter.dll" convert $DataDir $scratch $x $y $width $height 4096
if ($LASTEXITCODE) { throw 'Terrain neighborhood extraction failed' }
$halo = Get-Content -LiteralPath $scratch -Raw | ConvertFrom-Json
$outside = { $_.x -lt $world.originX -or $_.y -lt $world.originY -or $_.x -ge $world.originX+$world.width -or $_.y -ge $world.originY+$world.height }
$world | Add-Member -NotePropertyName terrainHalo -NotePropertyValue @($halo.terrain | Where-Object $outside) -Force
$world | Add-Member -NotePropertyName staticHalo -NotePropertyValue @($halo.statics | Where-Object $outside) -Force
# Halo tile IDs need metadata too; canonical interior records stay unchanged.
foreach ($name in @('landData','staticData')) {
  foreach ($property in $halo.$name.PSObject.Properties) {
    if (!$world.$name.PSObject.Properties[$property.Name]) { $world.$name | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value }
  }
}
$world | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $WorldPath -Encoding utf8
Write-Host "Added $($world.terrainHalo.Count) read-only terrain neighbors; visible region unchanged."
