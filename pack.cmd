@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\pack.ps1" %*
exit /b %ERRORLEVEL%
