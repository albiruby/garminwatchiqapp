@echo off
title RacePilot Simulator
echo ==========================================
echo  RacePilot - Starting Simulator
echo ==========================================

set /p SDK=<"%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg"
set PRG=D:\Garmin\RacePilot\build\RacePilot.prg
set DEVICE=fr165

echo [1/3] Killing old processes...
taskkill /F /IM simulator.exe >nul 2>&1
taskkill /F /IM java.exe >nul 2>&1
timeout /t 2 >nul

echo [2/3] Starting simulator...
start "" "%SDK%\bin\simulator.exe"
echo Waiting 12 seconds for simulator to fully load...
timeout /t 12 >nul

echo [3/3] Loading RacePilot...
"%SDK%\bin\monkeydo.bat" "%PRG%" %DEVICE%

echo.
echo ==========================================
echo  RacePilot loaded! Check simulator window.
echo  Click START (top right) to begin activity.
echo ==========================================
pause
