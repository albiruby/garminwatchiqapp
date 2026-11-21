import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

(:test)
function thousandsFormatting(logger as Logger) as Boolean {
    Test.assertEqual(FormatUtils.thousands(0), "0");
    Test.assertEqual(FormatUtils.thousands(999), "999");
    Test.assertEqual(FormatUtils.thousands(1000), "1,000");
    Test.assertEqual(FormatUtils.thousands(7482), "7,482");
    Test.assertEqual(FormatUtils.thousands(48213), "48,213");
    Test.assertEqual(FormatUtils.thousands(1002003), "1,002,003");
    Test.assertEqual(FormatUtils.compact(950), "950");
    Test.assertEqual(FormatUtils.compact(9549), "9.5K");
    Test.assertEqual(FormatUtils.compact(12999), "12K");
    return true;
}

(:test)
function distanceFormatting(logger as Logger) as Boolean {
    Test.assertEqual(FormatUtils.distance(0, true), "0.00");
    Test.assertEqual(FormatUtils.distance(524000, true), "5.24");
    Test.assertEqual(FormatUtils.distance(529999, true), "5.29");      // rounds down
    Test.assertEqual(FormatUtils.distance(4231000, true), "42.3");
    Test.assertEqual(FormatUtils.distance(15000000, true), "150");
    Test.assertEqual(FormatUtils.distance(160934, false), "0.99");     // just under a mile
    Test.assertEqual(FormatUtils.distance(1609344, false), "10.0");
    Test.assertEqual(FormatUtils.distanceUnit(true), "KM");
    Test.assertEqual(FormatUtils.distanceUnit(false), "MI");
    return true;
}

(:test)
function clockFormatting(logger as Logger) as Boolean {
    var t = FormatUtils.clock(0, 5, false);
    Test.assertEqual(t[0], "00:05");
    Test.assertEqual(t[1], "");
    t = FormatUtils.clock(0, 5, true);
    Test.assertEqual(t[0], "12:05");
    Test.assertEqual(t[1], "AM");
    t = FormatUtils.clock(9, 7, true);
    Test.assertEqual(t[0], "9:07");
    t = FormatUtils.clock(12, 0, true);
    Test.assertEqual(t[0], "12:00");
    Test.assertEqual(t[1], "PM");
    t = FormatUtils.clock(23, 59, true);
    Test.assertEqual(t[0], "11:59");
    Test.assertEqual(t[1], "PM");
    t = FormatUtils.clock(23, 59, false);
    Test.assertEqual(t[0], "23:59");
    return true;
}

(:test)
function settingsValidation(logger as Logger) as Boolean {
    Test.assertEqual(SettingsManager.validNumber(null, 7, 0, 10), 7);
    Test.assertEqual(SettingsManager.validNumber("3", 7, 0, 10), 7);
    Test.assertEqual(SettingsManager.validNumber(11, 7, 0, 10), 7);
    Test.assertEqual(SettingsManager.validNumber(-1, 7, 0, 10), 7);
    Test.assertEqual(SettingsManager.validNumber(4, 7, 0, 10), 4);
    Test.assertEqual(SettingsManager.validNumber(4.9, 7, 0, 10), 4);
    Test.assertEqual(SettingsManager.validNumber(5l, 7, 0, 10), 5);
    Test.assertEqual(SettingsManager.validDistance(null), 0.0);
    Test.assertEqual(SettingsManager.validDistance(-3.0), 0.0);
    Test.assertEqual(SettingsManager.validDistance(500.0), 0.0);
    Test.assertEqual(SettingsManager.validDistance(8), 8.0);
    Test.assertEqual(SettingsManager.validDistance(12.5), 12.5);
    return true;
}

