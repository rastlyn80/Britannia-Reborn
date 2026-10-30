@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\review-ostard.ps1" %*
