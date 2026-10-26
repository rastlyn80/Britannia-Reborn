@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\explore-britain.ps1"
if errorlevel 1 pause
