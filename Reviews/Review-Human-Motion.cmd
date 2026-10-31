@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\review-human-motion.ps1" %*
