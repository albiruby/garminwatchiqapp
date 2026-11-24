import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

class DeviceProfile {
    public var screenWidth as Number = 390;
    public var screenHeight as Number = 390;
    public var isRound as Boolean = true;
    public var isAmoled as Boolean = true;
    public var scaleFactor as Float = 1.0f;
    public var safeMarginPx as Number = 12;
    public var isCompactField as Boolean = false;

    // Skill 028: Obscurity flags (set from View.onLayout)
    public var isTopCurved as Boolean = false;
    public var isBotCurved as Boolean = false;
    public var isLeftCurved as Boolean = false;
    public var isRightCurved as Boolean = false;

    // Skill 029: Layout tier (0=Full, 1=Half, 2=Strip, 3=Compact)
    public var layoutTier as Number = 0;

    // Skill 030: Day/Night polarity
    public var isDarkBackground as Boolean = true;

    private const BASELINE_DIM as Float = 390.0f;

    public function initialize() {
        refreshFromSystem();
    }

    public function refreshFromSystem() as Void {
        var settings = System.getDeviceSettings();
        if (settings != null) {
            screenWidth = settings.screenWidth;
            screenHeight = settings.screenHeight;
            isRound = (settings.screenShape == System.SCREEN_SHAPE_ROUND);
            isAmoled = (screenWidth >= 360);
        }
        updateMetrics(screenWidth, screenHeight);
    }

    public function updateMetrics(dcWidth as Number, dcHeight as Number) as Void {
        var minDim = dcWidth < dcHeight ? dcWidth : dcHeight;
        scaleFactor = minDim.toFloat() / BASELINE_DIM;
        safeMarginPx = (10.0f * scaleFactor).toNumber();
        if (safeMarginPx < 6) {
            safeMarginPx = 6;
        }
        isCompactField = (dcHeight < (screenHeight * 0.65f).toNumber()) || (dcWidth < (screenWidth * 0.65f).toNumber());
    }

    // Skill 028: Safe chord width accounting for obscurity flags
    public function getSafeChordWidthAtY(y as Number, dcWidth as Number, dcHeight as Number) as Number {
        if (!isRound || isCompactField) {
            return dcWidth - (2 * safeMarginPx);
        }
        var radius = (dcWidth < dcHeight ? dcWidth : dcHeight).toFloat() / 2.0f;
        var centerY = dcHeight.toFloat() / 2.0f;
        var dy = (y.toFloat() - centerY).abs();
        if (dy >= radius) {
            return (dcWidth.toFloat() * 0.35f).toNumber();
        }
        var halfChord = Math.sqrt((radius * radius) - (dy * dy)).toFloat();
        var usable = (2.0f * halfChord).toNumber() - (2 * safeMarginPx);

        // Skill 028: Reduce width if top/bottom is obscured by bezel
        if (isTopCurved && y < (dcHeight * 0.15f)) {
            usable = (usable.toFloat() * 0.80f).toNumber();
        }
        if (isBotCurved && y > (dcHeight * 0.85f)) {
            usable = (usable.toFloat() * 0.80f).toNumber();
        }

        return usable > 40 ? usable : 40;
    }

    // Raw chord width at a given Y on a round display (no safe inset).
    // Returns full width for non-round / non-full-screen fields.
    public function chordWidthAtY(y as Number, dcWidth as Number, dcHeight as Number) as Number {
        if (!isRound || isCompactField) {
            return dcWidth;
        }
        var radius = (dcWidth < dcHeight ? dcWidth : dcHeight).toFloat() / 2.0f;
        var centerY = dcHeight.toFloat() / 2.0f;
        var dy = (y.toFloat() - centerY).abs();
        if (dy >= radius) {
            return (dcWidth.toFloat() * 0.35f).toNumber();
        }
        var halfChord = Math.sqrt((radius * radius) - (dy * dy)).toFloat();
        return (2.0f * halfChord).toNumber();
    }

    // Skill 030: Get appropriate colors based on polarity
    public function getTextColor() as Number {
        return isDarkBackground ? 0xFFFFFF : 0x000000;
    }

    public function getLabelColor() as Number {
        return isDarkBackground ? 0x9E9E9E : 0x666666;
    }

    public function getDividerColor() as Number {
        return isDarkBackground ? 0x3A3A3A : 0xCCCCCC;
    }

    public function getBackgroundColor() as Number {
        return isDarkBackground ? 0x000000 : 0xFFFFFF;
    }
}
