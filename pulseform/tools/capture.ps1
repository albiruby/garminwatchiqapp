# Renders PULSEFORM states in the Connect IQ simulator and saves each watch as a PNG.
# Each shot is one line of a CSV-like spec:
#   name,layout,style,accent,steps,goal,sleep,twelve,hour,min[,trackWeight[,look]]
# layout 0-5 (Balanced, Minimal, Dense, Dial, Horizon, Stack), accent 0 = look default,
# look 0-3 (Carbon, Reflective, Field, Signal).
#   capture.ps1 -Shots "balanced-74,0,0,0,7482,10000,0,0,10,9"
#   capture.ps1 -Matrix                 (the QA matrix below)
# Rewrites source\Preview.mc while running and always switches it back to ON = false.
param(
    [string[]]$Shots = @(),
    [switch]$Matrix,
    [string]$Device = "fr165",
    [string]$OutDir = "docs\screens",
    [string]$Key = "D:\Garmin\Batik Watchface\keys\developer_key.der"
)
$ErrorActionPreference = "Stop"
$proj = Resolve-Path (Join-Path $PSScriptRoot "..")
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
. (Join-Path $PSScriptRoot "CapWin.ps1")
$out = Join-Path $proj $OutDir
New-Item -ItemType Directory -Force $out | Out-Null

if ($Matrix) {
    $Shots = @(
        # every face in every look (mid-day, 74 %)
        "carbon-balanced,0,0,0,7482,10000,0,0,10,9,1,0",
        "carbon-minimal,1,0,0,7482,10000,0,0,10,9,1,0",
        "carbon-dense,2,0,0,7482,10000,0,0,10,9,1,0",
        "carbon-dial,3,0,0,7482,10000,0,0,10,9,1,0",
        "carbon-horizon,4,0,0,7482,10000,0,0,10,9,1,0",
        "carbon-stack,5,0,0,7482,10000,0,0,10,9,1,0",
        "reflective-balanced,0,0,0,7482,10000,0,0,10,9,1,1",
        "reflective-minimal,1,0,0,7482,10000,0,0,10,9,1,1",
        "reflective-dense,2,0,0,7482,10000,0,0,10,9,1,1",
        "reflective-dial,3,0,0,7482,10000,0,0,10,9,1,1",
        "reflective-horizon,4,0,0,7482,10000,0,0,10,9,1,1",
        "reflective-stack,5,0,0,7482,10000,0,0,10,9,1,1",
        "field-balanced,0,0,0,7482,10000,0,0,10,9,1,2",
        "field-minimal,1,0,0,7482,10000,0,0,10,9,1,2",
        "field-dense,2,0,0,7482,10000,0,0,10,9,1,2",
        "field-dial,3,0,0,7482,10000,0,0,10,9,1,2",
        "field-horizon,4,0,0,7482,10000,0,0,10,9,1,2",
        "field-stack,5,0,0,7482,10000,0,0,10,9,1,2",
        "signal-balanced,0,0,0,7482,10000,0,0,10,9,1,3",
        "signal-minimal,1,0,0,7482,10000,0,0,10,9,1,3",
        "signal-dense,2,0,0,7482,10000,0,0,10,9,1,3",
        "signal-dial,3,0,0,7482,10000,0,0,10,9,1,3",
        "signal-horizon,4,0,0,7482,10000,0,0,10,9,1,3",
        "signal-stack,5,0,0,7482,10000,0,0,10,9,1,3",
        # goal states (0, 1, 99, 100, 150 %) on the new faces
        "state-000-horizon,4,0,0,0,10000,0,0,7,5,1,0",
        "state-099-dial,3,0,0,9990,10000,0,0,18,20,1,0",
        "state-100-signal,0,0,0,10000,10000,0,0,19,0,1,3",
        "state-150-stack,5,0,0,15000,10000,0,0,21,15,1,0",
        "state-150-horizon,4,0,0,15000,10000,0,1,21,15,1,1",
        "state-001-balanced,0,0,0,100,10000,0,0,7,5,1,0",
        # styles, accents, bold track, 12 h, big numbers
        "linear-dense-150,2,1,0,15000,10000,0,0,10,9,1,0",
        "segmented-dial-violet,3,2,8,6100,8000,0,1,9,5,1,0",
        "bold-150-reflective,0,0,0,15000,10000,0,0,21,15,2,1",
        "big-steps-stack,5,0,0,48213,12000,0,1,12,0,1,2",
        "minimal-12h-red,1,0,6,7482,10000,0,1,12,45,1,0",
        # always-on
        "aod-balanced,0,0,0,7482,10000,1,0,10,9,1,0",
        "aod-dial,3,0,0,7482,10000,1,0,10,9,1,2"
    )
}

