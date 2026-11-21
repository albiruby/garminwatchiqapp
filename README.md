# Garmin Connect IQ apps

Two independent Connect IQ projects. Each folder has its own `manifest.xml`, `monkey.jungle` and README with build steps.

| Folder | Project |
|---|---|
| [`pulseform/`](pulseform/README.md) | **PULSEFORM**: an activity-goal watch face for Forerunner 165 (6 faces, 4 looks, goal track) |
| [`restora/`](restora/README.md) | **RESTORA**: see its README and `HANDOVER.md` |

Build a project from inside its folder, for example:

```powershell
cd pulseform
```
```powershell
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
```
```powershell
& "$sdk\bin\monkeyc.bat" -d fr165 -f monkey.jungle -o bin\PulseForm.prg -y <path-to-developer_key.der> -r
```

Signing keys are never committed (`.gitignore`).
