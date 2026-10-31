@echo off
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\review-third-dawn.ps1" -Equipment -Human -View clothing %*
if errorlevel 1 pause
