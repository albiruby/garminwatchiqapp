import Toybox.Graphics;
import Toybox.Lang;

// Font tokens. Connect IQ font enums are not CSS pixels; these map semantic
// roles to Garmin system fonts so the visual hierarchy holds on a 390px round
// AMOLED. Score uses the NUMBER font for tabular, dominant digits.

module Typography {
    function title() as Graphics.FontDefinition { return Graphics.FONT_MEDIUM; }
    function score() as Graphics.FontDefinition { return Graphics.FONT_NUMBER_HOT; }
    function status() as Graphics.FontDefinition { return Graphics.FONT_LARGE; }
    function label() as Graphics.FontDefinition { return Graphics.FONT_TINY; }
    function value() as Graphics.FontDefinition { return Graphics.FONT_SMALL; }
    function body() as Graphics.FontDefinition { return Graphics.FONT_XTINY; }
    // A slightly larger value font for hero context numbers (TODAY screen).
    function bigValue() as Graphics.FontDefinition { return Graphics.FONT_MEDIUM; }
}
