@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\review-ostard.ps1" %*
