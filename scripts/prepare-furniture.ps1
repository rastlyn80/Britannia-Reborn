$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$archive = Join-Path $root 'work/assets/kenney-furniture.zip'
if (!(Test-Path $archive)) {
  Invoke-WebRequest 'https://kenney.nl/media/pages/assets/furniture-kit/440e0608a4-1677580847/kenney_furniture-kit.zip' -OutFile $archive
}
if ((Get-FileHash $archive).Hash -ne 'E67652D0932CEE41683F74711C03D3E192A2AF9979EF8E6B237711F5482D46B0') { throw 'Furniture archive changed; review required' }
$source = Join-Path $root 'work/assets/kenney-furniture'
Expand-Archive -LiteralPath $archive -DestinationPath $source -Force
$target = Join-Path $root 'Viewer/Art/Kenney'
New-Item -ItemType Directory -Force $target | Out-Null
foreach ($name in @('bedSingle.glb','bedDouble.glb','bench.glb','table.glb','tableCloth.glb','cabinetBed.glb')) {
  $file = Get-ChildItem $source -Recurse -Filter $name | Select-Object -First 1
  Copy-Item -LiteralPath $file.FullName -Destination $target -Force
}
$license = Get-ChildItem $source -Recurse -Filter '*license*' | Select-Object -First 1
Copy-Item -LiteralPath $license.FullName -Destination "$target/LICENSE.txt" -Force
$files = @(Get-ChildItem $target -File | Where-Object Extension -in @('.glb','.txt') | ForEach-Object { @{path=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash} })
@{author='Kenney';source='https://kenney.nl/assets/furniture-kit';edition='Furniture Kit 2.0 (bundled notice)';license='CC0-1.0';archiveSha256=(Get-FileHash $archive).Hash;files=$files;modifications='Selected original GLB files; runtime scale, orientation and material warmth only.'} | ConvertTo-Json -Depth 5 | Set-Content "$target/manifest.json"
