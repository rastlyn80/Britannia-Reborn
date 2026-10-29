@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch.ps1" -Region britain-trinsic
if errorlevel 1 pause
