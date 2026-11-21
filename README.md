# Garmin Connect IQ apps

Independent Garmin projects, one per folder. Each has its own README with build steps.

| Folder | Project | History |
|---|---|---|
| [`pulseform/`](pulseform/README.md) | **PULSEFORM**: activity-goal watch face for Forerunner 165 (6 faces, 4 looks) | from this repo |
| [`restora/`](restora/README.md) | **RESTORA** | 32 commits, merged from branch `claude/restora-calculation-engine-1n4b9q` |
| [`racepilot/`](racepilot/) | **RacePilot** | 3 commits, merged from the local repo (`master`) |
| [`watchcraft/`](watchcraft/) | **WatchCraft** | 16 commits, merged from `albiruby/WatchCraft` (`main`) |
| [`batik-watchface/`](batik-watchface/) | **NUSANTARA batik watch faces** (Kawung, Megamendung, Parang) | first commit here (it was not under git before) |

Connect IQ projects build from inside their folder, for example:

```powershell
cd pulseform
```
```powershell
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
```
```powershell
& "$sdk\bin\monkeyc.bat" -d fr165 -f monkey.jungle -o bin\PulseForm.prg -y <path-to-developer_key.der> -r
```

Signing keys (`*.der`, `*.pem`) and build output (`bin/`) are never committed.
