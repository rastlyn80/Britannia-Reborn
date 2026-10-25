param([switch]$Observer,[switch]$PrepareOnly,[switch]$Diagnostic)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$settingsPath = $null

function Read-LastLogin {
  $vault = Join-Path $root '.godot-user/Godot/app_userdata/UO World Studio/last-login.vault'
  if (!(Test-Path -LiteralPath $vault)) { return $null }
  $info = New-Object System.Diagnostics.ProcessStartInfo
  $info.FileName = (Get-Command powershell.exe).Source
  $info.Arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $root + '\scripts\login-vault.ps1" -Mode load -Path "' + $vault + '"'
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
  $helper = [Diagnostics.Process]::Start($info)
  try {
    $helper.StandardInput.WriteLine('{}')
    $helper.StandardInput.Close()
    $result = $helper.StandardOutput.ReadToEnd()
    $helper.WaitForExit()
    try { return ($result | ConvertFrom-Json) } catch { return $null }
  } finally { $helper.Dispose() }
}

function Encode-ClassicPassword([string]$Secret) {
  # Interoperable with ClassicUO.Utility.Crypter (BSD-2-Clause; bundled notice).
  # This is temporary compatibility obfuscation, not a replacement for DPAPI.
  $bytes = [Text.Encoding]::ASCII.GetBytes($Secret)
  $machine = [Environment]::MachineName
  $encoded = New-Object Text.StringBuilder
  [void]$encoded.Append('1-')
  for ($index=0; $index -lt $bytes.Length; $index++) {
    [void]$encoded.Append(('{0:X2}' -f ($bytes[$index] -bxor ([int][char]$machine[$index % $machine.Length] -band 255))))
  }
  return $encoded.ToString()
}

