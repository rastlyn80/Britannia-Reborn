@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\review-human-batch.ps1"
if errorlevel 1 pause
