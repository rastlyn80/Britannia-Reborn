param([string]$DataDir, [string]$Dotnet, [switch]$SkipTests)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
if (!$Dotnet) {
  $portable = Join-Path $PSScriptRoot '.tools\dotnet\dotnet.exe'
  $Dotnet = if (Test-Path $portable) { (Resolve-Path $portable).Path } else { 'dotnet' }
}
$env:DOTNET_CLI_HOME = Join-Path $PSScriptRoot '.dotnet-home'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
& $Dotnet build Converter -c Release --configfile NuGet.Config
if ($LASTEXITCODE) { throw 'Build failed' }
$dll = Join-Path $PSScriptRoot 'Converter\bin\Release\net8.0\Converter.dll'
if (!$SkipTests) {
  & $Dotnet $dll test (Join-Path $PSScriptRoot '.test-fixture')
  if ($LASTEXITCODE) { throw 'Tests failed' }
}
if (!$DataDir) {
  $DataDir = Join-Path $PSScriptRoot '.fixture'
  & $Dotnet $dll fixture $DataDir
  if ($LASTEXITCODE) { throw 'Fixture generation failed' }
}
$outName = if (Test-Path (Join-Path $DataDir 'SYNTHETIC.txt')) { 'world.json' } else { 'local-world.json' }
& $Dotnet $dll convert $DataDir (Join-Path $PSScriptRoot "Viewer\$outName")
if ($LASTEXITCODE) { throw 'Conversion failed' }
Write-Host 'Ready. Run .\launch.ps1'
} finally { Pop-Location }
