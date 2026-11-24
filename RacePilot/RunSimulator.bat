@echo off
set "SDK="
set /p SDK=<"%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg"
if not defined SDK (echo SDK config tidak ditemukan & pause & exit /b 1)
set PRG=D:\Garmin\RacePilot\build\RacePilot.prg
set DEVICE=fr165

echo Starting simulator...
start "" "%SDK%\bin\simulator.exe"
timeout /t 3 >nul

echo Loading RacePilot on %DEVICE%...
"%SDK%\bin\monkeydo.bat" "%PRG%" %DEVICE%
