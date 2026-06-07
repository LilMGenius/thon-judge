@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%thon-judge.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%thon-judge.ps1" %*
)
if errorlevel 1 exit /b %errorlevel%
exit /b 0
