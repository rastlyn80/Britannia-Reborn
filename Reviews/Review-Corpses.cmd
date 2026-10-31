@echo off
if not exist "%~dp0..\outputs\corpses\index.html" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\build-corpse-catalogue.ps1" -Render
if exist "%~dp0..\outputs\corpses\index.html" start "" "%~dp0..\outputs\corpses\index.html"
