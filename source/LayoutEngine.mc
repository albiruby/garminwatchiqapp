import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Split-instrument grid (see docs/DESIGN-NOTES.md).
//
//            |  DATE
//     HOURS  |  MOVE BAR
//            |  STEPS
//   MINUTES  |  74%  2,518 TO GO
//            |  --------------
//            |  KM        5.24      readout rows: label left, value right,
//            |  KCAL     1,834      goal bar underneath
//                 battery
//
// A vertical spine at the centre separates time (left, right-aligned) from readings
// (right, left-aligned). Minimal drops the spine and stacks the time in the centre.
// Dial, Horizon and Stack have their own grids (positions below, drawing in source/faces).
// Fonts are Barlow bitmap fonts cropped to their ink, so a VCENTER text occupies
// exactly y +/- height/2. Offsets are for a 195 px radius; LayoutAudit checks them.
class LayoutEngine {

    static const ROW_BAR_DY = 19;   // readout row: goal bar below the value centre (>= 3 px clear)
    static const MINI_BAR_H = 4;

    var w as Number = 390;
    var h as Number = 390;
    var cx as Number = 195;
    var cy as Number = 195;
    var r as Number = 195;
    var k as Float = 1.0;
    var preset as Number = -1;
    var linear as Boolean = false;   // spine gauge / horizontal bar instead of the ring
    var ringed as Boolean = true;    // the bezel goal track is drawn

    var ringR as Number = 0;      // centre line of the goal track
    var ringW as Number = 10;
    var lapR as Number = 0;       // overshoot lap
    var lapW as Number = 3;
    var contentR as Number = 0;   // content must stay inside this radius

    // spine and columns
    var spineTop as Number = 0;
    var spineBottom as Number = 0;
    var gaugeTop as Number = 0;   // linear style: the spine becomes this gauge
    var gaugeBottom as Number = 0;
    var leftX as Number = 0;      // time column, right edge
    var rightX as Number = 0;     // readout column, left edge
    var colW as Number = 0;       // readout column width

    // time
    var hoursY as Number = 0;
    var minutesY as Number = 0;
    var markerY as Number = -1;   // AM/PM beside the time; -1 = appended to the date
    var secondsY as Number = -1;  // -1 = no seconds in this preset

    // readings
    var dateY as Number = 0;
    var dateLeft as Boolean = false; // Data Dense: the date heads the time column
    var moveY as Number = -1;
    var stepsY as Number = 0;
    var statusY as Number = 0;
    var dividerY as Number = -1;
    var rows as Array<Number> = [];

    // Minimal footer and its horizontal track
    var footerY as Number = 0;
    var barY as Number = 0;
    var barW as Number = 0;
    var barH as Number = 0;

    var batteryY as Number = 0;

    // Dial
    var sideDX as Number = 0;        // readouts at 9 and 3 o'clock
    var sideY as Number = 0;
    // Horizon: rising level from levelBottom (0 %) to levelGoal (100 %)
    var heroY as Number = 0;
    var levelBottom as Number = 0;
    var levelGoal as Number = 0;
    // Stack: goal columns
    var colBottom as Number = 0;
    var colGoal as Number = 0;       // 100 % line
    var colTop as Number = 0;        // overshoot is drawn up to here
    var colPitch as Number = 0;
    var colWidth as Number = 0;
    var valueY as Number = 0;
    var labelY as Number = 0;
    var timeY as Number = 0;         // single-line time (Horizon, Stack)

    var timeFont = Graphics.FONT_NUMBER_HOT;
    var heroFont = null;
    var stepsFont = Graphics.FONT_MEDIUM;
    var valueFont = Graphics.FONT_TINY;
    var textFont = Graphics.FONT_XTINY;
    var labelFont = Graphics.FONT_XTINY;

    private var _loadedKey as Number = -1;

    function initialize() {
    }

