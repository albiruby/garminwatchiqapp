# Converts the Barlow TTFs in fonts\src into Connect IQ BMFont resources (.fnt + .png)
# for the 390x390 FR165 screen. Only the glyphs PULSEFORM draws are included, and each
# atlas is cropped to the inked rows, so a font's line height equals its visible glyph
# height: text drawn with TEXT_JUSTIFY_VCENTER is centred exactly on its y.
# Adapted from Batik Watchface\fonts\make-bmfonts.ps1.
#   make-fonts.ps1           -> resources\fonts\*.fnt, *.png, fonts.xml
param([string]$Out = "")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$proj = Resolve-Path (Join-Path $PSScriptRoot "..")
$src = Join-Path $proj "fonts\src"
if ($Out -eq "") { $Out = Join-Path $proj "resources\fonts" }

$digits = "0123456789"
$upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
$dot = [string][char]0xB7
# id, file, pixel size, glyphs, extra tracking (px added to each advance),
# outline (stroke width in px; 0 = filled glyphs)
# Numerals come in three looks: solid (Carbon, Signal), outline (Reflective), light (Field).
$num = "$($digits):"
$hero = "$($digits),"   # HORIZON step count
$sets = @(
    @{ id = "TimeL";  file = "BarlowCondensed-SemiBold.ttf"; px = 128; chars = $num; track = 0 },
    @{ id = "TimeM";  file = "BarlowCondensed-SemiBold.ttf"; px = 108; chars = $num; track = 0 },
    @{ id = "TimeS";  file = "BarlowCondensed-SemiBold.ttf"; px = 76;  chars = $num; track = 0 },
    @{ id = "TimeLO"; file = "BarlowCondensed-SemiBold.ttf"; px = 128; chars = $num; track = 2; outline = 3.0 },
    @{ id = "TimeMO"; file = "BarlowCondensed-SemiBold.ttf"; px = 108; chars = $num; track = 2; outline = 2.6 },
    @{ id = "TimeSO"; file = "BarlowCondensed-SemiBold.ttf"; px = 76;  chars = $num; track = 1; outline = 2.0 },
    @{ id = "TimeLL"; file = "BarlowCondensed-Light.ttf";    px = 128; chars = $num; track = 0 },
    @{ id = "TimeML"; file = "BarlowCondensed-Light.ttf";    px = 108; chars = $num; track = 0 },
    @{ id = "TimeSL"; file = "BarlowCondensed-Light.ttf";    px = 76;  chars = $num; track = 0 },
    @{ id = "Hero";   file = "BarlowCondensed-SemiBold.ttf"; px = 100; chars = $hero; track = 0 },
    @{ id = "HeroO";  file = "BarlowCondensed-SemiBold.ttf"; px = 100; chars = $hero; track = 2; outline = 2.6 },
    @{ id = "HeroL";  file = "BarlowCondensed-Light.ttf";    px = 100; chars = $hero; track = 0 },
    @{ id = "TimeAod"; file = "BarlowCondensed-Light.ttf";  px = 84;  chars = "$($digits):";            track = 0 },
    @{ id = "Steps";  file = "Barlow-SemiBold.ttf";          px = 40;  chars = " $($digits),%-";         track = 0 },
    @{ id = "StepsS"; file = "Barlow-SemiBold.ttf";          px = 32;  chars = " $($digits),%-";         track = 0 },
    @{ id = "Value";  file = "BarlowCondensed-SemiBold.ttf"; px = 31;  chars = " $($digits),.-";         track = 0 },
    @{ id = "Text";   file = "BarlowCondensed-Medium.ttf";   px = 23;  chars = " $digits$upper,.%+-/:$dot"; track = 1 },
    @{ id = "Label";  file = "BarlowCondensed-Medium.ttf";   px = 18;  chars = " $digits$upper/%,.+-$dot"; track = 2 }
)

