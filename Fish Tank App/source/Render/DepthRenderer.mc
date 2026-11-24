import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Pseudo-3D Pixel Art: a tank box seen in perspective. Back wall, receding floor with
// pebbles that grow toward the viewer, dim small back-layer fish, big front fish and
// swaying foreground plants. All 2D layers, no real 3D.
class DepthRenderer extends AquariumRenderer {
    const WX0 = 72;
    const WX1 = 318;
    const WY0 = 58;
    const WY1 = 252;

    function initialize() {
        AquariumRenderer.initialize();
        floorY = 318;
        layered = true;
        airX = 296;
    }

    function bounds(f, eng) {
        if (f.z < 0.5) { return [WX0 + 24, WY0 + 28, WX1 - 24, WY1 - 6]; }
        var r = HabitatSystem.room(eng);
        return [65 - r, 92, 325 + r, 296];
    }

    function slotBottom(eng, slot) {
        return 304;
    }

    function restY() {
        return 312;
    }

    function fishScale(f) {
        if (f.z < 0.5) { return 2; }
        var st = f.stage();
        if (st == 0) { return 2; }
        if (st == 2 && f.giant()) { return 5; }
        return st == 1 ? 3 : 4;
    }

    // outer water, back wall, rays, floor (2 parts), glass edges, plants..., decor..., dirt
    function stageCount(eng) {
        return 6 + HabitatSystem.plantCount(eng) + decorCount(eng) + 1;
    }

    function drawStage(dc, eng, i) {
        var th = ThemeDatabase.PAL[eng.theme];
        var top = th[0];
        var wTop = PixelKit.shade(top, 0.35);
        var wBot = PixelKit.shade(th[1], 0.45);
        var plants = HabitatSystem.plantCount(eng);
        if (i == 0) {
            PixelKit.gradientPixel(dc, PixelKit.tint(top, 0.06), th[1], 0, 0, dc.getWidth(), dc.getHeight(), 3);
        } else if (i == 1) {
            PixelKit.gradientPixel(dc, wTop, wBot, WX0, WY0, WX1, WY1, 2);
        } else if (i == 2) {
            PixelKit.lightRays(dc, wTop, wBot, 150, 2);
        } else if (i == 3) {
            drawFloor(dc, th, WY1, 300, 11);
        } else if (i == 4) {
            drawFloor(dc, th, 300, dc.getHeight(), 12);
        } else if (i == 5) {
            drawEdges(dc, PixelKit.tint(top, 0.3));
        } else if (i < 6 + plants) {
            var k = i - 6;
            var c = ThemeDatabase.plantColors(eng.theme, k);
            var dim = [PixelKit.lerpColor(c[0], wBot, 0.45), PixelKit.lerpColor(c[1], wBot, 0.45), PixelKit.lerpColor(c[2], wBot, 0.45)];
            var px = WX0 + 16 + (ThemeDatabase.PLANT_X[k] - 36) * (WX1 - WX0 - 32) / 320;
            PlantKit.draw(dc, ThemeDatabase.KINDS[eng.theme][k], px, WY1 + 4, ThemeDatabase.PLANT_H[k] * 6 / 10, 2, dim, k, 0.0);
        } else if (i < 6 + plants + decorCount(eng)) {
            drawDecorItem(dc, eng, i - 6 - plants, 3, 304);
        } else {
            drawDirt(dc, eng, 2);
        }
    }

    // Floor rows between y0 and y1; blocks grow toward the viewer.
    function drawFloor(dc, th, y0, y1, seed) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var rng = new Rng(seed);
        var sandBack = PixelKit.shade(th[2], 0.55);
        var pc = [th[3], th[4], th[5]];
        var y = y0;
        while (y < y1) {
            var tt = (y - WY1) / ((h - WY1) * 1.0);
            var bs = 2 + (tt * 4).toNumber();
            var spread = (y - WY1) * WX0 / 75;
            var lx = WX0 - spread;
            var rx = WX1 + spread;
            if (lx < 0) { lx = 0; }
            if (rx > w) { rx = w; }
            PixelKit.rect(dc, PixelKit.lerpColor(sandBack, th[2], tt), lx, y, rx - lx, bs);
            var cnt = (rx - lx) / (bs * 5);
            var rowPc = [PixelKit.shade(pc[0], (1.0 - tt) * 0.5), PixelKit.shade(pc[1], (1.0 - tt) * 0.5), PixelKit.shade(pc[2], (1.0 - tt) * 0.5)];
            for (var k = 0; k < cnt; k++) {
                var px = lx + rng.next(rx - lx) / bs * bs;
                PixelKit.rect(dc, rowPc[rng.next(3)], px, y, bs * (1 + rng.next(2)), bs);
            }
            y += bs;
        }
    }

    function drawEdges(dc, edge) {
        PixelKit.rect(dc, edge, WX0, WY0, WX1 - WX0, 2);
        PixelKit.rect(dc, edge, WX0, WY0, 2, WY1 - WY0);
        PixelKit.rect(dc, edge, WX1 - 2, WY0, 2, WY1 - WY0);
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < 30; i++) {
            dc.fillRectangle(WX0 - i * 3, WY0 - i * 3, 2, 2);
            dc.fillRectangle(WX1 + i * 3 - 2, WY0 - i * 3, 2, 2);
            dc.fillRectangle(WX0 - i * 3, WY1 + i * 3, 2, 2);
            dc.fillRectangle(WX1 + i * 3 - 2, WY1 + i * 3, 2, 2);
        }
    }

    function drawFish(dc, f, eng) {
        drawSpriteFish(dc, f, fishScale(f), f.z < 0.5 ? 2 + eng.theme : 0);
    }

    // Foreground plants drawn over the fish every frame, gently swaying.
    function drawFront(dc, eng) {
        var kinds = ThemeDatabase.KINDS[eng.theme];
        var sway = eng.t * 1.1;
        PlantKit.draw(dc, kinds[0], 34, 400, 150, 4, ThemeDatabase.plantColors(eng.theme, 0), 3, sway);
        PlantKit.draw(dc, kinds[1], 360, 400, 115, 4, ThemeDatabase.plantColors(eng.theme, 1), 5, sway + 1.0);
    }
}
