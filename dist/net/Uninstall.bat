@echo off
title Deus Ex: Revision Co-op uninstaller
echo This removes Revision Co-op and its co-op saves (Revision itself and your single-player saves stay).
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0payload\Uninstall-RevNet.ps1"
pause
