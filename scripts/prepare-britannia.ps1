param([string]$DataDir="$env:USERPROFILE/OneDrive/Electronic Arts/Ultima Online Classic")
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:DOTNET_CLI_HOME=Join-Path $root '.dotnet-home'
& "$root/.tools/dotnet/dotnet.exe" build "$root/Converter" -c Release --configfile "$root/NuGet.Config"
if ($LASTEXITCODE) { throw 'Converter build failed' }
& "$root/.tools/dotnet/dotnet.exe" "$root/Converter/bin/Release/net8.0/Converter.dll" atlas $DataDir "$root/outputs/atlas"
if ($LASTEXITCODE) { throw 'Full Britannia conversion failed' }