function Write-Preview($p) {
    $on = if ($p) { "true" } else { "false" }
    if (-not $p) { $p = @("", 0, 0, 0, 7482, 10000, 0, 0, 10, 9) }
    $sl = if ([int]$p[6]) { "true" } else { "false" }
    $tw = if ([int]$p[7]) { "true" } else { "false" }
    $w = if ($p.Count -gt 10) { [int]$p[10] } else { 1 }
    $look = if ($p.Count -gt 11) { [int]$p[11] } else { 0 }
@"
import Toybox.Lang;

// Screenshot fixtures, rewritten by tools/capture.ps1. ON must be false in every
// release build: when ON, metrics come from these constants instead of the device.
module Preview {
    const ON = $on;
    const LAYOUT = $($p[1]);
    const STYLE = $($p[2]);
    const THEME = $($p[3]);
    const STEPS = $($p[4]);
    const GOAL = $($p[5]);
    const HOUR = $($p[8]);
    const MIN = $($p[9]);
    const SEC = 42;
    const SLEEP = $sl;
    const TWELVE = $tw;
    const DATE = "SAT 21 NOV";
    const WEIGHT = $w;
    const LOOK = $look;

    function apply(s as SettingsManager) as Void {
        s.layout = LAYOUT;
        s.goalStyle = STYLE;
        s.theme = THEME;
        s.stepGoalMode = 0;
        s.distanceTarget = 8.0;
        s.calorieTarget = 2600;
        s.showSeconds = true;
        s.trackWeight = WEIGHT;
        s.look = LOOK;
        ThemeManager.apply(LOOK, THEME);
    }

    function metrics() as Metrics {
        var m = new Metrics();
        m.steps = STEPS;
        m.stepGoal = GOAL;
        m.distanceCm = 524000;
        m.calories = 1834;
        m.intensityDay = 12;
        m.intensityWeek = 85;
        m.intensityWeekGoal = 150;
        m.moveBar = 2;
        m.floors = 7;
        m.floorsGoal = 10;
        m.heartRate = 64;
        m.battery = 82.0;
        m.batteryDays = 6;
        m.metric = true;
        return m;
    }
}
"@ | Set-Content -Encoding ascii (Join-Path $proj "source\Preview.mc")
}

# -File passes "a","b" as one string; shots may also be separated with ';'
$Shots = @($Shots | ForEach-Object { $_ -split ";" } | Where-Object { $_ })
$files = @()
try {
    foreach ($spec in $Shots) {
        $p = $spec.Split(",")
        Write-Preview $p
        $r = & "$sdk\bin\monkeyc.bat" -d $Device -f "$proj\monkey.jungle" -o "$proj\bin\preview.prg" -y $Key 2>&1
        if (($r | Out-String) -match "ERROR") { throw ($r | Out-String) }
        if (-not (Get-Process simulator -ErrorAction SilentlyContinue)) { Start-Process "$sdk\bin\simulator.exe"; Start-Sleep 10 }
        Start-Process -WindowStyle Hidden cmd -ArgumentList "/c `"`"$sdk\bin\monkeydo.bat`" `"$proj\bin\preview.prg`" $Device`""
        Start-Sleep 9
        $h = (Get-Process simulator).MainWindowHandle
        $raw = [CapW5]::Grab($h)
        $img = [CapW5]::Extract($raw)
        $f = Join-Path $out ($p[0] + ".png")
        $img.Save($f, [System.Drawing.Imaging.ImageFormat]::Png)
        $raw.Dispose(); $img.Dispose()
        $files += $f
        "saved $f"
    }
} finally {
    Write-Preview $null
}
