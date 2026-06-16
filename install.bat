@echo off
setlocal EnableExtensions
title Pakon F135 PSI - Installer

:: --- Require administrator; relaunch elevated in a window that NEVER closes on its own (cmd /k) ---
net session >nul 2>&1
if "%errorlevel%"=="0" goto :elevated

echo.
echo Requesting administrator privileges...
echo If a User Account Control (UAC) prompt appears, click YES.
echo.
powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/k \"%~f0\"' -Verb RunAs"
exit /b

:elevated
cd /d "%~dp0"
echo Running as administrator.
echo Installer folder: %~dp0
echo.

if not exist "%~dp0install_v4.ps1" (
    echo ERROR: install_v4.ps1 was not found next to install.bat.
    echo Extract the WHOLE package to a real folder ^(not inside the .zip^) and run again.
    echo.
    goto :end
)

:: Remove the "downloaded from the Internet" block so PowerShell can run the script.
powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%~dp0' -File | Unblock-File" >nul 2>&1

echo Starting the PowerShell installer...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_v4.ps1"
set "PSEXIT=%errorlevel%"
echo.
echo PowerShell finished with exit code: %PSEXIT%

:end
echo.
echo ============================================================
echo   The installer has finished. A full log was saved as:
echo   %~dp0install_log.txt
echo   Review the messages above before closing this window.
echo ============================================================
echo.
pause
