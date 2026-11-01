@echo off
rem The in-game assistant (bridge and automatic Claude responder), then the server.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-assistant.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-server.ps1"
if errorlevel 1 pause
