param([string]$DataDir = "$env:USERPROFILE\OneDrive\Electronic Arts\Ultima Online Classic")
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $root 'Server\runtime'
if (!(Test-Path (Join-Path $DataDir 'map1LegacyMUL.uop')) -and !(Test-Path (Join-Path $DataDir 'map1.mul'))) { throw 'Trammel source map not found' }
if (!(Test-Path "$runtime\ModernUO.dll")) {
  New-Item -ItemType Directory -Force $runtime | Out-Null
  Copy-Item "$root\Server\ModernUO\Distribution\*" $runtime -Recurse -ErrorAction Stop
}
New-Item -ItemType Directory -Force "$runtime\Configuration" | Out-Null
if (!(Test-Path "$runtime\Configuration\modernuo.json")) {
  @{
    assemblyDirectories = @('Assemblies')
    dataDirectories = @($DataDir)
    listeners = @('127.0.0.1:2593')
    settings = @{
      'serverListing.serverName' = 'UltimaClone Local Development'
      'serverListing.address' = '127.0.0.1'
      'serverListing.autoDetect' = 'False'
      'pingServer.enabled' = 'True'
      'network.encryptionMode' = 'Unencrypted'
      'accountHandler.enableAutoAccountCreation' = 'True'
      'accountHandler.maxAccountsPerIP' = '10'
      'pathfinding.prebakeMaps' = 'False'
    }
  } | ConvertTo-Json -Depth 5 | Set-Content "$runtime\Configuration\modernuo.json"
}
if (!(Test-Path "$runtime\Configuration\expansion.json")) {
  # Upstream's current default is a development profile, not a final era decision.
  $expansions = Get-Content "$runtime\Data\expansions.json" -Raw | ConvertFrom-Json
  $expansion = $expansions[-1]
  foreach ($property in $expansion.MapSelectionFlags.PSObject.Properties) { $property.Value = $property.Name -eq 'Trammel' }
  $expansion | ConvertTo-Json -Depth 6 | Set-Content "$runtime\Configuration\expansion.json"
}
$credentials = Join-Path $root 'Server\credentials.local.json'
if (!(Test-Path $credentials)) {
  @{ username='uo3ddev'; password=[Guid]::NewGuid().ToString('N').Substring(0,24) } | ConvertTo-Json | Set-Content $credentials
}
Write-Host 'Configured a loopback-only ModernUO runtime with separate local saves.'
