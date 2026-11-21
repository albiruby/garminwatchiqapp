import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

class Layout {
    private var mProfile as DeviceProfile;
    private var mFonts as FontManager;

    private const KM_PER_MILE as Float = 1.609344f;

    // Neutral palette
    private const COLOR_BG as Number = 0x000000;
    private const COLOR_TEXT as Number = 0xFFFFFF;
    private const COLOR_LABEL_DARK as Number = 0x9E9E9E;
    private const COLOR_LABEL_HC as Number = 0xE6E6E6;
    private const COLOR_UNIT_GRAY as Number = 0x8A8A8A;
    private const COLOR_DIV_DARK as Number = 0x3A3A3A;
    private const COLOR_DIV_HC as Number = 0x707070;
    private const COLOR_AHEAD_GREEN as Number = 0x2EE56B;
    private const COLOR_BEHIND_RED as Number = 0xFF3B30;
    private const COLOR_ACTIVITY_YELLOW as Number = 0xD4FF00;

    // Accent palette (index 0..4)
    private const ACCENT_0 as Number = 0x4FD1C5; // teal
    private const ACCENT_1 as Number = 0x2EE56B; // green
    private const ACCENT_2 as Number = 0xFF8A3D; // orange
    private const ACCENT_3 as Number = 0x4DA6FF; // blue
    private const ACCENT_4 as Number = 0xFFFFFF; // white

    public function initialize(profile as DeviceProfile, fontManager as FontManager) {
        mProfile = profile;
        mFonts = fontManager;
    }

    // ---- accent from snapshot index ----
    private function accentColor(snap as RPDisplaySnapshot) as Number {
        var a = snap.accentIndex;
        if (a == 1) { return ACCENT_1; }
        if (a == 2) { return ACCENT_2; }
        if (a == 3) { return ACCENT_3; }
        if (a == 4) { return ACCENT_4; }
        return ACCENT_0;
    }

    private function labelColor(snap as RPDisplaySnapshot) as Number {
        return (snap.themeMode == 1) ? COLOR_LABEL_HC : COLOR_LABEL_DARK;
    }

    private function dividerColor(snap as RPDisplaySnapshot) as Number {
        return (snap.themeMode == 1) ? COLOR_DIV_HC : COLOR_DIV_DARK;
    }

    // ---- pace conversion for display ----
    private function dispPace(snap as RPDisplaySnapshot, paceSec as Float) as Float {
        if (paceSec <= 0.0f) { return paceSec; }
        if (snap.isTrackMode) { return paceSec; }        // per lap (meters)
        if (snap.isImperial) { return paceSec * KM_PER_MILE; }
        return paceSec;
    }

    private function formatDist(snap as RPDisplaySnapshot, meters as Float) as String {
        if (meters <= 0.0f) { return "0.00"; }
        var v = snap.isImperial ? (meters / (KM_PER_MILE * 1000.0f)) : (meters / 1000.0f);
        return v.format("%.2f");
    }

    private function gpsLabel(q as Number) as String {
        if (q >= 3) { return "GOOD"; }
        if (q == 2) { return "OK"; }
        if (q == 1) { return "POOR"; }
        return "NONE";
    }

    public function render(dc as Graphics.Dc, snap as RPDisplaySnapshot) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        mProfile.updateMetrics(w, h);

        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();

        if (mProfile.isCompactField) {
            renderCompactField(dc, w, h, snap);
            return;
        }

        if (snap.layoutMode == 1) {
            renderFocus(dc, w, h, snap);
        } else if (snap.layoutMode == 2) {
            renderDelta(dc, w, h, snap);
        } else if (snap.layoutMode == 3) {
            renderGrid(dc, w, h, snap);
        } else {
            renderStandard(dc, w, h, snap);
        }

