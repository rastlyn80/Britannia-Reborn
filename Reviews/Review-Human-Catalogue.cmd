@echo off
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-human-catalogue.ps1
if errorlevel 1 pause
