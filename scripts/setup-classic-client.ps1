$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$pin = Get-Content "$root/ClassicClient/dependency.json" -Raw | ConvertFrom-Json
$target = Join-Path $root $pin.installPath
$exe = Join-Path $target 'ClassicUO.exe'
if ((Test-Path -LiteralPath $exe) -and (Get-FileHash -LiteralPath $exe).Hash -eq $pin.executableSha256) { return }
$archive = Join-Path $root 'work/assets/classic-client/ClassicUO-win-x64-release.zip'
New-Item -ItemType Directory -Force (Split-Path $archive -Parent) | Out-Null
if (!(Test-Path -LiteralPath $archive) -or (Get-FileHash -LiteralPath $archive).Hash -ne $pin.sha256) {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -UseBasicParsing $pin.url -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive).Hash -ne $pin.sha256) { throw 'ClassicUO download differs from the reviewed official package; installation stopped.' }
New-Item -ItemType Directory -Force $target | Out-Null
Expand-Archive -LiteralPath $archive -DestinationPath $target -Force
if ((Get-FileHash -LiteralPath $exe).Hash -ne $pin.executableSha256) { throw 'ClassicUO executable verification failed.' }
Copy-Item -LiteralPath "$root/ClassicClient/ClassicUO-LICENSE.txt" -Destination "$target/ClassicUO-LICENSE.txt" -Force
Write-Output 'Official ClassicUO portable client installed and SHA-256 verified.'
