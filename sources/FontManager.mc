import Toybox.Graphics;
import Toybox.Lang;

class FontManager {
    private var mNumberFonts as Array<Graphics.FontType>;
    private var mTextFonts as Array<Graphics.FontType>;

    public function initialize() {
        mNumberFonts = [
            Graphics.FONT_NUMBER_THAI_HOT,
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_LARGE,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
            Graphics.FONT_XTINY
        ] as Array<Graphics.FontType>;

        mTextFonts = [
            Graphics.FONT_LARGE,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
            Graphics.FONT_TINY,
            Graphics.FONT_XTINY
        ] as Array<Graphics.FontType>;
    }

    public function getOpticalHeight(dc as Graphics.Dc, font as Graphics.FontType) as Number {
        var rawH = dc.getFontHeight(font);
        var ascent = Graphics.getFontAscent(font);
        if (ascent > 0 && ascent < rawH) {
            var opt = (ascent.toFloat() * 0.82f).toNumber();
            return opt > 10 ? opt : rawH;
        }
        return rawH;
    }

    public function selectNumericFont(
        dc as Graphics.Dc,
        text as String,
        maxWidthPx as Number,
        maxOpticalHeightPx as Number,
        startRank as Number
    ) as Graphics.FontType {
        var startIdx = startRank;
        if (startIdx < 0) { startIdx = 0; }
        if (startIdx >= mNumberFonts.size()) { startIdx = mNumberFonts.size() - 1; }

        for (var i = startIdx; i < mNumberFonts.size(); i += 1) {
            var font = mNumberFonts[i];
            var w = dc.getTextWidthInPixels(text, font);
            var optH = getOpticalHeight(dc, font);
            if (w <= maxWidthPx && optH <= maxOpticalHeightPx) {
                return font;
            }
        }
        return Graphics.FONT_SMALL;
    }

    public function selectLabelFont(
        dc as Graphics.Dc,
        text as String,
        maxWidthPx as Number,
        maxHeightPx as Number,
        startRank as Number
    ) as Graphics.FontType {
        var startIdx = startRank;
        if (startIdx < 0) { startIdx = 0; }
        if (startIdx >= mTextFonts.size()) { startIdx = mTextFonts.size() - 1; }

        for (var i = startIdx; i < mTextFonts.size(); i += 1) {
            var font = mTextFonts[i];
            var w = dc.getTextWidthInPixels(text, font);
            var h = dc.getFontHeight(font);
            if (w <= maxWidthPx && h <= maxHeightPx) {
                return font;
            }
        }
        return Graphics.FONT_XTINY;
    }
}
