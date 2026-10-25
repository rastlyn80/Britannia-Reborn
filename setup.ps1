$ErrorActionPreference = 'Stop'
$tools = Join-Path $PSScriptRoot '.tools'
New-Item -ItemType Directory -Force $tools | Out-Null
# Pinned portable tools, installed only under this workspace. Requires internet.
$sdk = Join-Path $tools 'sdk-8.0.426.zip'
if (!(Test-Path "$tools\dotnet\dotnet.exe")) {
  Invoke-WebRequest 'https://builds.dotnet.microsoft.com/dotnet/Sdk/8.0.426/dotnet-sdk-8.0.426-win-x64.zip' -OutFile $sdk
  Expand-Archive $sdk "$tools\dotnet" -Force
}
if (!(Test-Path "$tools\godot\Godot_v4.7.2-stable_win64.exe")) {
  $zip = Join-Path $tools 'godot.zip'
  Invoke-WebRequest 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip' -OutFile $zip
  if ((Get-FileHash $zip).Hash -ne '731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953') { throw 'Godot archive checksum mismatch' }
  Expand-Archive $zip "$tools\godot" -Force
}
& "$PSScriptRoot\build.ps1"
