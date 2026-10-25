$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'Server\ModernUO'
if (!(Test-Path "$source\.git")) {
  & git clone --no-checkout 'https://github.com/modernuo/ModernUO.git' $source
  if ($LASTEXITCODE) { throw 'ModernUO checkout failed' }
  & git -C $source checkout --detach ab59efea86fd9e399d261bed9d188ab4d95ad4c2
  if ($LASTEXITCODE) { throw 'Pinned ModernUO revision unavailable' }
}
$tools = Join-Path $root '.tools'
if (!(Test-Path "$tools\dotnet-server\dotnet.exe")) {
  $archive = Join-Path $tools 'sdk-10.0.201.zip'
  Invoke-WebRequest 'https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.201/dotnet-sdk-10.0.201-win-x64.zip' -OutFile $archive
  Expand-Archive $archive "$tools\dotnet-server" -Force
}
& "$PSScriptRoot\build-server.ps1"
& "$PSScriptRoot\configure-server.ps1"