    function compute(width as Number, height as Number, s as SettingsManager) as Void {
        w = width;
        h = height;
        cx = w / 2;
        cy = h / 2;
        r = (w < h ? w : h) / 2;
        k = r / 195.0;
        preset = s.layout;
        ringed = preset != SettingsManager.LAYOUT_HORIZON && preset != SettingsManager.LAYOUT_STACK;
        // linear style applies to the spine faces and Minimal; Dial keeps its ring
        linear = s.goalStyle == SettingsManager.STYLE_LINEAR && preset <= SettingsManager.LAYOUT_DENSE;
        loadFonts();

        var weights = [6, 10, 14];
        ringW = px(weights[s.trackWeight]);
        ringR = r - px(4) - ringW / 2;
        lapW = ringW / 3 < 2 ? 2 : ringW / 3;
        lapR = ringR - ringW / 2 - px(5) - lapW / 2;
        // stay 6 px inside the lap's inner edge; without a ring keep a bezel margin
        var open = linear || !ringed;
        contentR = open ? r - px(14) : lapR - lapW / 2 - px(6);
        barH = linear ? px(weights[s.trackWeight]) : MINI_BAR_H;
        batteryY = cy + px(open ? 170 : 166);
        leftX = cx - px(14);
        rightX = cx + px(14);
        colW = px(98);
        markerY = -1;
        secondsY = -1;
        moveY = -1;
        dividerY = -1;
        dateLeft = false;

        if (preset == SettingsManager.LAYOUT_MINIMAL) {
            dateY = cy - px(124);
            hoursY = cy - px(54);
            minutesY = cy + px(54);
            barY = cy + px(118);
            barW = px(170);
            footerY = cy + px(linear ? 140 : 124);
            rows = [];
        } else if (preset == SettingsManager.LAYOUT_DIAL) {
            dateY = cy - px(128);
            sideDX = px(100);
            sideY = cy - px(6);
            stepsY = cy + px(82);
            statusY = cy + px(114);
            rows = [];
        } else if (preset == SettingsManager.LAYOUT_HORIZON) {
            timeY = cy - px(122);
            dateY = cy - px(64);
            heroY = cy + px(4);
            statusY = cy + px(62);
            valueY = cy + px(104);
            levelBottom = cy + px(172);
            levelGoal = cy - px(86);
            rows = [];
        } else if (preset == SettingsManager.LAYOUT_STACK) {
            timeY = cy - px(104);
            dateY = cy - px(58);
            colBottom = cy + px(66);
            colGoal = cy - px(22);
            colTop = cy - px(40);
            colPitch = px(48);
            colWidth = px(26);
            valueY = cy + px(86);
            labelY = cy + px(110);
            rows = [];
        } else if (preset == SettingsManager.LAYOUT_DENSE) {
            dateLeft = true;
            dateY = cy - px(112);
            // sized for the tallest numerals (outline, 60 px)
            hoursY = cy - px(68);
            minutesY = cy - px(2);
            stepsY = cy + px(46);
            statusY = cy + px(76);
            moveY = cy - px(112);
            rows = [cy - px(84), cy - px(44), cy - px(4), cy + px(36), cy + px(76)];
            spineTop = cy - px(122);
            spineBottom = cy + px(96);
            gaugeTop = cy - px(95);
            gaugeBottom = cy + px(86);
        } else {
            hoursY = cy - px(46);
            minutesY = cy + px(46);
            markerY = cy - px(104);
            secondsY = cy + px(104);
            dateY = cy - px(96);
            moveY = cy - px(78);
            stepsY = cy - px(52);
            statusY = cy - px(20);
            dividerY = cy - px(2);
            rows = [cy + px(18), cy + px(56), cy + px(94)];
            spineTop = cy - px(106);
            spineBottom = cy + px(114);
            gaugeTop = cy - px(86);
            gaugeBottom = cy + px(86);
        }
    }

    // Fonts for the active preset and look only, to keep the watch-face heap small.
    // Numerals: solid (Carbon, Signal), outline (Reflective), light (Field).
    private function loadFonts() as Void {
        var num = ThemeManager.numerals;
        var key = preset * 10 + num;
        if (key == _loadedKey) {
            return;
        }
        _loadedKey = key;
        timeFont = null;
        stepsFont = null;
        heroFont = null;
        var large = [Rez.Fonts.TimeL, Rez.Fonts.TimeLO, Rez.Fonts.TimeLL];
        var medium = [Rez.Fonts.TimeM, Rez.Fonts.TimeMO, Rez.Fonts.TimeML];
        var small = [Rez.Fonts.TimeS, Rez.Fonts.TimeSO, Rez.Fonts.TimeSL];
        var hero = [Rez.Fonts.Hero, Rez.Fonts.HeroO, Rez.Fonts.HeroL];
        if (preset == SettingsManager.LAYOUT_MINIMAL) {
            timeFont = WatchUi.loadResource(large[num]);
        } else if (preset == SettingsManager.LAYOUT_DENSE || preset == SettingsManager.LAYOUT_STACK) {
            timeFont = WatchUi.loadResource(small[num]);
            stepsFont = WatchUi.loadResource(Rez.Fonts.StepsS);
        } else if (preset == SettingsManager.LAYOUT_HORIZON) {
            timeFont = WatchUi.loadResource(small[num]);
            heroFont = WatchUi.loadResource(hero[num]);
        } else if (preset == SettingsManager.LAYOUT_DIAL) {
            stepsFont = WatchUi.loadResource(Rez.Fonts.Steps);
        } else {
            timeFont = WatchUi.loadResource(medium[num]);
            stepsFont = WatchUi.loadResource(Rez.Fonts.Steps);
        }
        if (valueFont == Graphics.FONT_TINY) {
            valueFont = WatchUi.loadResource(Rez.Fonts.Value);
            textFont = WatchUi.loadResource(Rez.Fonts.Text);
            labelFont = WatchUi.loadResource(Rez.Fonts.Label);
        }
    }

    // Half-width of the content circle at a given y (0 when outside).
    function chord(y as Number) as Number {
        var dy = (y - cy).abs();
        if (dy >= contentR) {
            return 0;
        }
        return Math.sqrt(contentR * contentR - dy * dy).toNumber();
    }

    private function px(v as Number) as Number {
        return Math.round(v * k).toNumber();
    }
}
