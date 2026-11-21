import Toybox.Lang;

// Screenshot fixtures, rewritten by tools/capture.ps1. ON must be false in every
// release build: when ON, metrics come from these constants instead of the device.
module Preview {
    const ON = false;
    const LAYOUT = 0;
    const STYLE = 0;
    const THEME = 0;
    const STEPS = 7482;
    const GOAL = 10000;
    const HOUR = 10;
    const MIN = 9;
    const SEC = 42;
    const SLEEP = false;
    const TWELVE = false;
    const DATE = "SAT 21 NOV";
    const WEIGHT = 1;
    const LOOK = 0;

    function apply(s as SettingsManager) as Void {
        s.layout = LAYOUT;
        s.goalStyle = STYLE;
        s.theme = THEME;
        s.stepGoalMode = 0;
        s.distanceTarget = 8.0;
        s.calorieTarget = 2600;
        s.showSeconds = true;
        s.trackWeight = WEIGHT;
        s.look = LOOK;
        ThemeManager.apply(LOOK, THEME);
    }

    function metrics() as Metrics {
        var m = new Metrics();
        m.steps = STEPS;
        m.stepGoal = GOAL;
        m.distanceCm = 524000;
        m.calories = 1834;
        m.intensityDay = 12;
        m.intensityWeek = 85;
        m.intensityWeekGoal = 150;
        m.moveBar = 2;
        m.floors = 7;
        m.floorsGoal = 10;
        m.heartRate = 64;
        m.battery = 82.0;
        m.batteryDays = 6;
        m.metric = true;
        return m;
    }
}
