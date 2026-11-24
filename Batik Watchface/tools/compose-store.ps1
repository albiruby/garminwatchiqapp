# Builds the four Connect IQ Store preview images from the captures in docs/mockups.
#   1 Main Watch Face   2 Living Pattern   3 Metric Customization   4 Display Modes
param(
    [string]$Shots = (Join-Path $PSScriptRoot "..\nusantara-kawung\docs\mockups"),
    [string]$OutDir = (Join-Path $PSScriptRoot "..\nusantara-kawung\docs\store\master")
)
Add-Type -AssemblyName System.Drawing
$W = 1600; $H = 1000
$fonts = Join-Path $PSScriptRoot "..\fonts"
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($f in "Pridi-SemiBold.ttf", "Pridi-Medium.ttf", "Pridi-Light.ttf") { $pfc.AddFontFile((Join-Path $fonts $f)) }
function Fam($name) { $pfc.Families | Where-Object { $_.Name -eq $name } | Select-Object -First 1 }
$semi = Fam "Pridi SemiBold"; $med = Fam "Pridi Medium"; $light = Fam "Pridi Light"
function F($fam, $px) { New-Object System.Drawing.Font($fam, [single]$px, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel) }

$gold = [System.Drawing.Color]::FromArgb(217, 174, 79)
$cream = [System.Drawing.Color]::FromArgb(246, 231, 190)
$muted = [System.Drawing.Color]::FromArgb(150, 128, 92)

function New-Canvas {
    $bm = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bm)
    $g.SmoothingMode = "AntiAlias"; $g.InterpolationMode = "HighQualityBicubic"; $g.TextRenderingHint = "AntiAliasGridFit"
    $rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(18, 13, 8)), ([System.Drawing.Color]::FromArgb(5, 4, 3)), 90
    $g.FillRectangle($bg, $rect)
    # faint gold glow behind the watches
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(-200, 260, $W + 400, 900)
    $glow = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $glow.CenterColor = [System.Drawing.Color]::FromArgb(40, 217, 174, 79)
    $glow.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.FillPath($glow, $path)
    return @($bm, $g)
}
function Text($g, $s, $font, $color, $x, $y, [string]$align = "Center") {
    $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = $align
    $g.DrawString($s, $font, (New-Object System.Drawing.SolidBrush $color), [single]$x, [single]$y, $fmt)
}
function Header($g, $kicker, $title, $sub) {
    Text $g $kicker (F $med 22) $muted ($W / 2) 46
    Text $g $title (F $semi 58) $gold ($W / 2) 76
    Text $g $sub (F $light 26) $cream ($W / 2) 152
}
# Draw images in a centred row, each fitted into (cellW x maxH), captions underneath.
function Row($g, $items, $top, $maxH, $cellW) {
    $n = $items.Count; $gap = 24
    $x0 = ($W - ($n * $cellW + ($n - 1) * $gap)) / 2
    for ($i = 0; $i -lt $n; $i++) {
        $it = $items[$i]
        $img = [System.Drawing.Image]::FromFile((Join-Path $Shots $it[0]))
        $s = [math]::Min($cellW / $img.Width, $maxH / $img.Height)
        $w = [int]($img.Width * $s); $h = [int]($img.Height * $s)
        $cx = $x0 + $i * ($cellW + $gap) + $cellW / 2
        $g.DrawImage($img, [int]($cx - $w / 2), [int]($top + ($maxH - $h) / 2), $w, $h)
        $img.Dispose()
        Text $g $it[1] (F $semi 26) $gold $cx ($top + $maxH + 14)
        if ($it.Count -gt 2) { Text $g $it[2] (F $light 20) $cream $cx ($top + $maxH + 48) }
    }
}
function Save($bm, $g, $name) {
    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $p = Join-Path $OutDir $name
    $bm.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bm.Dispose(); "saved $p"
}

# 1 Main Watch Face
$c = New-Canvas; $g = $c[1]
Header $g "NUSANTARA  ·  LIVING BATIK" "Three motifs, one watch face" "Pick Kawung, Parang or Mega Mendung in Garmin Connect"
Row $g @(
    @("01-main-fr165.png", "Kawung", "four-petal lattice"),
    @("01-main-parang-fr165.png", "Parang", "S-blades in diagonal bands"),
    @("01-main-megamendung-fr165.png", "Mega Mendung", "layered Cirebon clouds")
) 230 640 460
Save $c[0] $g "1-main-watch-face.png"

# 2 Living Pattern
$c = New-Canvas; $g = $c[1]
Header $g "LIVING PATTERN" "The motif grows with your day" "Every motif fills in with your daily steps  ·  shown here: Kawung"
Row $g @(
    @("02-living-1-dormant.png", "Dormant", "0%  ·  fine line work"),
    @("02-living-2-awakening.png", "Awakening", "25%  ·  gilded outlines"),
    @("02-living-3-blooming.png", "Blooming", "50%  ·  petals fill with gold"),
    @("02-living-4-complete.png", "Complete", "100%  ·  gold ring closes")
) 230 640 340
Save $c[0] $g "2-living-pattern.png"

# 3 Metric Customization
$c = New-Canvas; $g = $c[1]
Header $g "METRIC CUSTOMIZATION" "Your motif, your colours, your data" "3 motifs  ·  6 colorways  ·  34 metrics across 4 slots"
Row $g @(
    @("03-custom-a-kawung-indigo.png", "Kawung  ·  Silver Indigo", "Weather  ·  Body Battery  ·  Intensity  ·  HR"),
    @("03-custom-b-parang-red-digital.png", "Parang  ·  Cirebon Red", "Date  ·  Stress  ·  Calories  ·  Pulse Ox"),
    @("03-custom-c-megamendung-sogan.png", "Mega Mendung  ·  Sogan", "Sunrise  ·  5K  ·  Weekly Run  ·  Distance")
) 230 640 460
Save $c[0] $g "3-metric-customization.png"

# 4 Display Modes
$c = New-Canvas; $g = $c[1]
Header $g "DISPLAY MODES" "Made for every Garmin screen" "Rendering adapts to the panel, not just the size"
Row $g @(
    @("04-mode-amoled-digital-venu3.png", "AMOLED", "Venu 3  ·  Kawung"),
    @("04-mode-aod-venu3.png", "Always-On", "low-pixel, shifts each minute"),
    @("04-mode-mip-fenix7.png", "MIP", "fenix 7  ·  Parang"),
    @("04-mode-mono-instinct3.png", "Monochrome", "Instinct 3  ·  Mega Mendung"),
    @("04-mode-rect-venux1.png", "Rectangle", "Venu X1  ·  Mega Mendung")
) 240 600 270
Save $c[0] $g "4-display-modes.png"
