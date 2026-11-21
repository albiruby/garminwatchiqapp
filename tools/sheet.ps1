# Builds a contact sheet from docs\screens\*.png and reports the lit-pixel share of the
# always-on shots (aod-*), measured inside the round display.
#   sheet.ps1 [-Out docs\contact-sheet.png] [-Cols 5]
param(
    [string]$Dir = "docs\screens",
    [string]$Out = "docs\contact-sheet.png",
    [int]$Cols = 5
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$proj = Resolve-Path (Join-Path $PSScriptRoot "..")
$files = Get-ChildItem (Join-Path $proj $Dir) -Filter *.png | Sort-Object Name

# Locate the display: the simulator draws it as a 390 px circle; find its centre as the
# middle of the non-transparent device body's widest black run near the vertical middle.
function Find-Screen($bm) {
    $cx = [int]($bm.Width / 2)
    # scan down the centre column for the first and last near-black display pixels
    $top = -1; $bottom = -1
    for ($y = 0; $y -lt $bm.Height; $y++) {
        $c = $bm.GetPixel($cx, $y)
        if ($c.A -gt 0 -and $c.R + $c.G + $c.B -lt 12) { if ($top -lt 0) { $top = $y }; $bottom = $y }
    }
    return @($cx, [int](($top + $bottom) / 2))
}

$cell = 260; $label = 22
$rows = [Math]::Ceiling($files.Count / $Cols)
$sheet = New-Object System.Drawing.Bitmap ($Cols * $cell), ($rows * ($cell + $label))
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(24, 24, 24)); $g.InterpolationMode = "HighQualityBicubic"
$font = New-Object System.Drawing.Font "Segoe UI", 9
$i = 0
$script:collisions = 0
foreach ($f in $files) {
    $bm = [System.Drawing.Bitmap]::FromFile($f.FullName)
    $sc = Find-Screen $bm
    $src = New-Object System.Drawing.Rectangle ($sc[0] - 205), ($sc[1] - 205), 410, 410
    $x = ($i % $Cols) * $cell; $y = [Math]::Floor($i / $Cols) * ($cell + $label)
    $g.DrawImage($bm, (New-Object System.Drawing.Rectangle ($x + 5), ($y + 5), ($cell - 10), ($cell - 10)), $src, "Pixel")
    $g.DrawString($f.BaseName, $font, [System.Drawing.Brushes]::Gray, ($x + 8), ($y + $cell - 2))
    # LayoutAudit outlines collisions in pure red, a colour the face never uses
    $red = 0
    for ($yy = -195; $yy -le 195; $yy += 1) { for ($xx = -195; $xx -le 195; $xx += 1) {
        $c = $bm.GetPixel($sc[0] + $xx, $sc[1] + $yy)
        if ($c.R -ge 235 -and $c.G -le 20 -and $c.B -le 20) { $red++ } } }
    if ($red -gt 0) { "{0}: COLLISION ({1} red audit pixels)" -f $f.BaseName, $red; $script:collisions++ }
    if ($f.BaseName -like "aod-*") {
        $lit = 0; $all = 0
        for ($yy = -195; $yy -le 195; $yy++) { for ($xx = -195; $xx -le 195; $xx++) {
            if ($xx * $xx + $yy * $yy -gt 190 * 190) { continue }
            $all++; $c = $bm.GetPixel($sc[0] + $xx, $sc[1] + $yy)
            if ([Math]::Max($c.R, [Math]::Max($c.G, $c.B)) -gt 16) { $lit++ } } }
        "{0}: lit pixels {1:P1} of display" -f $f.BaseName, ($lit / $all)
    }
    $bm.Dispose(); $i++
}
$g.Dispose()
$o = Join-Path $proj $Out
$sheet.Save($o, [System.Drawing.Imaging.ImageFormat]::Png); $sheet.Dispose()
"sheet $o"
"layout audit: {0} of {1} shots with collisions" -f $script:collisions, $files.Count