        if (snap.debugMode) {
            renderDebug(dc, w, h, snap);
        }
    }

    // ============================================================
    // Shared helpers for Delta / Grid layouts
    // ============================================================
    private const COLOR_NAVY as Number = 0x0A1628;
    private const COLOR_ORANGE_LBL as Number = 0xFFA53D;
    private const COLOR_GRID_RED as Number = 0xE24B4A;

    // Signed delta "+0:19" (ahead) / "-0:42" (behind)
    private function formatDelta(sec as Float) as String {
        var totalSec = (sec.abs() + 0.5f).toNumber();
        var s = (totalSec / 60).format("%d") + ":" + (totalSec % 60).format("%02d");
        if (totalSec == 0) { return s; }
        return (sec >= 0.0f ? "+" : "-") + s;
    }

    // Zone index for status bar: 0 = far behind ... n-1 = far ahead; on-target in the middle.
    private function statusZone(snap as RPDisplaySnapshot, n as Number) as Number {
        if (!snap.hasTarget || snap.projectedFinishSec <= 0.0f) { return -1; }
        var d = snap.aheadBehindSec;
        var mid = n / 2;
        if (snap.isOnTarget) { return mid; }
        if (d < 0.0f) {
            if (d < -60.0f) { return 0; }
            if (d < -20.0f) { return (mid >= 2) ? 1 : 0; }
            return mid - 1;
        }
        if (d > 60.0f && n - 1 > mid + 1) { return n - 1; }
        return mid + 1;
    }

    private function zoneColor(i as Number, n as Number) as Number {
        var mid = n / 2;
        if (i == mid) { return 0x9E9E9E; }
        if (i < mid) { return (i == 0) ? COLOR_BEHIND_RED : ((i == mid - 1) ? 0xFAC775 : 0xFF8A3D); }
        return (i == mid + 1) ? COLOR_AHEAD_GREEN : 0x4FD1C5;
    }

    // Segmented status bar; active segment drawn taller, optional marker below it.
    private function drawZoneBar(dc as Graphics.Dc, cx as Number, cy as Number, totalW as Number, segH as Number, n as Number, active as Number, withMarker as Boolean) as Void {
        var gap = (segH > 3) ? segH : 3;
        var segW = (totalW - (gap * (n - 1))) / n;
        var x = cx - (totalW / 2);
        for (var i = 0; i < n; i += 1) {
            var c = (active < 0) ? 0x444444 : zoneColor(i, n);
            dc.setColor(c, Graphics.COLOR_TRANSPARENT);
            if (i == active) {
                dc.fillRectangle(x, cy - segH, segW, segH * 2 + 1);
                if (withMarker) {
                    var mx = x + (segW / 2);
                    var my = cy + segH + 3;
                    dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
                    dc.fillPolygon([[mx, my], [mx - segH - 2, my + segH + 4], [mx + segH + 2, my + segH + 4]]);
                }
            } else {
                dc.fillRectangle(x, cy - (segH / 2), segW, segH);
            }
            x += segW + gap;
        }
    }

    private function statusText(snap as RPDisplaySnapshot) as String {
        if (!snap.hasTarget) { return "SET TARGET"; }
        if (snap.state == STATE_FINISHED || snap.state == STATE_LOCKED) { return "FINISHED"; }
        if (snap.projectedFinishSec <= 0.0f) { return snap.stateLabel; }
        if (snap.state == STATE_WAIT_GPS || snap.state == STATE_PAUSED || snap.state == STATE_MANUAL_PAUSED) { return snap.stateLabel; }
        if (snap.isOnTarget) { return "ON TARGET"; }
        return snap.isAhead ? "AHEAD OF TARGET" : "BEHIND TARGET";
    }

    private function statusColor(snap as RPDisplaySnapshot) as Number {
        if (!snap.hasTarget || snap.projectedFinishSec <= 0.0f) { return COLOR_UNIT_GRAY; }
        if (snap.isOnTarget) { return COLOR_TEXT; }
        return snap.isAhead ? COLOR_AHEAD_GREEN : COLOR_BEHIND_RED;
    }

    private function contentBounds(dc as Graphics.Dc, h as Number, snap as RPDisplaySnapshot) as Array<Number> {
        var top = mProfile.safeMarginPx;
        var dbgH = snap.debugMode ? (dc.getFontHeight(Graphics.FONT_XTINY) * 2 + 6) : 0;
        return [top, h - mProfile.safeMarginPx - dbgH] as Array<Number>;
    }

    private function drawLabelValue(dc as Graphics.Dc, cx as Number, valY as Number, lblY as Number, val as String, lbl as String, maxW as Number, maxH as Number, valColor as Number, lblColor as Number, rank as Number) as Void {
        var cv = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var empty = val.equals("--:--");
        var f = empty ? Graphics.FONT_SMALL : mFonts.selectNumericFont(dc, val, maxW, maxH, rank);
        dc.setColor(empty ? COLOR_UNIT_GRAY : valColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, valY, f, val, cv);
        dc.setColor(lblColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, lblY, Graphics.FONT_XTINY, lbl, cv);
    }

    // ============================================================
    // Delta layout: COROS-style (giant signed delta + zone bar)
    // ============================================================
    private function renderDelta(dc as Graphics.Dc, w as Number, h as Number, snap as RPDisplaySnapshot) as Void {
        dc.setColor(COLOR_NAVY, COLOR_NAVY);
        dc.clear();
        var cx = w / 2;
        var cv = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var b = contentBounds(dc, h, snap);
        var top = b[0]; var cH = b[1] - b[0];
        var lblC = (snap.themeMode == 1) ? COLOR_LABEL_HC : 0x8A9BB5;

        // Hero
        var heroY = top + (cH * 0.30).toNumber();
        var hasDelta = snap.hasTarget && snap.projectedFinishSec > 0.0f;
        var heroStr = hasDelta ? formatDelta(snap.aheadBehindSec) : formatPace(dispPace(snap, snap.lapPaceSec));
        if (heroStr.equals("--:--")) {
            dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, heroY, Graphics.FONT_MEDIUM, heroStr, cv);
        } else {
            var hf = mFonts.selectNumericFont(dc, heroStr, mProfile.getSafeChordWidthAtY(heroY, w, h), (cH * 0.26).toNumber(), 0);
            dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, heroY, hf, heroStr, cv);
        }
        if (!hasDelta && !snap.hasTarget) {
            dc.setColor(lblC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, top + (cH * 0.12).toNumber(), Graphics.FONT_XTINY, "LAP " + snap.paceUnitStr, cv);
        }

        // Zone bar + status
        var barY = top + (cH * 0.47).toNumber();
        var segH = (cH * 0.012f).toNumber(); if (segH < 2) { segH = 2; }
        var barW = (mProfile.getSafeChordWidthAtY(barY, w, h) * 0.85f).toNumber();
        drawZoneBar(dc, cx, barY, barW, segH, 6, statusZone(snap, 6), true);
        dc.setColor(statusColor(snap), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + (cH * 0.57).toNumber(), Graphics.FONT_XTINY, statusText(snap), cv);

        // Pair
        var valY = top + (cH * 0.71).toNumber();
        var lblY = top + (cH * 0.81).toNumber();
        var pairW = (mProfile.getSafeChordWidthAtY(lblY, w, h) / 2) - 6;
        var lx = cx - (pairW / 2) - 4; var rx = cx + (pairW / 2) + 4;
        var maxH = (cH * 0.13).toNumber();
        if (snap.hasTarget) {
            drawLabelValue(dc, lx, valY, lblY, formatPace(dispPace(snap, snap.lapPaceSec)), "LAP PACE", pairW, maxH, COLOR_TEXT, COLOR_ORANGE_LBL, 2);
            drawLabelValue(dc, rx, valY, lblY, hasDelta ? formatDuration(snap.projectedFinishSec) : "--:--", "PROJECTED", pairW, maxH, COLOR_TEXT, COLOR_ORANGE_LBL, 2);
        } else {
            drawLabelValue(dc, lx, valY, lblY, formatDist(snap, snap.distanceMeters), "DIST " + snap.distanceUnitStr, pairW, maxH, COLOR_TEXT, COLOR_ORANGE_LBL, 2);
            drawLabelValue(dc, rx, valY, lblY, formatDuration(snap.elapsedSeconds), "TIME", pairW, maxH, COLOR_TEXT, COLOR_ORANGE_LBL, 2);
        }

        // Footer
        if (snap.hasTarget && !snap.debugMode) {
            var fy = top + (cH * 0.92).toNumber();
            var need = snap.hideNeedPace ? "--:--" : formatPace(dispPace(snap, snap.needPaceSec));
            var foot = "NEED " + need + "  " + (snap.isTrackMode ? ("LAP " + snap.lapCountText) : (formatDist(snap, snap.distanceMeters) + " " + snap.distanceUnitStr));
            var footCw = mProfile.chordWidthAtY(fy + (dc.getFontHeight(Graphics.FONT_XTINY) / 2), w, h);
            if (footCw < dc.getTextWidthInPixels(foot, Graphics.FONT_XTINY) + 8) {
                foot = "NEED " + need;
            }
            if (footCw >= dc.getTextWidthInPixels(foot, Graphics.FONT_XTINY) + 8) {
                dc.setColor(lblC, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, fy, Graphics.FONT_XTINY, foot, cv);
            }
        }
    }

    // ============================================================
    // Grid layout: Garmin FR170-style (cross grid + status bar)
    // ============================================================
    private function renderGrid(dc as Graphics.Dc, w as Number, h as Number, snap as RPDisplaySnapshot) as Void {
        var cx = w / 2;
        var cv = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var b = contentBounds(dc, h, snap);
        var top = b[0]; var cH = b[1] - b[0];
        var lbl = labelColor(snap);
        var hasProj = snap.hasTarget && snap.projectedFinishSec > 0.0f;

        // Top: projected (or lap pace)
        var tLblY = top + (cH * 0.07).toNumber();
        var tValY = top + (cH * 0.215).toNumber();
        var topLbl = snap.hasTarget ? "PROJECTED" : ("LAP " + snap.paceUnitStr);
        if (snap.state == STATE_WAIT_GPS || snap.state == STATE_PAUSED || snap.state == STATE_MANUAL_PAUSED) { topLbl = snap.stateLabel; }
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, tLblY, Graphics.FONT_XTINY, topLbl, cv);
        var topStr = snap.hasTarget ? (hasProj ? formatDuration(snap.projectedFinishSec) : "--:--") : formatPace(dispPace(snap, snap.lapPaceSec));
        if (topStr.equals("--:--")) {
            dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, tValY, Graphics.FONT_MEDIUM, topStr, cv);
        } else {
            var tf = mFonts.selectNumericFont(dc, topStr, mProfile.getSafeChordWidthAtY(tValY, w, h), (cH * 0.15).toNumber(), 1);
            dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, tValY, tf, topStr, cv);
        }

        // Grid lines
        var y1 = top + (cH * 0.32).toNumber();
        var y2 = top + (cH * 0.70).toNumber();
        var cw1 = mProfile.chordWidthAtY(y1, w, h);
        var cw2 = mProfile.chordWidthAtY(y2, w, h);
        dc.setColor(COLOR_GRID_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx - (cw1 / 2) + 4, y1, cx + (cw1 / 2) - 4, y1);
        dc.drawLine(cx - (cw2 / 2) + 4, y2, cx + (cw2 / 2) - 4, y2);
        dc.drawLine(cx, y1, cx, y2);
        dc.setPenWidth(1);

        // Quadrants
        var qLblY = top + (cH * 0.37).toNumber();
        var qValY = top + (cH * 0.48).toNumber();
        var qSubY = top + (cH * 0.62).toNumber();
        var qW = (mProfile.getSafeChordWidthAtY(qValY, w, h) / 2) - 8;
        var lx = cx - (qW / 2) - 6; var rx = cx + (qW / 2) + 6;
        var qMaxH = (cH * 0.14).toNumber();
        var lLbl = snap.hasTarget ? "LAP PACE" : "DIST";
        var rLbl = snap.hasTarget ? "NEED PACE" : "TIME";
        var lVal = snap.hasTarget ? formatPace(dispPace(snap, snap.lapPaceSec)) : formatDist(snap, snap.distanceMeters);
        var rVal = snap.hasTarget ? (snap.hideNeedPace ? "--:--" : formatPace(dispPace(snap, snap.needPaceSec))) : formatDuration(snap.elapsedSeconds);
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx, qLblY, Graphics.FONT_XTINY, lLbl, cv);
        dc.drawText(rx, qLblY, Graphics.FONT_XTINY, rLbl, cv);
        drawPairValue(dc, lx, qValY, lVal, qW, qMaxH, COLOR_TEXT);
        drawPairValue(dc, rx, qValY, rVal, qW, qMaxH, COLOR_TEXT);
        if (snap.hasTarget) {
            dc.setColor(lbl, Graphics.COLOR_TRANSPARENT);
            var lSub = snap.isTrackMode ? ("LAP " + snap.lapCountText) : formatDist(snap, snap.distanceMeters);
            dc.drawText(lx, qSubY, Graphics.FONT_XTINY, lSub, cv);
            dc.drawText(rx, qSubY, Graphics.FONT_XTINY, formatDuration(snap.elapsedSeconds), cv);
        }

        // Status bar + delta
        var barY = top + (cH * 0.76).toNumber();
        var segH = (cH * 0.012f).toNumber(); if (segH < 2) { segH = 2; }
        var barW = (mProfile.getSafeChordWidthAtY(barY, w, h) * 0.75f).toNumber();
        drawZoneBar(dc, cx, barY, barW, segH, 5, statusZone(snap, 5), false);
        var dY = top + (cH * 0.88).toNumber();
        var dStr = hasProj ? formatDelta(snap.aheadBehindSec) : statusText(snap);
        var dFont = hasProj ? mFonts.selectNumericFont(dc, dStr, mProfile.getSafeChordWidthAtY(dY, w, h), (cH * 0.10).toNumber(), 3) : Graphics.FONT_XTINY;
        dc.setColor(statusColor(snap), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, dY, dFont, dStr, cv);
    }

    // ============================================================
    // Standard layout: Suunto-style HUD (progress ring + projected hero)
    // ============================================================
    private function renderStandard(dc as Graphics.Dc, w as Number, h as Number, snap as RPDisplaySnapshot) as Void {
        var centerX = w / 2;
        var centerV = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var labelFont = Graphics.FONT_XTINY;
        var lbl = labelColor(snap);
        var div = dividerColor(snap);
        var accent = accentColor(snap);
        var minDim = (w < h) ? w : h;

        // ---- Progress ring (round) / bar (rectangular) ----
        var progress = 0.0f;
        if (snap.hasTarget && snap.targetDistM > 0.0f) {
            progress = snap.distanceMeters / snap.targetDistM;
            if (progress > 1.0f) { progress = 1.0f; }
            if (progress < 0.0f) { progress = 0.0f; }
        }
        var pen = (minDim * 0.014f).toNumber();
        if (pen < 3) { pen = 3; }
        var ringInset = 0;
        if (mProfile.isRound) {
            ringInset = pen * 2;
            drawProgressRing(dc, w, h, pen, progress, snap.hasTarget, accent, div);
        } else {
            ringInset = pen + 4;
            drawProgressBar(dc, w, pen, progress, snap.hasTarget, accent, div);
        }

        var top = mProfile.safeMarginPx + ringInset;
        var dbgH = snap.debugMode ? (dc.getFontHeight(labelFont) * 2 + 6) : 0;
        var bottom = h - mProfile.safeMarginPx - ringInset - dbgH;
        var cH = bottom - top;

        // ---- Mode tag (TRACK / TREADMILL) ----
        var tagY = top + (cH * 0.07).toNumber();
        if (snap.activeRunMode == MODE_TREADMILL || snap.activeRunMode == MODE_TRACK) {
            var tag = (snap.activeRunMode == MODE_TREADMILL) ? "TREADMILL" : "TRACK";
            if (mProfile.chordWidthAtY(tagY - (dc.getFontHeight(labelFont) / 2), w, h) >= dc.getTextWidthInPixels(tag, labelFont) + 8) {
                dc.setColor(COLOR_ACTIVITY_YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.drawText(centerX, tagY, labelFont, tag, centerV);
            }
        }

        // ---- Hero: projected finish (or lap pace when no target) ----
        var heroLabelY = top + (cH * 0.20).toNumber();
        var heroY = top + (cH * 0.37).toNumber();
        var deltaY = top + (cH * 0.53).toNumber();
        var heroW = mProfile.getSafeChordWidthAtY(heroY, w, h);
        var heroMaxH = (cH * 0.24).toNumber();

        var heroLabel = snap.hasTarget ? "PROJECTED" : "LAP PACE";
        var heroLabelColor = lbl;
        if (snap.state == STATE_WAIT_GPS || snap.state == STATE_PAUSED || snap.state == STATE_MANUAL_PAUSED) {
            heroLabel = snap.stateLabel;
            heroLabelColor = accent;
        }
        dc.setColor(heroLabelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, heroLabelY, labelFont, heroLabel, centerV);

        var heroStr = "--:--";
        var heroOk = false;
        if (snap.hasTarget) {
            if (snap.projectedFinishSec > 0.0f) { heroStr = formatDuration(snap.projectedFinishSec); heroOk = true; }
        } else if (snap.lapPaceSec > 0.0f) {
            heroStr = formatPace(dispPace(snap, snap.lapPaceSec));
            heroOk = true;
        }
        if (heroOk) {
            var heroFont = mFonts.selectNumericFont(dc, heroStr, heroW, heroMaxH, 0);
            dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, heroY, heroFont, heroStr, centerV);
        } else {
            dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, heroY, Graphics.FONT_MEDIUM, heroStr, centerV);
        }

        if (snap.hasTarget) {
            drawAheadBehind(dc, centerX, deltaY, snap);
        } else {
            dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, deltaY, labelFont, "SET TARGET", centerV);
        }

        // ---- Secondary pair: LAP | NEED  (or DIST | TIME without target) ----
        var pairValY = top + (cH * 0.70).toNumber();
        var pairLblY = top + (cH * 0.81).toNumber();
        var pairW = (mProfile.getSafeChordWidthAtY(pairLblY, w, h) / 2) - 6;
        var leftCX = centerX - (pairW / 2) - 4;
        var rightCX = centerX + (pairW / 2) + 4;
        var pairMaxH = (cH * 0.13).toNumber();

        dc.setColor(div, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX, pairValY - (pairMaxH / 2), centerX, pairLblY + 4);

        var lStr; var rStr; var lLbl; var rLbl; var rColor = accent;
        if (snap.hasTarget) {
            lStr = formatPace(dispPace(snap, snap.lapPaceSec));
            rStr = snap.hideNeedPace ? "--:--" : formatPace(dispPace(snap, snap.needPaceSec));
            lLbl = "LAP " + snap.paceUnitStr;
            rLbl = "NEED " + snap.paceUnitStr;
        } else {
            lStr = formatDist(snap, snap.distanceMeters);
            rStr = formatDuration(snap.elapsedSeconds);
            lLbl = "DIST " + snap.distanceUnitStr;
            rLbl = "TIME";
            rColor = COLOR_TEXT;
        }
        drawPairValue(dc, leftCX, pairValY, lStr, pairW, pairMaxH, COLOR_TEXT);
        drawPairValue(dc, rightCX, pairValY, rStr, pairW, pairMaxH, rColor);
        dc.setColor(lbl, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftCX, pairLblY, labelFont, lLbl, centerV);
        dc.drawText(rightCX, pairLblY, labelFont, rLbl, centerV);

        // ---- Footer: dist + time (or lap count on track) ----
        if (snap.hasTarget && !snap.debugMode) {
            var footY = top + (cH * 0.93).toNumber();
            var foot = formatDist(snap, snap.distanceMeters) + " " + snap.distanceUnitStr + "  " + formatDuration(snap.elapsedSeconds);
            if (snap.isTrackMode) {
                foot = "LAP " + snap.lapCountText + "  " + formatDuration(snap.elapsedSeconds);
            }
            if (mProfile.chordWidthAtY(footY + (dc.getFontHeight(labelFont) / 2), w, h) >= dc.getTextWidthInPixels(foot, labelFont) + 8) {
                dc.setColor(lbl, Graphics.COLOR_TRANSPARENT);
                dc.drawText(centerX, footY, labelFont, foot, centerV);
            }
        }
    }

    private function drawPairValue(dc as Graphics.Dc, cx as Number, cy as Number, str as String, maxW as Number, maxH as Number, color as Number) as Void {
        var isEmpty = str.equals("--:--");
        var font = isEmpty ? Graphics.FONT_SMALL : mFonts.selectNumericFont(dc, str, maxW, maxH, 2);
        dc.setColor(isEmpty ? COLOR_UNIT_GRAY : color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, font, str, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Thin ring hugging the bezel; arc grows clockwise from 12 o'clock with distance progress.
    private function drawProgressRing(dc as Graphics.Dc, w as Number, h as Number, pen as Number, progress as Float, hasTarget as Boolean, accent as Number, track as Number) as Void {
        var cx = w / 2;
        var cy = h / 2;
        var r = ((w < h) ? w : h) / 2 - (pen / 2) - 2;
        dc.setPenWidth(pen);
        dc.setColor(track, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        if (hasTarget && progress > 0.005f) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            if (progress >= 0.999f) {
                dc.drawCircle(cx, cy, r);
            } else {
                var endDeg = 90.0f - (360.0f * progress);
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, endDeg.toNumber());
                var rad = endDeg * Math.PI.toFloat() / 180.0f;
                var dx = cx + (r * Math.cos(rad)).toNumber();
                var dy = cy - (r * Math.sin(rad)).toNumber();
                dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(dx, dy, pen);
            }
        }
        dc.setPenWidth(1);
    }

    private function drawProgressBar(dc as Graphics.Dc, w as Number, pen as Number, progress as Float, hasTarget as Boolean, accent as Number, track as Number) as Void {
        var x0 = mProfile.safeMarginPx;
        var bw = w - (2 * x0);
        var y = mProfile.safeMarginPx;
        dc.setColor(track, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, y, bw, pen);
        if (hasTarget && progress > 0.005f) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0, y, (bw * progress).toNumber(), pen);
        }
    }

    // ============================================================
    // Focus layout (big pace + projection, no separate DIST/TIME band)
    // ============================================================
    private function renderFocus(dc as Graphics.Dc, w as Number, h as Number, snap as RPDisplaySnapshot) as Void {
        var centerX = w / 2;
        var centerV = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var labelFont = Graphics.FONT_XTINY;
        var safe = mProfile.safeMarginPx;
        var lbl = labelColor(snap);
        var div = dividerColor(snap);
        var accent = accentColor(snap);

        var hasHeader = (snap.activeRunMode == MODE_TREADMILL || snap.activeRunMode == MODE_TRACK);
        var headerH = 0;
        if (hasHeader) {
            // Short labels: "RUN" is redundant inside the Run activity,
            // and the full string cannot fit the top chord (TW~197px).
            var hdrText = (snap.activeRunMode == MODE_TREADMILL) ? "TREADMILL" : "TRACK";
            var hdrFontH = dc.getFontHeight(labelFont);
            var needW = dc.getTextWidthInPixels(hdrText, labelFont) + 8;
            // Bottom-anchored in its strip (widest chord there).
            // Skip entirely (reclaim space) if it still doesn't fit.
            var candH = (h * 0.11).toNumber();
            if (candH < 24) { candH = 24; }
            var candY = safe + candH - (hdrFontH / 2) - 2;
            if (mProfile.chordWidthAtY(candY - (hdrFontH / 2), w, h) >= needW) {
                headerH = candH;
                dc.setColor(COLOR_ACTIVITY_YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.drawText(centerX, candY, labelFont, hdrText, centerV);
            }
        }

        var contentTop = safe + headerH;
        var dbgH = snap.debugMode ? (dc.getFontHeight(labelFont) * 2 + 6) : 0;
        var contentH = (h - safe - dbgH) - contentTop;

        // Big lap pace
        var b1LabelY = contentTop + (contentH * 0.04).toNumber();
        var b1ValueY = contentTop + (contentH * 0.17).toNumber();
        var b1SafeW = mProfile.getSafeChordWidthAtY(b1ValueY, w, h);

        dc.setColor(lbl, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, b1LabelY, labelFont, "LAP PACE", centerV);
        if (snap.lapPaceSec > 0.0f) {
            drawPace(dc, centerX, b1ValueY, dispPace(snap, snap.lapPaceSec), snap.paceUnitStr, b1SafeW, COLOR_TEXT, 1);
        } else {
            dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, b1ValueY, labelFont, "--:--", centerV);
        }

        // Combined dist/time line
        var distLineY = contentTop + (contentH * 0.33).toNumber();
        var distLine = formatDist(snap, snap.distanceMeters) + " " + snap.distanceUnitStr +
                       "   " + formatDuration(snap.elapsedSeconds);
        dc.setColor(lbl, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, distLineY, labelFont, distLine, centerV);

        // Divider before projected
        var divY1 = contentTop + (contentH * 0.40).toNumber();
        dc.setColor(div, Graphics.COLOR_TRANSPARENT);
        var xi = (w * 0.16).toNumber();
        dc.drawLine(xi, divY1, w - xi, divY1);

        // Projected finish
        var b3LabelY = contentTop + (contentH * 0.45).toNumber();
        var b3ValueY = contentTop + (contentH * 0.57).toNumber();
        var b3DeltaY = contentTop + (contentH * 0.66).toNumber();
        var b3SafeW = mProfile.getSafeChordWidthAtY(b3ValueY, w, h);

        dc.setColor(lbl, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, b3LabelY, labelFont, "PROJECTED FINISH", centerV);
        if (snap.hasTarget && snap.projectedFinishSec > 0.0f) {
            var projStr = formatDuration(snap.projectedFinishSec);
            var projFont = mFonts.selectNumericFont(dc, projStr, b3SafeW, (contentH * 0.11).toNumber(), 2);
            dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, b3ValueY, projFont, projStr, centerV);
            drawAheadBehind(dc, centerX, b3DeltaY, snap);
        } else {
            dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, b3ValueY, labelFont, "--:--", centerV);
        }

        // Divider before need pace
        var divY2 = contentTop + (contentH * 0.74).toNumber();
        dc.setColor(div, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(xi, divY2, w - xi, divY2);

        // Need pace
        var b4LabelY = contentTop + (contentH * 0.79).toNumber();
        var b4ValueY = contentTop + (contentH * 0.91).toNumber();
        var b4SafeW = mProfile.getSafeChordWidthAtY(b4ValueY, w, h);

        dc.setColor(lbl, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, b4LabelY, labelFont, "NEED PACE", centerV);
        if (!snap.hideNeedPace && snap.needPaceSec > 0.0f) {
            drawPace(dc, centerX, b4ValueY, dispPace(snap, snap.needPaceSec), snap.paceUnitStr, b4SafeW, accent, 3);
        } else {
            dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, b4ValueY, labelFont, "--:--", centerV);
        }
    }

    // ============================================================
    // Debug overlay (engine, GPS, confidence, rejection, locks)
    // ============================================================
    private function renderDebug(dc as Graphics.Dc, w as Number, h as Number, snap as RPDisplaySnapshot) as Void {
        var labelFont = Graphics.FONT_XTINY;
        var safe = mProfile.safeMarginPx;
        // Line spacing derived from measured font height — never overlap
        var fh = dc.getFontHeight(labelFont);
        var stripH = fh * 2 + 6;
        var stripTop = h - safe - stripH;
        var y1 = stripTop + (fh / 2) + 1;
        var y2 = y1 + fh + 2;
        var centerX = w / 2;
        var cv = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        // Short codes so both lines fit the narrow bottom chord of round displays
        var eng = "OUT";
        if (snap.activeRunMode == MODE_TREADMILL) { eng = "TRD"; }
        else if (snap.activeRunMode == MODE_TRACK) { eng = "TRK"; }
        var gps = "G0";
        if (snap.gpsQuality >= 3) { gps = "G3"; }
        else if (snap.gpsQuality == 2) { gps = "G2"; }
        else if (snap.gpsQuality == 1) { gps = "G1"; }

        var confPct = (snap.confidence * 100.0f).toNumber();
        var rejPct = snap.rejectionRatePct.toNumber();
        var line1 = eng + " " + gps + " C:" + confPct + "%";
        var line2 = "R:" + rejPct + "%" + (snap.isPaceLocked ? " LOCK" : "") + (snap.isProjectionLocked ? " PLOCK" : "");

        dc.setColor(COLOR_ACTIVITY_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y1, labelFont, line1, cv);
        dc.drawText(centerX, y2, labelFont, line2, cv);
    }

    // ============================================================
    // Pace value + unit (baseline aligned)
    // ============================================================
    private function drawPace(
        dc as Graphics.Dc,
        centerX as Number,
        centerY as Number,
        paceSec as Float,
        unitStr as String,
        maxWidthPx as Number,
        valColor as Number,
        startRank as Number
    ) as Void {
        var valStr = formatPace(paceSec);
        var unitFont = Graphics.FONT_XTINY;
        var unitW = dc.getTextWidthInPixels(unitStr, unitFont);
        var spacing = 2;
        var availValW = maxWidthPx - unitW - spacing;
        if (availValW < 40) { availValW = maxWidthPx; }

        var valFont;
        var valW;
        if (paceSec <= 0.0f || valStr.equals("--:--")) {
            valFont = Graphics.FONT_XTINY;
            valW = dc.getTextWidthInPixels(valStr, valFont);
        } else {
            valFont = mFonts.selectNumericFont(dc, valStr, availValW, (maxWidthPx.toFloat() * 0.28f).toNumber(), startRank);
            valW = dc.getTextWidthInPixels(valStr, valFont);
        }

        var optValH = mFonts.getOpticalHeight(dc, valFont);
        var unitH = dc.getFontHeight(unitFont);
        var totalW = valW + spacing + unitW;
        var startX = centerX - (totalW / 2);

        dc.setColor(valColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, centerY, valFont, valStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var unitCenterY = centerY + (optValH / 2) - (unitH / 3);
        dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + valW + spacing, unitCenterY, unitFont, unitStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ============================================================
    // Ahead/behind with triangle
    // ============================================================
    private function drawAheadBehind(dc as Graphics.Dc, centerX as Number, centerY as Number, snap as RPDisplaySnapshot) as Void {
        var font = Graphics.FONT_XTINY;
        var text = formatAheadBehind(snap);

        if (!snap.hasTarget || snap.projectedFinishSec <= 0.0f) {
            dc.setColor(COLOR_UNIT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, centerY, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var isUp = snap.isAhead || snap.isOnTarget;
        var color = isUp ? COLOR_AHEAD_GREEN : COLOR_BEHIND_RED;
        var textW = dc.getTextWidthInPixels(text, font);
        var triSize = (dc.getFontHeight(font) * 0.45f).toNumber();
        if (triSize < 7) { triSize = 7; }
        var tH = triSize / 2;
        var gap = 3;
        var totalW = triSize + gap + textW;
        var startX = centerX - (totalW / 2);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (isUp) {
            dc.fillPolygon([[startX + (triSize / 2), centerY - tH], [startX, centerY + tH], [startX + triSize, centerY + tH]]);
        } else {
            dc.fillPolygon([[startX, centerY - tH], [startX + triSize, centerY - tH], [startX + (triSize / 2), centerY + tH]]);
        }
        dc.drawText(startX + triSize + gap, centerY, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function renderCompactField(dc as Graphics.Dc, w as Number, h as Number, snap as RPDisplaySnapshot) as Void {
        var centerX = w / 2;
        var paceStr = formatPace(dispPace(snap, snap.lapPaceSec));
        var topFont;
        if (snap.lapPaceSec <= 0.0f) {
            topFont = Graphics.FONT_XTINY;
        } else {
            topFont = mFonts.selectNumericFont(dc, paceStr, w - 12, (h.toFloat() * 0.40f).toNumber(), 2);
        }
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, (h.toFloat() * 0.36f).toNumber(), topFont, paceStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawAheadBehind(dc, centerX, (h.toFloat() * 0.78f).toNumber(), snap);
    }

    // ============================================================
    // Formatters
    // ============================================================
    public static function formatPace(paceSec as Float) as String {
        if (paceSec <= 0.0f || paceSec > 3599.0f) {
            return "--:--";
        }
        var totalSec = (paceSec + 0.5f).toNumber();
        var mins = totalSec / 60;
        var secs = totalSec % 60;
        return mins.format("%d") + ":" + secs.format("%02d");
    }

    public static function formatDuration(durationSec as Float) as String {
        if (durationSec <= 0.0f) {
            return "0:00";
        }
        var totalSec = (durationSec + 0.5f).toNumber();
        var hours = totalSec / 3600;
        var mins = (totalSec % 3600) / 60;
        var secs = totalSec % 60;
        if (hours > 0) {
            return hours.format("%d") + ":" + mins.format("%02d") + ":" + secs.format("%02d");
        }
        return mins.format("%d") + ":" + secs.format("%02d");
    }

    public static function formatAheadBehind(snap as RPDisplaySnapshot) as String {
        if (!snap.hasTarget) {
            return "SET TARGET";
        }
        if (snap.state == STATE_FINISHED || snap.state == STATE_LOCKED) {
            return "FINISHED";
        }
        if (snap.projectedFinishSec <= 0.0f) {
            return snap.stateLabel;
        }
        if (snap.isOnTarget) {
            return "ON TARGET";
        }
        var absDelta = snap.aheadBehindSec.abs();
        var totalSec = (absDelta + 0.5f).toNumber();
        var mins = totalSec / 60;
        var secs = totalSec % 60;
        var timeStr = mins.format("%d") + ":" + secs.format("%02d");
        if (snap.isAhead) {
            return timeStr + " AHEAD";
        }
        return timeStr + " BEHIND";
    }
}
