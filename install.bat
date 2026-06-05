@echo off
:: Auto-elevate to Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs -Wait"
    exit /b
)

:: Run the PowerShell installer from the same folder
powershell -ExecutionPolicy Bypass -NoExit -File "%~dp0install_v4.ps1"
pause
