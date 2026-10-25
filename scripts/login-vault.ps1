param([ValidateSet('save','load','forget')][string]$Mode, [string]$Path)
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
try {
    Add-Type -AssemblyName System.Security
    $request = [Console]::ReadLine()
    if ($Mode -eq 'save') {
        $null = $request | ConvertFrom-Json
        $bytes = [Text.Encoding]::UTF8.GetBytes($request)
        $protected = [Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
        [IO.File]::WriteAllBytes($Path + '.tmp',$protected)
        Move-Item -LiteralPath ($Path + '.tmp') -Destination $Path -Force
        [Console]::WriteLine('{"ok":true}')
    } elseif ($Mode -eq 'load' -and [IO.File]::Exists($Path)) {
        $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($Path),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
        [Console]::WriteLine([Text.Encoding]::UTF8.GetString($bytes))
    } else {
        if ($Mode -eq 'forget' -and [IO.File]::Exists($Path)) { [IO.File]::Delete($Path) }
        [Console]::WriteLine('{"ok":true}')
    }
} catch { [Console]::WriteLine('{"ok":false}') }
