# Renders Fish Tank states in the Connect IQ simulator and saves each as a PNG.
# Each shot is "name,style,theme,mode[,screen]": style 0-2 (Modern, Minimal, Pseudo-3D),
# theme 0-5 (Tropical, Freshwater, Fantasy, Mixed, Frozen, Deep), mode 0 play,
# 1 style picker, 2 theme picker, 3 gift card, 4 run card, 5 build; screen = a menu screen
# opened on top (see source\UI\PreviewScreens.mc).
#   capture.ps1 -Shots "modern-mixed,0,3,0"
#   capture.ps1 -Matrix          (all style x theme combos + pickers + cards)
#   capture.ps1 -Screens         (every menu screen and mini-game)
# Rewrites source\Preview.mc while running and always switches it back to ON = false.
param(
    [string[]]$Shots = @(),
    [switch]$Matrix,
    [switch]$Screens,
    [string]$Device = "fr165",
    [string]$OutDir = "docs\screens",
    [string]$Key = "$env:USERPROFILE\.Garmin\ConnectIQ\developer_key.der"
)
$ErrorActionPreference = "Continue"
$proj = Resolve-Path (Join-Path $PSScriptRoot "..")
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
. (Join-Path $PSScriptRoot "CapWin.ps1")
$out = Join-Path $proj $OutDir
New-Item -ItemType Directory -Force $out | Out-Null

if ($Matrix) {
    $styles = @("modern", "minimal", "depth")
    $themes = @("tropical", "fresh", "fantasy", "mixed", "frozen", "deep")
    $Shots = @()
    for ($s = 0; $s -lt 3; $s++) {
        for ($t = 0; $t -lt 6; $t++) { $Shots += "$($styles[$s])-$($themes[$t]),$s,$t,0" }
    }
    $Shots += "picker-style,0,3,1", "picker-theme,2,0,2", "card-gift,0,3,3", "card-run,0,3,4", "build,0,0,5"
}
if ($Screens) {
    $names = @("", "menu", "shop-fish", "inventory", "fish-profile", "quests", "activity", "expedition",
               "games", "fishdex", "trophies", "league", "profile", "game-bubble", "game-dive", "game-race",
               "settings", "shop-decor")
    for ($i = 1; $i -lt $names.Count; $i++) { $Shots += "screen-$($names[$i]),0,3,0,$i" }
}

function Write-Preview($p) {
    $on = if ($p) { "true" } else { "false" }
    if (-not $p) { $p = @("", 0, 3, 0, 0) }
    $screen = if ($p.Count -gt 4) { $p[4] } else { 0 }
@"
// Screenshot mode. tools/capture.ps1 rewrites these values while it runs and always
// switches ON back to false. With ON = true the app skips the save file and shows a
// populated demo tank in the chosen style/theme.
module Preview {
    const ON = $on;
    const STYLE = $($p[1]);   // 0 Modern Pixel, 1 Minimalist, 2 Pseudo-3D
    const THEME = $($p[2]);   // 0 Tropical, 1 Freshwater, 2 Fantasy, 3 Mixed, 4 Frozen, 5 Deep
    const MODE = $($p[3]);    // 0 play, 1 style picker, 2 theme picker, 3 gift card, 4 run card, 5 build, 6 event card, 7-8 long-text cards, 9-11 tutorial coach
    const SCREEN = $screen;  // 0 tank, else a screen opened on top (PreviewScreens.open)
}
"@ | Set-Content -Encoding ascii (Join-Path $proj "source\Preview.mc")
}

$Shots = @($Shots | ForEach-Object { $_ -split ";" } | Where-Object { $_ })
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
        "saved $f"
    }
} finally {
    Write-Preview $null
}
