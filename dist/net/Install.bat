@echo off
title Deus Ex: Revision Co-op installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0payload\Install-RevNet.ps1" %*
echo.
pause
