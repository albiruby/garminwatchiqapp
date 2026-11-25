import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Modern Pixel Art: 3px blocks everywhere, dithered water bands, light shafts,
// outlined 16-bit sprites.
class ModernRenderer extends AquariumRenderer {
    const B = 3;

    function initialize() {
        AquariumRenderer.initialize();
        floorY = 300;
        airX = 332;
    }

    // water bands (4), rays (3), reef (2), plants..., substrate (4), decor..., dirt (3)
    function stageCount(eng) {
        return 16 + HabitatSystem.plantCount(eng) + decorCount(eng);
    }

    function drawStage(dc, eng, i) {
        var th = ThemeDatabase.PAL[eng.theme];
        var w = dc.getWidth();
        var plants = HabitatSystem.plantCount(eng);
        var decor = decorCount(eng);
        if (i < 4) {
            PixelKit.gradientPixelPart(dc, th[0], th[1], 0, 0, w, floorY + 6, B, i);
        } else if (i < 7) {
            PixelKit.lightRaysShaft(dc, th[0], th[1], 210, B, i - 4);
        } else if (i < 9) {
            drawReefPart(dc, th, w, eng, i - 7);
        } else if (i < 9 + plants) {
            var k = i - 9;
            PlantKit.draw(dc, ThemeDatabase.KINDS[eng.theme][k], ThemeDatabase.PLANT_X[k], floorY + 6,
                ThemeDatabase.PLANT_H[k], B, ThemeDatabase.plantColors(eng.theme, k), k, 0.0);
        } else if (i < 13 + plants) {
            drawSubstratePart(dc, th, w, dc.getHeight(), i - (9 + plants));
        } else if (i < 13 + plants + decor) {
            drawDecorItem(dc, eng, i - (13 + plants), B, floorY + 16);
        } else {
            drawDirtPart(dc, eng, B, i - (13 + plants + decor));
        }
    }

    function drawReefPart(dc, th, w, eng, part) {
        var half = (w / 2) / B * B;
        var start = part == 0 ? 0 : half;
        var end = part == 0 ? half : w;
        dc.setColor(PixelKit.shade(th[1], 0.35), Graphics.COLOR_TRANSPARENT);
        for (var x = start; x < end; x += B) {
            var hh = 26 + (Math.sin(x * 0.021 + eng.theme) * 12 + Math.sin(x * 0.067) * 6).toNumber();
            hh = hh / B * B;
            dc.fillRectangle(x, floorY - hh, B, hh + 8);
        }
    }

    function drawSubstratePart(dc, th, w, h, part) {
        var rng = new Rng(7);
        if (part == 0) { PixelKit.rect(dc, th[2], 0, floorY, w, h - floorY); }
        var half = (w / 2) / B * B;
        for (var x = 0; x < w; x += B) {
            var k = rng.next(3);
            var edge = part == 0 ? (x < half) : (part == 1 && x >= half);
            if (edge) {
                if (k == 0) { PixelKit.rect(dc, th[2], x, floorY - B, B, B); }
                if (rng.next(2) == 0) { PixelKit.rect(dc, th[4], x, floorY, B, B); }
            } else {
                rng.next(2);   // keep the random sequence identical
            }
        }
        var pc = [th[3], th[4], th[5], PixelKit.shade(th[2], 0.2)];
        var hi = [PixelKit.tint(pc[0], 0.3), PixelKit.tint(pc[1], 0.3), PixelKit.tint(pc[2], 0.3), PixelKit.tint(pc[3], 0.3)];
        var drawBlocks = part >= 2;
        var start = part == 2 ? 0 : 85;
        var end = part == 2 ? 85 : 170;
        for (var i = 0; i < 170; i++) {
            var px = rng.next(w) / B * B;
            var py = (floorY + 2 * B + rng.next(h - floorY)) / B * B;
            var ci = rng.next(4);
            var pw = B * (1 + rng.next(3));
            var ph = B * (1 + rng.next(2));
            if (drawBlocks && i >= start && i < end) {
                PixelKit.rect(dc, pc[ci], px, py, pw, ph);
                PixelKit.rect(dc, hi[ci], px, py, B, B);
            }
        }
    }

    function drawFish(dc, f, eng) {
        drawSpriteFish(dc, f, fishScale(f), 0);
    }
}