// Defaults load cleanly and stay inside their ranges.
(:test)
function settingsDefaults(logger as Logger) as Boolean {
    var s = new SettingsManager();
    Test.assert(s.layout >= 0 && s.layout <= 2);
    Test.assert(s.goalStyle >= 0 && s.goalStyle <= 2);
    Test.assert(s.theme >= 0 && s.theme <= 8);
    Test.assert(s.look >= 0 && s.look <= 3);
    Test.assert(s.stepGoal >= 500 && s.stepGoal <= 100000);
    Test.assert(s.distanceTarget >= 0.0);
    return true;
}

(:test)
function lookTokens(logger as Logger) as Boolean {
    ThemeManager.apply(ThemeManager.LOOK_CARBON, 0);
    Test.assertEqual(ThemeManager.accent(), 0xB7F34A);                 // look default
    Test.assertEqual(ThemeManager.progressColor(ActivityGoalEngine.STATE_START), ThemeManager.accentDim());
    Test.assertEqual(ThemeManager.progressColor(ActivityGoalEngine.STATE_NEAR), ThemeManager.accent());
    ThemeManager.apply(ThemeManager.LOOK_CARBON, 4);                   // Pure White accent
    Test.assert(ThemeManager.lapColor() != ThemeManager.accent());     // lap stays visible
    ThemeManager.apply(99, 99);                                        // invalid -> Carbon + its accent
    Test.assertEqual(ThemeManager.look, ThemeManager.LOOK_CARBON);
    Test.assertEqual(ThemeManager.accent(), 0xB7F34A);
    // Signal: neutral until the goal is met, accent afterwards
    ThemeManager.apply(ThemeManager.LOOK_SIGNAL, 0);
    Test.assertEqual(ThemeManager.textAccent(ActivityGoalEngine.STATE_NEAR), ThemeManager.TEXT);
    Test.assertEqual(ThemeManager.textAccent(ActivityGoalEngine.STATE_COMPLETED), ThemeManager.accent());
    Test.assertEqual(ThemeManager.progressColor(ActivityGoalEngine.STATE_BUILDING), ThemeManager.TEXT);
    // each look has its own numerals / rules / cursor
    ThemeManager.apply(ThemeManager.LOOK_REFLECTIVE, 0);
    Test.assertEqual(ThemeManager.numerals, ThemeManager.NUM_OUTLINE);
    Test.assertEqual(ThemeManager.needleStyle, ThemeManager.NEEDLE_CHEVRON);
    ThemeManager.apply(ThemeManager.LOOK_FIELD, 0);
    Test.assertEqual(ThemeManager.numerals, ThemeManager.NUM_LIGHT);
    Test.assertEqual(ThemeManager.dividerStyle, ThemeManager.DIV_NONE);
    ThemeManager.apply(ThemeManager.LOOK_CARBON, 0);
    return true;
}

// Text colours of every look and accent reach WCAG AA (4.5:1) on black.
(:test)
function lookContrast(logger as Logger) as Boolean {
    for (var l = 0; l < ThemeManager.LOOKS.size(); l++) {
        var look = ThemeManager.LOOKS[l] as Array;
        Test.assert(contrastOnBlack(look[0] as Number) >= 4.5);
        Test.assert(contrastOnBlack(look[1] as Number) >= 4.5);
    }
    for (var a = 0; a < ThemeManager.ACCENTS.size(); a++) {
        var c = (ThemeManager.ACCENTS[a] as Array<Number>)[0];
        logger.debug("accent " + a + " contrast " + contrastOnBlack(c).format("%.2f"));
        Test.assert(contrastOnBlack(c) >= 4.5);
    }
    return true;
}

function contrastOnBlack(rgb as Number) as Float {
    var ch = [(rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF];
    var lin = [0.0, 0.0, 0.0];
    for (var i = 0; i < 3; i++) {
        var v = (ch[i] as Number) / 255.0;
        lin[i] = v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4).toFloat();
    }
    var lum = 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
    return ((lum + 0.05) / 0.05).toFloat();
}

// Release guard: screenshot fixtures must be off in committed source.
(:test)
function previewIsOff(logger as Logger) as Boolean {
    Test.assert(!Preview.ON);
    return true;
}
