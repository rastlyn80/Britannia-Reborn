[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Install,
    [string]$ServerRuntime = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Server/runtime')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$toolRoot = $root
while ($toolRoot -and !(Test-Path -LiteralPath (Join-Path $toolRoot '.tools/dotnet-server/dotnet.exe'))) {
    $toolRoot = Split-Path -Parent $toolRoot
}
if (!$toolRoot) { throw 'Prepare the pinned ModernUO SDK before building the creature content extension.' }
$runtime = (Resolve-Path -LiteralPath $ServerRuntime).Path
$project = Join-Path $root 'Server/CreatureContent'
$dotnet = Join-Path $toolRoot '.tools/dotnet-server/dotnet.exe'
$env:DOTNET_CLI_HOME = Join-Path $toolRoot '.dotnet-home'
$env:NUGET_PACKAGES = Join-Path $toolRoot '.tools/nuget'
Push-Location $project
try {
    & $dotnet build CreatureContent.csproj -c Release --nologo --ignore-failed-sources "-p:ServerRuntime=$runtime"
    if ($LASTEXITCODE) { throw 'Creature content extension failed to build.' }
} finally {
    Pop-Location
}

if (!$Install -or !$PSCmdlet.ShouldProcess($runtime, 'Install the Britannia Reborn creature content extension')) {
    return
}

$assemblyName = 'BritanniaReborn.CreatureContent.dll'
$source = Join-Path $project "bin/Release/net10.0/$assemblyName"
$destination = Join-Path $runtime "Assemblies/$assemblyName"
$manifest = Join-Path $runtime 'Data/assemblies.json'
$assemblyList = @((Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json) | ForEach-Object { $_ })
if (!$assemblyList.Count -or !$assemblyList.Contains('UOContent.dll')) {
    throw 'The selected runtime assembly list does not include UOContent.dll.'
}
if (!(Test-Path -LiteralPath $destination) -or (Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    Copy-Item -LiteralPath $source -Destination $destination -Force
}
if ($assemblyName -notin $assemblyList) {
    $nextManifest = "$manifest.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        ConvertTo-Json -InputObject ($assemblyList + $assemblyName) | Set-Content -LiteralPath $nextManifest
        [IO.File]::Move($nextManifest, $manifest, $true)
    } finally {
        if (Test-Path -LiteralPath $nextManifest) {
            Remove-Item -LiteralPath $nextManifest
        }
    }
}
Write-Output 'Creature content installed. ModernUO loads the assembly at the next server start.'