function New-BmFont($ttf, [int]$px, [string]$chars, [int]$track, [double]$outline, [string]$outBase) {
    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    $pfc.AddFontFile($ttf)
    $fam = $pfc.Families[0]
    $style = [System.Drawing.FontStyle]::Regular
    if (-not $fam.IsStyleAvailable($style)) { $style = [System.Drawing.FontStyle]::Bold }
    $font = New-Object System.Drawing.Font($fam, [single]$px, $style, [System.Drawing.GraphicsUnit]::Pixel)
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    $cellH = [int][math]::Ceiling($font.GetHeight()) + 4
    $pad = [int][math]::Ceiling($px * 0.08) + 2

    $probe = New-Object System.Drawing.Bitmap 1, 1
    $pg = [System.Drawing.Graphics]::FromImage($probe)
    $glyphs = @()
    foreach ($ch in $chars.ToCharArray()) {
        $adv = $pg.MeasureString([string]$ch, $font, 1000, $fmt).Width
        if ($ch -eq ' ') { $adv = $px * 0.24 }
        $w = [int][math]::Ceiling($adv) + 2 * $pad
        $bmp = New-Object System.Drawing.Bitmap $w, $cellH
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.Clear([System.Drawing.Color]::Transparent)
        if ($outline -gt 0) {
            # stroked glyph outline (Reflective look)
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddString([string]$ch, $fam, [int]$style, [single]$px, (New-Object System.Drawing.PointF ([single]$pad), ([single]2)), $fmt)
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([single]$outline)
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.DrawPath($pen, $path)
            $pen.Dispose(); $path.Dispose()
        } else {
            $g.DrawString([string]$ch, $font, [System.Drawing.Brushes]::White, [single]$pad, [single]2, $fmt)
        }
        $g.Dispose()
        $glyphs += @{ ch = $ch; bmp = $bmp; adv = [int][math]::Round($adv) + $track }
    }

    # crop rows to the union of inked pixels
    $top = $cellH; $bot = 0
    foreach ($gl in $glyphs) {
        $b = $gl.bmp
        for ($y = 0; $y -lt $b.Height; $y++) {
            for ($x = 0; $x -lt $b.Width; $x++) {
                if ($b.GetPixel($x, $y).A -gt 20) { if ($y -lt $top) { $top = $y }; if ($y -gt $bot) { $bot = $y }; break }
            }
        }
    }
    $top = [math]::Max(0, $top - 1); $bot = [math]::Min($cellH - 1, $bot + 1)
    $lineH = $bot - $top + 1

    [int]$atlasW = 0
    foreach ($gl in $glyphs) { $atlasW += $gl.bmp.Width + 1 }
    $atlas = New-Object System.Drawing.Bitmap ([int]$atlasW), ([int]$lineH)
    $ag = [System.Drawing.Graphics]::FromImage($atlas)
    $ag.Clear([System.Drawing.Color]::Transparent)
    $lines = @()
    $x = 0
    foreach ($gl in $glyphs) {
        $r = New-Object System.Drawing.Rectangle 0, $top, $gl.bmp.Width, $lineH
        $ag.DrawImage($gl.bmp, (New-Object System.Drawing.Rectangle $x, 0, $gl.bmp.Width, $lineH), $r, [System.Drawing.GraphicsUnit]::Pixel)
        $lines += "char id=$([int]$gl.ch) x=$x y=0 width=$($gl.bmp.Width) height=$lineH xoffset=-$pad yoffset=0 xadvance=$($gl.adv) page=0 chnl=15"
        $x += $gl.bmp.Width + 1
        $gl.bmp.Dispose()
    }
    $ag.Dispose()
    $png = Split-Path $outBase -Leaf
    $atlas.Save("$outBase.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $atlas.Dispose()
    $head = @(
        "info face=`"$($fam.Name)`" size=$px bold=0 italic=0 charset=`"`" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1",
        "common lineHeight=$lineH base=$lineH scaleW=$atlasW scaleH=$lineH pages=1 packed=0",
        "page id=0 file=`"$png.png`"",
        "chars count=$($glyphs.Count)"
    )
    [IO.File]::WriteAllLines("$outBase.fnt", ($head + $lines))
    $font.Dispose(); $pg.Dispose(); $probe.Dispose()
    return $lineH
}

New-Item -ItemType Directory -Force $Out | Out-Null
$xml = @("<fonts>")
foreach ($s in $sets) {
    $name = $s.id.ToLower()
    $o = 0.0
    if ($s.ContainsKey("outline")) { $o = [double]$s.outline }
    $h = New-BmFont (Join-Path $src $s.file) $s.px $s.chars $s.track $o (Join-Path $Out $name)
    $xml += "    <font id=`"$($s.id)`" filename=`"$name.fnt`" antialias=`"true`"/>"
    "{0,-8} {1,4}px  line height {2,3}px  ({3})" -f $s.id, $s.px, $h, $s.file
}
$xml += "</fonts>"
[IO.File]::WriteAllLines((Join-Path $Out "fonts.xml"), $xml)
"fonts in $Out"
