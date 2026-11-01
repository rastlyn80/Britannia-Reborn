@echo off
rem Stops this package's game server. The world saves itself every few minutes.
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='dotnet.exe'\" | Where-Object { $_.CommandLine -match 'ModernUO' -and $_.ExecutablePath -like '%~dp0*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force; 'Game server stopped.' }"
pause
