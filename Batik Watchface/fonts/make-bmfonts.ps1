# Converts Pridi TTFs into Connect IQ BMFont (.fnt + .png) resources, one set per screen size.
# Only the glyphs the watch face draws are included, to keep app memory low.
param([string]$Project = "D:\Garmin\Batik Watchface\nusantara-kawung")
Add-Type -AssemblyName System.Drawing
$here = Split-Path $MyInvocation.MyCommand.Path

$sets = @(
    @{ id = "PridiSmall"; file = "Pridi-Medium.ttf";   scale = 0.105; chars = " 0123456789:%.-/$([char]0xB0)ABCDEFGHIJKLMNOPQRSTUVWXYZkbpm" },
    @{ id = "PridiTime";  file = "Pridi-SemiBold.ttf"; scale = 0.24;  chars = "0123456789:" },
    @{ id = "PridiAod";   file = "Pridi-Light.ttf";    scale = 0.30;  chars = "0123456789:" }
    @{ id = "PridiRing";  file = "Pridi-Medium.ttf";   scale = 0.115; chars = "0123456789.-:%$([char]0xB0)ABCDEFGHIJKLMNOPQRSTUVWXYZ" },
    @{ id = "PridiLabel"; file = "Pridi-Medium.ttf";   scale = 0.078; chars = " 0123456789/ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
)
$screens = @("round-218x218", "round-240x240", "round-260x260", "round-280x280", "round-360x360", "round-390x390", "round-416x416", "round-454x454", "round-466x466", "semioctagon-166x166", "semioctagon-176x176", "rectangle-448x486")

function New-BmFont($ttf, [int]$px, [string]$chars, [string]$outBase) {
    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    $pfc.AddFontFile($ttf)
    $fam = $pfc.Families[0]
    $font = New-Object System.Drawing.Font($fam, [single]$px, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    $cellH = [int][math]::Ceiling($font.GetHeight()) + 4
    $pad = [int][math]::Ceiling($px * 0.08) + 2

    $probe = New-Object System.Drawing.Bitmap 1, 1
    $pg = [System.Drawing.Graphics]::FromImage($probe)
    $glyphs = @()
    foreach ($ch in $chars.ToCharArray()) {
        $adv = $pg.MeasureString([string]$ch, $font, 1000, $fmt).Width
        if ($ch -eq ' ') { $adv = $px * 0.28 }
        $w = [int][math]::Ceiling($adv) + 2 * $pad
        $bmp = New-Object System.Drawing.Bitmap $w, $cellH
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawString([string]$ch, $font, [System.Drawing.Brushes]::White, [single]$pad, [single]2, $fmt)
        $g.Dispose()
        $glyphs += @{ ch = $ch; bmp = $bmp; adv = [int][math]::Round($adv) }
    }

    # Crop rows to the union of inked pixels (drops Pridi's tall Thai ascent/descent space).
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
        $src = New-Object System.Drawing.Rectangle 0, $top, $gl.bmp.Width, $lineH
        $ag.DrawImage($gl.bmp, (New-Object System.Drawing.Rectangle $x, 0, $gl.bmp.Width, $lineH), $src, [System.Drawing.GraphicsUnit]::Pixel)
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
}

foreach ($s in $screens) {
    $dir = Join-Path (Join-Path $Project ("resources-" + $s)) "fonts"
    $wh = ($s -split "-")[1] -split "x"
    $minDim = [math]::Min([int]$wh[0], [int]$wh[1])
    New-Item -ItemType Directory -Force $dir | Out-Null
    $xml = @("<fonts>")
    foreach ($set in $sets) {
        $px = [math]::Max(9, [int][math]::Round($minDim / 2 * $set.scale))
        $name = "$($set.id.ToLower())"
        New-BmFont (Join-Path $here $set.file) $px $set.chars (Join-Path $dir $name)
        $xml += "    <font id=`"$($set.id)`" filename=`"$name.fnt`" antialias=`"true`"/>"
    }
    $xml += "</fonts>"
    [IO.File]::WriteAllLines((Join-Path $dir "fonts.xml"), $xml)
    "built $dir"
}
