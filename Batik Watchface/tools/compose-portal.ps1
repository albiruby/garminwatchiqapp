# Portal-ready images: hero (1440x720), cover (500x500, <300 KB) and screen images (<150 KB JPG).
$root = Join-Path $PSScriptRoot "..\nusantara-kawung\docs"
$out = Join-Path $root "store"
New-Item -ItemType Directory -Force $out | Out-Null
Add-Type -AssemblyName System.Drawing
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($f in "Pridi-SemiBold.ttf", "Pridi-Medium.ttf", "Pridi-Light.ttf") { $pfc.AddFontFile((Join-Path $PSScriptRoot "..\fonts\$f")) }
function Fam($n) { $pfc.Families | Where-Object { $_.Name -eq $n } | Select-Object -First 1 }
function F($n, $px) { New-Object System.Drawing.Font((Fam $n), [single]$px, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel) }
$gold = [System.Drawing.Color]::FromArgb(217, 174, 79); $cream = [System.Drawing.Color]::FromArgb(246, 231, 190); $muted = [System.Drawing.Color]::FromArgb(150, 128, 92)

function Canvas($w, $h) {
    $bm = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bm)
    $g.SmoothingMode = "AntiAlias"; $g.InterpolationMode = "HighQualityBicubic"; $g.TextRenderingHint = "AntiAliasGridFit"
    $r = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $g.FillRectangle((New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, ([System.Drawing.Color]::FromArgb(20, 14, 8)), ([System.Drawing.Color]::FromArgb(5, 4, 3)), 90), $r)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse(-$w * 0.2, $h * 0.15, $w * 1.4, $h * 1.1)
    $gl = New-Object System.Drawing.Drawing2D.PathGradientBrush $p
    $gl.CenterColor = [System.Drawing.Color]::FromArgb(45, 217, 174, 79); $gl.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.FillPath($gl, $p)
    return @($bm, $g)
}
function Txt($g, $s, $font, $c, $x, $y) { $g.DrawString($s, $font, (New-Object System.Drawing.SolidBrush $c), [single]$x, [single]$y) }
function SaveJpg($bm, $path, $maxBytes) {
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    foreach ($q in 92, 90, 88, 86, 84, 82, 80, 78, 76, 74, 72, 70, 68, 66, 64, 62, 60, 56, 52) {
        $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$q)
        $bm.Save($path, $codec, $ep)
        $size = (Get-Item $path).Length
        if ($size -le $maxBytes) { break }
    }
    if ($size -gt $maxBytes) { throw "$path still $size bytes" }
    "saved {0,-34} {1}x{2}  {3:N0} bytes  (q{4})" -f (Split-Path $path -Leaf), $bm.Width, $bm.Height, $size, $q
}

# Hero 1440x720: three Living Pattern stages fanned out, title on the right
$c = Canvas 1440 720; $g = $c[1]
$shots = "01-main-fr165.png", "01-main-parang-fr165.png", "01-main-megamendung-fr165.png"
$xs = 40, 290, 540
for ($i = 0; $i -lt 3; $i++) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $root "mockups\$($shots[$i])"))
    $h = 640; $w = [int]($img.Width * $h / $img.Height)
    $g.DrawImage($img, $xs[$i], 40, $w, $h); $img.Dispose()
}
Txt $g "LIVING BATIK WATCH FACE" (F "Pridi Medium" 22) $muted 960 200
Txt $g "NUSANTARA" (F "Pridi SemiBold" 78) $gold 950 236
Txt $g "Three batik motifs that" (F "Pridi Light" 34) $cream 960 352
Txt $g "bloom with your daily steps" (F "Pridi Light" 34) $cream 960 394
Txt $g "Kawung  ·  Parang  ·  Mega Mendung" (F "Pridi Medium" 22) $gold 962 466
Txt $g "34 metrics  ·  6 colorways  ·  64 watches" (F "Pridi Medium" 22) $muted 962 502
SaveJpg $c[0] (Join-Path $out "HERO_1440x720.jpg") 1900000; $g.Dispose(); $c[0].Dispose()

# Cover 500x500: the three motifs, Kawung in front, name underneath
$c = Canvas 500 500; $g = $c[1]
function Watch($g, $file, $cx, $top, $h) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $root "mockups\$file"))
    $w = [int]($img.Width * $h / $img.Height)
    $g.DrawImage($img, [int]($cx - $w / 2), $top, $w, $h); $img.Dispose()
}
Watch $g "01-main-parang-fr165.png" 128 62 320
Watch $g "01-main-megamendung-fr165.png" 372 62 320
Watch $g "01-main-fr165.png" 250 18 380
$fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = "Center"
$g.DrawString("NUSANTARA", (F "Pridi SemiBold" 46), (New-Object System.Drawing.SolidBrush $gold), [single]250, [single]392, $fmt)
$g.DrawString("LIVING BATIK  ·  KAWUNG  ·  PARANG  ·  MEGA MENDUNG", (F "Pridi Medium" 14), (New-Object System.Drawing.SolidBrush $cream), [single]250, [single]452, $fmt)
SaveJpg $c[0] (Join-Path $out "COVER_500x500.jpg") 250000; $g.Dispose(); $c[0].Dispose()

# Screen images: store PNGs re-encoded as JPG under 150 KB
$n = 1
foreach ($p in Get-ChildItem (Join-Path $root "store\master\*.png") | Sort-Object Name) {
    # 1440x900 keeps quality high while staying well under the 150 KB limit
    $img = [System.Drawing.Image]::FromFile($p.FullName)
    $bm = New-Object System.Drawing.Bitmap 1440, 900
    $g = [System.Drawing.Graphics]::FromImage($bm); $g.InterpolationMode = "HighQualityBicubic"; $g.DrawImage($img, 0, 0, 1440, 900); $g.Dispose(); $img.Dispose()
    $name = "SCREEN_{0}_{1}.jpg" -f $n, ($p.BaseName -replace "^\d-", "")
    SaveJpg $bm (Join-Path $out $name) 120000; $bm.Dispose(); $n++
}
