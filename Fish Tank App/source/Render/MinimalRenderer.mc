import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Minimalist Aquarium: smooth gradient, a soft sand mound, a few thin stems and
// vector fish. Slower, calmer swimming.
class MinimalRenderer extends AquariumRenderer {
    const RATIO = [0.55, 0.85, 0.36, 0.55, 0.6, 0.6, 0.5, 0.9, 0.2, 0.7];
    const SAND_CY = 470;
    const SAND_RX = 300;
    const SAND_RY = 170;

    function initialize() {
        AquariumRenderer.initialize();
        floorY = 300;
        speedMul = 0.7;
        airX = 300;
    }

    function rimY(x) {
        var u = (x - 195) / (SAND_RX * 1.0);
        return SAND_CY - (SAND_RY * Math.sqrt(1.0 - u * u)).toNumber();
    }

    function restY() {
        return 304;
    }

    function hitHalf(f) {
        var s = fishSize(f);
        return [s * 1.2, s * 0.8];
    }

    function fishSize(f) {
        var s = [11, 15, 18][f.stage()];
        if (f.giant() && f.stage() == 2) { s = 22; }
        if (f.evo) { s += 2; }
        return s;
    }

    function slotBottom(eng, slot) {
        return rimY(ItemDatabase.SLOT_X[slot]) + 14;
    }

    // Classic pieces get flat vector shapes; plant decor uses the stem/plant drawer;
    // the newer pixel pieces are drawn small.
    function decorMinimal(dc, id, x, bottom) {
        if (id <= 3) {
            decorShape(dc, id, x, bottom);
        } else if (ItemDatabase.DECOR_KIND[id] == 1) {
            plant(dc, ItemDatabase.DECOR_ARG[id], x, bottom, 46, ItemDatabase.DECOR_COLS[id], id);
        } else {
            drawDecorAt(dc, id, x, bottom, 2);
        }
    }

    // water, plants..., sand + decor, dirt
    function stageCount(eng) {
        return 1 + HabitatSystem.plantCount(eng) + 2;
    }

