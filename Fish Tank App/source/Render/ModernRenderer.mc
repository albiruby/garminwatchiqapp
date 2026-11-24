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

    // water, rays, reef, plants..., substrate, decor..., dirt
    function stageCount(eng) {
        return 3 + HabitatSystem.plantCount(eng) + 1 + decorCount(eng) + 1;
    }

    function drawStage(dc, eng, i) {
        var th = ThemeDatabase.PAL[eng.theme];
        var w = dc.getWidth();
        var plants = HabitatSystem.plantCount(eng);
        if (i == 0) {
            PixelKit.gradientPixel(dc, th[0], th[1], 0, 0, w, floorY + 6, B);
        } else if (i == 1) {
            PixelKit.lightRays(dc, th[0], th[1], 210, B);
        } else if (i == 2) {
            dc.setColor(PixelKit.shade(th[1], 0.35), Graphics.COLOR_TRANSPARENT);
            for (var x = 0; x < w; x += B) {
                var hh = 26 + (Math.sin(x * 0.021 + eng.theme) * 12 + Math.sin(x * 0.067) * 6).toNumber();
                hh = hh / B * B;
                dc.fillRectangle(x, floorY - hh, B, hh + 8);
            }
        } else if (i < 3 + plants) {
            var k = i - 3;
            PlantKit.draw(dc, ThemeDatabase.KINDS[eng.theme][k], ThemeDatabase.PLANT_X[k], floorY + 6,
                ThemeDatabase.PLANT_H[k], B, ThemeDatabase.plantColors(eng.theme, k), k, 0.0);
        } else if (i == 3 + plants) {
            drawSubstrate(dc, th, w, dc.getHeight());
        } else if (i < 4 + plants + decorCount(eng)) {
            drawDecorItem(dc, eng, i - 4 - plants, B, floorY + 16);
        } else {
            drawDirt(dc, eng, B);
        }
    }

    function drawSubstrate(dc, th, w, h) {
        var rng = new Rng(7);
        PixelKit.rect(dc, th[2], 0, floorY, w, h - floorY);
        for (var x = 0; x < w; x += B) {
            var k = rng.next(3);
            if (k == 0) { PixelKit.rect(dc, th[2], x, floorY - B, B, B); }
            if (rng.next(2) == 0) { PixelKit.rect(dc, th[4], x, floorY, B, B); }
        }
        var pc = [th[3], th[4], th[5], PixelKit.shade(th[2], 0.2)];
        var hi = [PixelKit.tint(pc[0], 0.3), PixelKit.tint(pc[1], 0.3), PixelKit.tint(pc[2], 0.3), PixelKit.tint(pc[3], 0.3)];
        for (var i = 0; i < 170; i++) {
            var px = rng.next(w) / B * B;
            var py = (floorY + 2 * B + rng.next(h - floorY)) / B * B;
            var ci = rng.next(4);
            var pw = B * (1 + rng.next(3));
            PixelKit.rect(dc, pc[ci], px, py, pw, B * (1 + rng.next(2)));
            PixelKit.rect(dc, hi[ci], px, py, B, B);
        }
    }

    function drawFish(dc, f, eng) {
        drawSpriteFish(dc, f, fishScale(f), 0);
    }
}
