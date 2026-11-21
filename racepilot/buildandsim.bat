@echo off
REM SDK dibaca dari current-sdk.cfg supaya tidak rusak saat SDK upgrade
set "SDK="
set /p SDK=<"%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg"
if not defined SDK (echo SDK config tidak ditemukan & pause & exit /b 1)
set PRG=D:\Garmin\RacePilot\build\RacePilot.prg
set DEVICE=fr165

echo Building...
call "%SDK%\bin\monkeyc.bat" -o "%PRG%" -f D:\Garmin\RacePilot\monkey.jungle -y C:\Users\ALBIREO\developer_key.der -d %DEVICE%
if errorlevel 1 (
    echo BUILD FAILED
    pause
    exit /b 1
)

echo Build successful! Loading in simulator...
"%SDK%\bin\monkeydo.bat" "%PRG%" %DEVICE%
