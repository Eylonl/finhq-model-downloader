@echo off
REM Double-click this, or run it from CMD, to download a FinHQ model.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0finhq-download.ps1"
echo.
pause
