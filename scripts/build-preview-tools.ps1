param([switch]$BuildOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:DOTNET_CLI_HOME = Join-Path $root '.dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
Push-Location "$root/Server/PreviewTools"
try {
  & "$root/.tools/dotnet-server/dotnet.exe" build PreviewTools.csproj -c Release --ignore-failed-sources
  if ($LASTEXITCODE) { throw 'Preview recovery extension build failed' }
} finally { Pop-Location }
if ($BuildOnly) { return }
$runtime = Join-Path $root 'Server/runtime'
$built = "$root/Server/PreviewTools/bin/Release/net10.0/UltimaClone.PreviewTools.dll"
$installed = "$runtime/Assemblies/UltimaClone.PreviewTools.dll"
if (!(Test-Path -LiteralPath $installed) -or (Get-FileHash -LiteralPath $built).Hash -ne (Get-FileHash -LiteralPath $installed).Hash) {
  Copy-Item -LiteralPath $built -Destination $installed -Force
}
$assemblies = @(Get-Content "$runtime/Data/assemblies.json" -Raw | ConvertFrom-Json)
if ('UltimaClone.PreviewTools.dll' -notin $assemblies) { $assemblies += 'UltimaClone.PreviewTools.dll' }
ConvertTo-Json -InputObject $assemblies | Set-Content "$runtime/Data/assemblies.json"
$configuration = Get-Content "$runtime/Configuration/modernuo.json" -Raw | ConvertFrom-Json
$configuration.settings | Add-Member -NotePropertyName 'ultimaClone.previewTools' -NotePropertyValue 'True' -Force
$configuration | ConvertTo-Json -Depth 12 | Set-Content "$runtime/Configuration/modernuo.json"
Write-Output 'Local-only recovery extension installed. A running server needs a saved, graceful restart to load it.'