function Write-Profile($Profile,[string]$Path) {
  [IO.File]::WriteAllText($Path,($Profile | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
}

function Test-LocalServer {
  $probe = New-Object Net.Sockets.TcpClient
  try {
    $connection = $probe.ConnectAsync('127.0.0.1',2593)
    return ($connection.Wait(300) -and $probe.Connected)
  } catch { return $false } finally { $probe.Dispose() }
}

try {
  & "$PSScriptRoot/setup-classic-client.ps1"
  $clientRoot = Join-Path $root '.tools/classicuo'
  $profileDir = Join-Path $clientRoot 'UltimaClone'
  New-Item -ItemType Directory -Force $profileDir | Out-Null
  $profileName = if ($Observer) { 'observer.json' } else { 'primary.json' }
  $settingsPath = Join-Path $profileDir $profileName
  if (!$PrepareOnly) {
    $existing = Get-CimInstance Win32_Process -Filter "Name='ClassicUO.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($settingsPath) }
    if ($existing) { Write-Output 'This classic client is already running.'; return }
  }
  $data = $null
  if (Test-Path "$root/Server/runtime/Configuration/modernuo.json") {
    $configuration = Get-Content "$root/Server/runtime/Configuration/modernuo.json" -Raw | ConvertFrom-Json
    $data = @($configuration.dataDirectories | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'client.exe') } | Select-Object -First 1)[0]
  }
  if (!$data) { $data = Join-Path $env:USERPROFILE 'OneDrive/Electronic Arts/Ultima Online Classic' }
  if (!(Test-Path -LiteralPath (Join-Path $data 'client.exe'))) { throw 'The existing UO game-data folder could not be found.' }
  $version = ((Get-Item -LiteralPath (Join-Path $data 'client.exe')).VersionInfo.FileVersion -replace ',\s*','.').Trim()
  if ($version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'Could not read the installed UO client version.' }
  $profile = @{}
  if (Test-Path -LiteralPath $settingsPath) {
    $old = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    foreach ($property in $old.PSObject.Properties) { $profile[$property.Name] = $property.Value }
  }
  $profile.ip = '127.0.0.1'
  $profile.port = 2593
  $profile.ultimaonlinedirectory = $data
  $profile.clientversion = $version
  $profile.ignore_relay_ip = $true
  $profile.profilespath = Join-Path $clientRoot 'Data/Profiles'
  $profile.plugins = @()
  $profile.encryption = 0
  $profile.force_driver = 1
  $profile.login_music = $false
  $profile.reconnect = $false
  $profile.lastservernum = 1
  $profile.saveaccount = $false
  $profile.autologin = !$PrepareOnly
  $profile.username = ''
  $profile.password = ''
  if ($PrepareOnly) {
    Write-Profile $profile $settingsPath
    Write-Output 'Classic 2D local-server profile prepared without credentials.'
    return
  }
  if (!(Test-LocalServer)) {
    $serverArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSScriptRoot + '\start-server.ps1"'
    Start-Process powershell.exe -ArgumentList $serverArgs -WorkingDirectory $root -WindowStyle Hidden | Out-Null
    $ready = $false
    for ($attempt=0; $attempt -lt 100; $attempt++) {
      if (Test-LocalServer) { $ready = $true; break }
      Start-Sleep -Milliseconds 200
    }
    if (!$ready) { throw 'The local server did not become ready. Run Start-Server.cmd for details.' }
  }
  $credentials = if ($Observer) { $null } else { Read-LastLogin }
  if (!$credentials -or !$credentials.username -or !$credentials.password) {
    $credentials = Get-Content "$root/Server/credentials.local.json" -Raw | ConvertFrom-Json
    if ($Observer) { $credentials.username += '2' }
  }
  $profile.username = $credentials.username
  $profile.password = Encode-ClassicPassword $credentials.password
  $credentials = $null
  Write-Profile $profile $settingsPath
  # Only public profile paths are passed on the command line. Never passwords.
  $arguments = '-settings "' + $settingsPath + '" -profilespath "' + $profile.profilespath + '" -skiploginscreen -autologin true'
  $client = Start-Process -FilePath "$clientRoot/ClassicUO.exe" -ArgumentList $arguments -WorkingDirectory $clientRoot -WindowStyle Normal -RedirectStandardOutput "$root/work/classic-$profileName-stdout.log" -RedirectStandardError "$root/work/classic-$profileName-stderr.log" -PassThru
  $connected = $false
  for ($attempt=0; $attempt -lt 240; $attempt++) {
    $client.Refresh()
    if ($client.HasExited) { throw 'ClassicUO exited during startup. See its Logs folder in .tools/classicuo.' }
    $connection = Get-NetTCPConnection -OwningProcess $client.Id -RemotePort 2593 -State Established -ErrorAction SilentlyContinue
    if ($connection) { $connected = $true; break }
    Start-Sleep -Milliseconds 150
  }
  if (!$connected) { throw 'ClassicUO opened but its local-server connection was not confirmed.' }
  Remove-Item -LiteralPath (Join-Path $root 'outputs/validation/classic-launch-error.log') -ErrorAction SilentlyContinue
  Write-Output 'ClassicUO is open and connected to the existing local server.'
} catch {
  $logDir = Join-Path $root 'outputs/validation'
  New-Item -ItemType Directory -Force $logDir | Out-Null
  [IO.File]::WriteAllText((Join-Path $logDir 'classic-launch-error.log'),$_.Exception.Message)
  if ($PrepareOnly -or $Diagnostic) { throw }
  Add-Type -AssemblyName System.Windows.Forms
  [void][Windows.Forms.MessageBox]::Show("ClassicUO could not be opened automatically. Details are in outputs\validation\classic-launch-error.log.", 'UltimaClone classic comparison')
  throw
} finally {
  # Remove the short-lived native-client compatibility credential after startup,
  # including failure. The persistent source remains the Windows-encrypted vault.
  if ($settingsPath -and (Test-Path -LiteralPath $settingsPath)) {
    for ($retry=0; $retry -lt 3; $retry++) {
      try {
        $clean = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $clean.username = ''
        $clean.password = ''
        $clean.saveaccount = $false
        Write-Profile $clean $settingsPath
        break
      } catch { Start-Sleep -Milliseconds 100 }
    }
  }
}
