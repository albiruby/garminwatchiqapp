import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Overlay drawing: effects, play HUD, style/theme picker, daily reward card.
module AquariumHUD {
    // Action dock geometry, recomputed from the screen size each frame and read by the
    // view's tap handling so hit areas always match what is drawn.
    var BTN_X = [151, 195, 239];
    var BTN_Y = 333;
    var BTN_R = 20;
    const PANEL = 0x0B1226;
    const BORDER = 0x2A4A7A;
    const DIM = 0x8EA3C0;
    const GOLD = 0xFFC93C;
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    // Pixelify Sans bitmap fonts (tools/make-fonts.py): 0 small, 1 medium, 2 large.
    var _fonts = null;

    function font(i) {
        if (_fonts == null) {
            _fonts = [WatchUi.loadResource(Rez.Fonts.PixS), WatchUi.loadResource(Rez.Fonts.PixM), WatchUi.loadResource(Rez.Fonts.PixL)];
        }
        return _fonts[i];
    }

    function icon(dc, rows, x, y, b) {
        PixelKit.drawGrid(dc, rows, SpriteData.ICON_KEYS, SpriteData.ICON_COLS, x, y, b, false);
    }

    function text(dc, x, y, font, s, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, CENTER);
    }

    function bar(dc, x, y, w, h, v, col) {
        PixelKit.rect(dc, 0x1A2238, x, y, w, h);
        var fw = (w * Util.clamp(v, 0, 100) / 100.0).toNumber();
        if (fw > 0) { PixelKit.rect(dc, col, x, y, fw, h); }
    }

    function levelColor(v) {
        if (v < 30) { return 0xFF5A5A; }
        if (v < 60) { return 0xFFC93C; }
        return 0x5EE36A;
    }

    function drawEffects(dc, eng) {
        for (var i = 0; i < eng.parts.size(); i++) {
            var p = eng.parts[i];
            var x = p[0].toNumber();
            var y = p[1].toNumber();
            if (p[6] == 1) { icon(dc, SpriteData.ICON_HEART, x - 7, y - 6, 2); }
            else if (p[6] == 2) { icon(dc, SpriteData.ICON_COIN, x - 8, y - 8, 2); }
            else { PixelKit.rect(dc, p[5], x - 1, y - 1, 3, 3); }
        }
        for (var i = 0; i < eng.pops.size(); i++) {
            var p = eng.pops[i];
            text(dc, p[0], p[1], font(0), p[2], p[4]);
        }
        if (eng.cleanT >= 0) {
            var sp = eng.spongePos();
            var sx = sp[0].toNumber();
            var sy = sp[1].toNumber();
            PixelKit.rect(dc, 0x1A1424, sx - 22, sy - 14, 44, 28);
            PixelKit.rect(dc, 0xFFD84A, sx - 20, sy - 12, 40, 24);
            PixelKit.rect(dc, 0xC9A020, sx - 12, sy - 6, 4, 4);
            PixelKit.rect(dc, 0xC9A020, sx + 4, sy + 2, 4, 4);
            PixelKit.rect(dc, 0x5EE36A, sx - 20, sy + 6, 40, 6);
        }
    }

    function drawPlay(dc, eng, focus) {
        // coins + level
        drawTopBar(dc, eng);

        drawDock(dc, eng, focus);

        if (eng.tutorialActive()) {
            drawCoach(dc, eng);
        } else if (eng.toastT > 0 && eng.toastText != null) {
            drawToast(dc, eng.toastText, eng.toastCol);
        } else if (eng.infoFish != null) {
            drawInfo(dc, eng.infoFish);
        }
    }

    // Feed / Clean / Menu in one rounded dock matching the top pill. Sized from the screen
    // and kept inside the round glass at its bottom edge.
    function drawDock(dc, eng, focus) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cell = 40;
        var gap = 6;
        var pad = 6;
        var dockW = 3 * cell + 2 * gap + 2 * pad;
        var dockH = cell + 2 * pad;
        var cy = (h * 0.855).toNumber();
        var r = w / 2;
        var dy = cy + dockH / 2 - r;
        var half = Math.sqrt((r * r - dy * dy).toFloat()).toNumber() - 8;
        if (dockW / 2 > half) { cy -= (dockW / 2 - half); }   // lift it on tighter screens

        var x0 = w / 2 - dockW / 2;
        var y0 = cy - dockH / 2;
        dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, y0, dockW, dockH, 16);
        dc.setColor(BORDER, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x0, y0, dockW, dockH, 16);

        var icons = [SpriteData.ICON_FEED, SpriteData.ICON_CLEAN, SpriteData.ICON_MENU];
        BTN_Y = cy;
        BTN_R = cell / 2;
        for (var i = 0; i < 3; i++) {
            var cx = x0 + pad + cell / 2 + i * (cell + gap);
            BTN_X[i] = cx;
            if (focus == i) {
                dc.setColor(0x173055, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - cell / 2, cy - cell / 2, cell, cell, 10);
                dc.setPenWidth(2);
                dc.setColor(0x7FE7FF, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(cx - cell / 2, cy - cell / 2, cell, cell, 10);
                dc.setPenWidth(1);
            }
            icon(dc, icons[i], cx - 12, cy - 12, 3);
        }

        // food stock badge on the Feed cell (flakes are unlimited, so no badge)
        var fc = eng.foodCount();
        if (fc >= 0) {
            var s = fc > 99 ? "99" : fc.toString();
            var bw = dc.getTextWidthInPixels(s, font(0)) + 8;
            var bx = BTN_X[0] + cell / 2 - bw + 4;
            var by = cy - cell / 2 - 6;
            dc.setColor(ItemDatabase.FOOD_COLOR[eng.selFood], Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, by, bw, 16, 6);
            dc.setColor(0x0B1226, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + bw / 2, by + 7, font(0), s, CENTER);
        }
    }

    // 1240 -> "1240", 12500 -> "12.5k", 250000 -> "250k": keeps the pill short.
    function compact(n) {
        if (n < 10000) { return n.toString(); }
        if (n < 100000) { return (n / 1000).toString() + "." + ((n % 1000) / 100).toString() + "k"; }
        if (n < 1000000) { return (n / 1000).toString() + "k"; }
        return (n / 1000000).toString() + "M";
    }

    // Coins and level share one centred pill, measured from the real text widths and
    // positioned from the screen size, so it never collides or leaves the round glass.
    function drawTopBar(dc, eng) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var f = font(0);
        var coinStr = compact(eng.coins);
        var lvStr = "LV " + eng.lv.toString();
        var cw = dc.getTextWidthInPixels(coinStr, f);
        var lw = dc.getTextWidthInPixels(lvStr, f);
        var gap = 8;                      // icon->text and text->divider spacing
        var inner = 14 + 5 + cw + gap * 2 + 2 + lw;
        var pillW = inner + 24;
        var pillH = 26;
        var top = (h * 0.075).toNumber();

        // keep inside the circle: chord half-width at the pill's top edge
        var r = w / 2;
        var dy = r - top;
        var half = Math.sqrt((r * r - dy * dy).toFloat()).toNumber() - 6;
        if (pillW / 2 > half) {
            top += (pillW / 2 - half) / 2 + 4;
        }

        var x0 = cx - pillW / 2;
        var mid = top + pillH / 2 - 1;
        dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, top, pillW, pillH, 10);
        // an active event tints the pill border in its color
        var evOn = eng.events != null && eng.events.size() > 0;
        dc.setColor(evOn ? EventSystem.UI[eng.events[0][0]] : BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(evOn ? 2 : 1);
        dc.drawRoundedRectangle(x0, top, pillW, pillH, 10);
        dc.setPenWidth(1);

        var x = x0 + 12;
        icon(dc, SpriteData.ICON_COIN, x, mid - 7, 2);   // 16px icon (8x8 at 2x)
        x += 14 + 5;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, mid, f, coinStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += cw + gap;
        PixelKit.rect(dc, BORDER, x, top + 6, 2, pillH - 12);
        x += 2 + gap;
        dc.setColor(0x7FE7FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, mid, f, lvStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // XP progress: a 2px line just under the pill, as wide as the pill
        var need = ProgressionSystem.need(eng.lv);
        var pct = eng.lv >= ProgressionSystem.MAX_LV ? 100 : eng.xp * 100 / need;
        bar(dc, x0 + 12, top + pillH + 3, pillW - 24, 2, pct, 0x7FE7FF);

        // tank condition: two short bars centred under the XP line
        var by = top + pillH + 12;
        var sat = eng.avgSat();
        PixelKit.rect(dc, ItemDatabase.FOOD_COLOR[0], cx - 46, by - 1, 4, 4);
        bar(dc, cx - 39, by, 32, 3, sat, levelColor(sat));
        PixelKit.rect(dc, 0x9FE3FF, cx + 7, by - 1, 4, 4);
        bar(dc, cx + 14, by, 32, 3, eng.clean, levelColor(eng.clean));
    }

    function drawToast(dc, s, col) {
        var w = dc.getTextWidthInPixels(s, font(0)) + 24;
        if (w > 300) { w = 300; }
        dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(195 - w / 2, 88, w, 32, 12);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(195 - w / 2, 88, w, 32, 12);
        text(dc, 195, 104, font(0), s, col);
    }

    function drawInfo(dc, f) {
        var rar = FishDatabase.RARITY[f.sp];
        dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(95, 80, 200, 72, 14);
        dc.setColor(FishDatabase.RARITY_COLOR[rar], Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(95, 80, 200, 72, 14);
        text(dc, 195, 97, font(0), f.name() + (f.syn ? " +" : ""), FishDatabase.RARITY_COLOR[rar]);
        text(dc, 195, 118, font(0), "LV " + f.level().toString() + " " + f.stageName() + " - " + FishDatabase.PERS_NAME[f.personality()], DIM);
        bar(dc, 115, 138, 50, 5, f.sat, 0xFF9F43);
        bar(dc, 170, 138, 50, 5, f.hap, 0xFF5A7A);
        bar(dc, 225, 138, 50, 5, f.hp, 0x5EE36A);
    }

    // `idx` = style or theme shown, `pos`/`n` = its place among the options offered.
    function drawPicker(dc, eng, mode, idx, pos, n, onboarding) {
        var isStyle = mode == Modes.STYLE;
        var name = isStyle ? CustomizationManager.STYLE_NAME[idx] : ThemeDatabase.NAME[idx];
        var desc = isStyle ? CustomizationManager.STYLE_DESC[idx] : ThemeDatabase.DESC[idx];
        var accent = ThemeDatabase.PAL[eng.theme][9];

        if (onboarding) {
            dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(110, 26, 170, 56, 14);
            text(dc, 195, 44, font(2), "FISH TANK", accent);
            text(dc, 195, 68, font(0), "Pocket Aquarium", DIM);
        }

        PixelKit.rect(dc, 0x060B1A, 0, 250, 390, 140);
        PixelKit.rect(dc, accent, 0, 250, 390, 2);
        var step = isStyle ? "ART STYLE" : "AQUARIUM THEME";
        if (onboarding) { step = (isStyle ? "1/2  " : "2/2  ") + step; }
        text(dc, 195, 272, font(0), step, accent);
        text(dc, 195, 302, font(2), name, 0xFFFFFF);
        text(dc, 195, 330, font(0), desc, DIM);
        text(dc, 46, 302, font(2), "<", accent);
        text(dc, 344, 302, font(2), ">", accent);
        var dx = 195 - (n - 1) * 8;
        for (var i = 0; i < n; i++) {
            PixelKit.rect(dc, i == pos ? accent : BORDER, dx + i * 16 - 3, 352, 6, 6);
        }
        text(dc, 195, 374, font(0), "TAP TO SELECT", DIM);
    }

    // ---- reward / info cards ----------------------------------------------------------
    function drawCard(dc, eng) {
        if (eng.cards.size() == 0) { return; }
        var c = eng.cards[0];
        var col = c[:c];
        var x0 = 70;
        var y0 = 92;
        var cw = 250;
        var ch = 226;
        dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, y0, cw, ch, 18);
        dc.setPenWidth(2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x0, y0, cw, ch, 18);
        dc.setPenWidth(1);
        text(dc, 195, y0 + 22, font(0), c[:t], col);

        var bob = (Math.sin(eng.t * 3) * 3).toNumber();
        var kind = c[:i];
        var iy = y0 + 70 + bob;
        if (kind == RewardSystem.IC_FISH) {
            IconKit.draw(dc, IconKit.FISH, c[:a], 195, iy, 3);
        } else if (kind == RewardSystem.IC_EGG) {
            IconKit.draw(dc, IconKit.EGG, c[:a], 195, iy, 5);
        } else if (kind == RewardSystem.IC_DECOR) {
            IconKit.draw(dc, IconKit.DECOR, c[:a], 195, iy, 4);
        } else {
            IconKit.draw(dc, IconKit.GRID, c[:a], 195, iy, 5);
        }

        var bf = font(1);
        text(dc, 195, y0 + 120, bf, UIKit.fit(dc, c[:b], bf, cw - 30), 0xFFFFFF);
        var lines = c[:l];
        for (var i = 0; i < lines.size() && i < 3; i++) {
            text(dc, 195, y0 + 148 + i * 20, font(0), UIKit.fit(dc, lines[i], font(0), cw - 30), DIM);
        }
        var more = eng.cards.size() > 1 ? "TAP  (" + (eng.cards.size() - 1).toString() + " more)" : "TAP TO CONTINUE";
        text(dc, 195, y0 + ch - 16, font(0), more, col);
    }

    // ---- build mode ---------------------------------------------------------------------
    function drawBuild(dc, eng, slot) {
        var r = eng.renderer;
        var n = HabitatSystem.slotCount(eng);
        for (var i = 0; i < n; i++) {
            var x = ItemDatabase.SLOT_X[i];
            var y = r.slotBottom(eng, i);
            var sel = i == slot;
            var col = sel ? 0x7FE7FF : 0xB0BEC5;
            // pixel corner brackets around the slot
            PixelKit.rect(dc, col, x - 26, y - 56, 8, 3);
            PixelKit.rect(dc, col, x - 26, y - 56, 3, 8);
            PixelKit.rect(dc, col, x + 18, y - 56, 8, 3);
            PixelKit.rect(dc, col, x + 23, y - 56, 3, 8);
            PixelKit.rect(dc, col, x - 26, y + 1, 8, 3);
            PixelKit.rect(dc, col, x - 26, y - 6, 3, 8);
            PixelKit.rect(dc, col, x + 18, y + 1, 8, 3);
            PixelKit.rect(dc, col, x + 23, y - 6, 3, 8);
            if (eng.placed[i] < 0) {
                text(dc, x, y - 26, font(0), "+", col);
            }
        }
        var stars = HabitatSystem.rating(eng);
        var label = "BUILD  " + stars.format("%.1f") + " stars";
        UIKit.titlePill(dc, label, 0xFFC93C);
        var id = eng.placed[slot];
        var name = id < 0 ? "Empty slot" : ItemDatabase.DECOR_NAME[id];
        dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(105, 84, 180, 46, 12);
        dc.setColor(BORDER, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(105, 84, 180, 46, 12);
        text(dc, 195, 98, font(0), "Slot " + (slot + 1).toString() + ": " + name, 0xFFFFFF);
        text(dc, 195, 118, font(0), "TAP TO CHANGE", DIM);
    }

    // ---- tutorial coach ---------------------------------------------------------------
    const COACH = ["Tap FEED to drop food", "Tap CLEAN to scrub the glass", "Run with your Run app",
                   "Open MENU: shop, quests, games"];
    const COACH2 = ["Hungry fish swim to it", "Clean tanks keep fish happy", "100 m = 1 coin - tap",
                    "Your tank grows from here"];

    function drawCoach(dc, eng) {
        var step = eng.tutorial;
        var y0 = 214;
        dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(75, y0, 240, 52, 14);
        dc.setPenWidth(2);
        dc.setColor(0x7FE7FF, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(75, y0, 240, 52, 14);
        dc.setPenWidth(1);
        text(dc, 195, y0 + 16, font(0), COACH[step], 0x7FE7FF);
        text(dc, 195, y0 + 36, font(0), COACH2[step], DIM);
        if (step != 2) {
            // arrow down to the button
            var bx = BTN_X[step == 3 ? 2 : step];
            var ay = y0 + 56;
            var bob = (Math.sin(eng.t * 6) * 3).toNumber();
            dc.setColor(0x7FE7FF, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[bx - 8, ay + bob], [bx + 8, ay + bob], [bx, ay + 10 + bob]]);
        }
    }
}
