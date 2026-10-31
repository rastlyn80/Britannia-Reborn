param([switch]$RestoreLocks)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'Server\ModernUO'
$expected = 'ab59efea86fd9e399d261bed9d188ab4d95ad4c2'
if ((& git -C $source rev-parse HEAD) -ne $expected) { throw 'ModernUO revision differs from the audited dependency pin' }
& python -B "$PSScriptRoot/prepare-server-fixes.py"
if ($LASTEXITCODE) { throw 'Reviewed server overlay preparation failed' }
$dotnet = Join-Path $root '.tools\dotnet-server\dotnet.exe'
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:NUGET_PACKAGES = Join-Path $root '.tools\nuget'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$versionDir = Join-Path $root 'work\server-version'
New-Item -ItemType Directory -Force $versionDir | Out-Null
Set-Content (Join-Path $versionDir 'version.json') '{"version":"0.1.0-dev"}'
$locks = Join-Path $root 'Server\dependency-locks'
if (Test-Path $locks) {
  foreach ($file in Get-ChildItem $locks -Filter '*.json' -Recurse) {
    $relative = $file.FullName.Substring($locks.Length + 1)
    $destination = Join-Path $source $relative
    New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
  }
}
Push-Location $source
try {
  $fixTargets=Join-Path $root 'Server/fixes/EthicsRegistry.targets'
  $arguments = @('build','Projects/Application/Application.csproj','-c','Release','-m:1','-nr:false','--source','https://api.nuget.org/v3/index.json',"-p:GitVersionBaseDirectory=$versionDir",'-p:RestorePackagesWithLockFile=true',"-p:CustomBeforeMicrosoftCommonTargets=$fixTargets")
  if ((Test-Path $locks) -and !$RestoreLocks) { $arguments += '-p:RestoreLockedMode=true' }
  & $dotnet @arguments
  if ($LASTEXITCODE) { throw 'ModernUO build failed' }
  $content=Join-Path $source 'Distribution/Assemblies/UOContent.dll'
  $receipt=Get-Content "$root/work/server-fixes/source-manifest.json" -Raw|ConvertFrom-Json
  $receipt|Add-Member -NotePropertyName 'assembly_sha256' -NotePropertyValue (Get-FileHash -LiteralPath $content -Algorithm SHA256).Hash.ToLowerInvariant() -Force
  $receipt|ConvertTo-Json -Depth 6|Set-Content "$root/work/server-fixes/build-manifest.json"
  foreach ($file in Get-ChildItem Projects -Filter 'packages.lock.json' -Recurse) {
    $relative = $file.FullName.Substring($source.Length + 1)
    $destination = Join-Path $locks $relative
    New-Item -ItemType Directory -Force (Split-Path $destination -Parent) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
  }
} finally { Pop-Location }