    function drawStage(dc, eng, i) {
        var th = ThemeDatabase.PAL[eng.theme];
        var plants = HabitatSystem.plantCount(eng);
        if (i == 0) {
            PixelKit.gradientSmooth(dc, PixelKit.shade(th[0], 0.3), PixelKit.shade(th[1], 0.3), 0, dc.getHeight(), dc.getWidth());
            return;
        }
        if (i <= plants) {
            var k = i - 1;
            var x = ThemeDatabase.PLANT_X[k];
            plant(dc, ThemeDatabase.KINDS[eng.theme][k], x, rimY(x) + 8, ThemeDatabase.PLANT_H[k], ThemeDatabase.plantColors(eng.theme, k), k);
            return;
        }
        if (i == plants + 1) {
            dc.setColor(PixelKit.shade(th[4], 0.15), Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(195, SAND_CY - 4, SAND_RX, SAND_RY);
            dc.setColor(PixelKit.shade(th[2], 0.25), Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(195, SAND_CY, SAND_RX, SAND_RY);
            var dl = decorList(eng);
            for (var d = 0; d < dl.size(); d++) {
                var x = ItemDatabase.SLOT_X[dl[d][0]];
                decorMinimal(dc, dl[d][1], x, rimY(x) + 14);
            }
            return;
        }
        if (eng.clean < 80) {
            var rng = new Rng(99);
            var cnt = ((80 - eng.clean) * 1.2).toNumber();
            dc.setColor(0x4F7A3A, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < cnt; s++) {
                dc.fillCircle(25 + rng.next(340), 50 + rng.next(250), 1 + rng.next(2));
            }
        }
    }

    function plant(dc, kind, x, baseY, h, cols, seed) {
        if (kind == PlantKit.CRYSTAL) {
            var specs = [[-12, 0.6, 7], [0, 1.0, 9], [12, 0.45, 6]];
            for (var k = 0; k < 3; k++) {
                var sp = specs[k];
                var cx = x + sp[0];
                var top = baseY - (h * sp[1]).toNumber();
                dc.setColor(cols[0], Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[cx - sp[2], baseY], [cx, top], [cx + sp[2], baseY]]);
                dc.setColor(cols[2], Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[cx - sp[2], baseY], [cx, top], [cx, baseY]]);
            }
            return;
        }
        if (kind == PlantKit.ROCK) {
            dc.setColor(cols[0], Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(x, baseY, h / 2, h / 3);
            return;
        }
        if (kind == PlantKit.MUSHROOM || kind == PlantKit.TUBE) {
            var xs = [-12, 0, 12];
            var hs = [0.5, 0.8, 0.4];
            for (var k = 0; k < 3; k++) {
                var cx = x + xs[k];
                var top = baseY - (h * hs[k]).toNumber();
                dc.setColor(kind == PlantKit.TUBE ? cols[0] : PixelKit.tint(cols[2], 0.4), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - 4, top, 8, baseY - top, 4);
                dc.setColor(kind == PlantKit.TUBE ? cols[1] : cols[0], Graphics.COLOR_TRANSPARENT);
                if (kind == PlantKit.TUBE) { dc.fillEllipse(cx, top + 2, 3, 2); }
                else { dc.fillEllipse(cx, top, 10, 6); }
            }
            return;
        }
        if (kind == PlantKit.CORAL) {
            dc.setColor(cols[0], Graphics.COLOR_TRANSPARENT);
            for (var k = -1; k <= 1; k++) {
                for (var t = 0.0; t <= 1.0; t += 0.08) {
                    var px = x + k * t * h * 0.35 + Math.sin(t * 5 + k) * 3;
                    var py = baseY - t * h * (k == 0 ? 1.0 : 0.8);
                    dc.fillCircle(px, py, 4 - t * 2);
                }
            }
            return;
        }
        // stems: kelp, grass, sword, anemone
        var stems = 2;
        if (kind == PlantKit.GRASS) { stems = 4; }
        else if (kind == PlantKit.SWORD) { stems = 3; }
        else if (kind == PlantKit.ANEMONE) { stems = 6; h = h / 2; }
        for (var s = 0; s < stems; s++) {
            var off = (s - (stems - 1) / 2.0) * 7;
            var hh = h * (0.7 + 0.3 * ((s * 7 + seed) % 4) / 3.0);
            dc.setColor(s % 2 == 0 ? cols[0] : cols[1], Graphics.COLOR_TRANSPARENT);
            for (var t = 0.0; t <= 1.0; t += 0.05) {
                var px = x + off + Math.sin(t * 2.6 + seed + s) * 6 * t + off * t * 0.6;
                var py = baseY - t * hh;
                dc.fillCircle(px, py, 2.6 - t * 1.2);
                if (kind == PlantKit.SWORD && ((t * 20).toNumber() % 5) == 2) {
                    dc.fillEllipse(px + 5, py, 6, 2);
                }
            }
        }
    }

    function decorShape(dc, id, x, bottom) {
        if (id == 0) {
            dc.setColor(0x5A566C, Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(x - 10, bottom - 10, 14, 10);
            dc.fillEllipse(x + 10, bottom - 10, 14, 10);
            dc.fillEllipse(x, bottom - 20, 20, 8);
        } else if (id == 1) {
            dc.setColor(0x8B5A2B, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x - 16, bottom - 22, 32, 22, 5);
            dc.setColor(0xFFC93C, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 16, bottom - 13, 32, 2);
            dc.fillRectangle(x - 2, bottom - 15, 4, 6);
        } else if (id == 2) {
            dc.setColor(0xB8733A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, bottom - 18, 16);
            dc.fillRectangle(x - 18, bottom - 6, 36, 6);
            dc.setColor(0x173F4F, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, bottom - 18, 8);
        } else {
            dc.setColor(0x8C8AA0, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 18, bottom - 30, 10, 30);
            dc.fillRectangle(x + 8, bottom - 30, 10, 30);
            dc.fillRectangle(x - 8, bottom - 20, 16, 20);
            dc.setColor(0x0B0B14, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x - 4, bottom - 12, 8, 12, 3);
        }
    }

    function drawFish(dc, f, eng) {
        var sp = f.sp;
        var cols = FishDatabase.COLORS[sp];
        var body = cols[0];
        var fin = cols[3];
        var v = f.colorVariant();
        if (v == 1) { body = PixelKit.hueRotate(body, 150); fin = PixelKit.hueRotate(fin, 150); }
        else if (v == 2) { body = PixelKit.lerpColor(body, 0xFFD84A, 0.5); fin = PixelKit.lerpColor(fin, 0xFFD84A, 0.5); }
        else if (v == 3) { body = PixelKit.lerpColor(body, 0xE6EEFF, 0.6); fin = PixelKit.lerpColor(fin, 0xE6EEFF, 0.6); }
        if (f.hp < 50) {
            body = PixelKit.lerpColor(body, 0x8C96A8, 0.45);
            fin = PixelKit.lerpColor(fin, 0x8C96A8, 0.45);
        }
        var size = fishSize(f);
        var shape = FishDatabase.SHAPE[sp];
        var x = f.x;
        var y = f.y + Math.sin(f.phase * 1.8) * 2;
        var d = f.face;
        var wig = Math.sin(f.phase * 6) * size * 0.12;

        if (shape == FishDatabase.SH_JELLY) {
            y = f.y + Math.sin(f.phase * 1.5) * 6;
            var pts = [];
            for (var a = 0; a <= 8; a++) {
                var ang = Math.PI * a / 8;
                pts.add([x - Math.cos(ang) * size, y - Math.sin(ang) * size * 0.8]);
            }
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(pts);
            dc.setColor(fin, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            for (var k = 0; k < 4; k++) {
                var tx = x - size * 0.6 + k * size * 0.4;
                dc.drawLine(tx, y, tx + wig, y + size * 0.7);
                dc.drawLine(tx + wig, y + size * 0.7, tx - wig, y + size * 1.3);
            }
            dc.setPenWidth(1);
            return;
        }
        if (shape == FishDatabase.SH_RAY) {
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[x + d * size * 1.1, y], [x - d * size * 0.2, y - size * 0.75 + wig],
                            [x - d * size * 0.9, y], [x - d * size * 0.2, y + size * 0.75 - wig]]);
            dc.setColor(fin, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x - d * size * 0.9, y, x - d * size * 1.8, y + wig);
            dc.fillCircle(x + d * size * 0.5, y - 2, 1);
            return;
        }

        if (shape == FishDatabase.SH_EEL) {
            // a wavy ribbon of circles
            dc.setColor(body, Graphics.COLOR_TRANSPARENT);
            for (var k = 0; k < 9; k++) {
                var px = x + d * (size * 1.2 - k * size * 0.3);
                var py = y + Math.sin(f.phase * 4 - k * 0.7) * 3;
                dc.fillCircle(px, py, k == 0 ? 4 : 4 - k * 0.3);
            }
            dc.setColor(0x0B0B14, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + d * size * 1.25, y - 1, 1);
            return;
        }

        var ry = size * RATIO[shape];
        var flow = FishDatabase.TAIL[sp] == FishDatabase.T_FLOW || f.evo;
        var tl = size * (flow ? 1.0 : 0.75);
        var tw = size * (flow ? 0.9 : 0.6);
        var tx = x - d * size * 0.85;
        dc.setColor(fin, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[tx + d * 3, y], [tx - d * tl, y - tw + wig], [tx - d * tl * 0.8, y + wig * 0.5], [tx - d * tl, y + tw + wig]]);
        dc.fillPolygon([[x - d * size * 0.35, y - ry * 0.7], [x + d * size * 0.25, y - ry * 0.8],
                        [x - d * size * 0.2, y - ry - size * (flow ? 0.6 : 0.3)]]);
        dc.setColor(body, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(x, y, size, ry);
        dc.setColor(FishDatabase.ACCENT[sp], Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(x + d * size * 0.15, y, size * 0.12 + 1, ry * 0.8);
        dc.setColor(0x0B0B14, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + d * size * 0.58, y - ry * 0.2, size > 12 ? 2 : 1);
        if (shape == FishDatabase.SH_ANGLER) {
            dc.setColor(fin, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + d * size * 0.2, y - ry, x + d * size * 0.9, y - ry - 8);
            dc.setColor(FishDatabase.ACCENT[sp], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + d * size * 0.95, y - ry - 8, 3);
        } else if (shape == FishDatabase.SH_ROUND) {
            dc.setColor(fin, Graphics.COLOR_TRANSPARENT);
            for (var k = 0; k < 8; k++) {
                var a = Math.PI * 2 * k / 8;
                dc.drawLine(x + Math.cos(a) * size, y + Math.sin(a) * ry, x + Math.cos(a) * (size + 4), y + Math.sin(a) * (ry + 4));
            }
        }
    }

    function drawFood(dc, p) {
        dc.setColor(ItemDatabase.FOOD_COLOR[p[2]], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(p[0], p[1], 2);
    }

    function drawBubble(dc, b) {
        dc.setColor(0x9FD8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(b[0], b[1], b[2] + 1);
    }
}
