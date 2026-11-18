import Toybox.Activity;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class RacePilotView extends WatchUi.DataField {
    private var mEngine as PaceEngine;
    private var mProfile as DeviceProfile;
    private var mFontManager as FontManager;
    private var mLayoutEngine as Layout;

    private var mLastElapsedDistM as Float = 0.0f;
    private var mLastTimerSec as Float = 0.0f;

    // v2.2: FIT custom fields (recorded to activity file)
    private var mFitProj as FitContributor.Field? = null;
    private var mFitAhead as FitContributor.Field? = null;
    private var mFitNeed as FitContributor.Field? = null;

    // v2.2: off-target alert throttle
    private var mLastAlertSec as Float = -9999.0f;

    // Skill 028: Obscurity flags
    private var _obscurity as Number = 0;
    private var _isTopCurved as Boolean = false;
    private var _isBotCurved as Boolean = false;
    private var _isLeftCurved as Boolean = false;
    private var _isRightCurved as Boolean = false;

    // Skill 030: Day/Night polarity
    private var _isDarkBackground as Boolean = true;

    // Skill 029: Layout tier
    private var _layoutTier as Number = 0;

    public function initialize(engine as PaceEngine) {
        DataField.initialize();
        mEngine = engine;
        mProfile = new DeviceProfile();
        mFontManager = new FontManager();
        mLayoutEngine = new Layout(mProfile, mFontManager);
        createFitFields();
    }

    // ============================================================
    // v2.2: Create FIT custom fields (best-effort; null on failure)
    // ============================================================
    private function createFitFields() as Void {
        try {
            mFitProj = createField("projFinish", 0, FitContributor.DATA_TYPE_FLOAT,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "s"});
        } catch (ex) { mFitProj = null; }
        try {
            mFitAhead = createField("aheadBehind", 1, FitContributor.DATA_TYPE_FLOAT,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "s"});
        } catch (ex) { mFitAhead = null; }
        try {
            mFitNeed = createField("needPace", 2, FitContributor.DATA_TYPE_FLOAT,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "s"});
        } catch (ex) { mFitNeed = null; }
    }

    private function updateFitFields(snap as RPDisplaySnapshot) as Void {
        try {
            if (mFitProj != null && snap.projectedFinishSec > 0.0f) {
                mFitProj.setData(snap.projectedFinishSec);
            }
            if (mFitAhead != null && snap.hasTarget && snap.projectedFinishSec > 0.0f) {
                mFitAhead.setData(snap.aheadBehindSec);
            }
            if (mFitNeed != null && snap.needPaceSec > 0.0f) {
                mFitNeed.setData(snap.needPaceSec);
            }
        } catch (ex) {}
    }

    // ============================================================
    // v2.2: Off-target vibration alert (throttled to every 30s)
    // ============================================================
    private function checkAlerts(snap as RPDisplaySnapshot) as Void {
        if (!snap.alertsEnabled) { return; }
        if (!snap.hasTarget || snap.projectedFinishSec <= 0.0f) { return; }
        if (snap.state != STATE_RACING) { return; }
        // Behind target by more than 5 seconds
        if (snap.aheadBehindSec < -5.0f) {
            var now = snap.elapsedSeconds;
            if (now - mLastAlertSec >= 30.0f) {
                mLastAlertSec = now;
                vibrateAlert();
            }
        }
    }

    private function vibrateAlert() as Void {
        try {
            if (Attention has :vibrate) {
                var profiles = new [1];
                profiles[0] = new Attention.VibeProfile(70, 200);
                Attention.vibrate(profiles);
            }
        } catch (ex) {}
    }

    // ============================================================
    // Skill 028/029/030: onLayout
    // ============================================================
    public function onLayout(dc as Graphics.Dc) as Void {
        _obscurity = getObscurityFlags();
        _isTopCurved = (_obscurity & OBSCURE_TOP) != 0;
        _isBotCurved = (_obscurity & OBSCURE_BOTTOM) != 0;
        _isLeftCurved = (_obscurity & OBSCURE_LEFT) != 0;
        _isRightCurved = (_obscurity & OBSCURE_RIGHT) != 0;

        mProfile.updateMetrics(dc.getWidth(), dc.getHeight());
        mProfile.isTopCurved = _isTopCurved;
        mProfile.isBotCurved = _isBotCurved;
        mProfile.isLeftCurved = _isLeftCurved;
        mProfile.isRightCurved = _isRightCurved;

        var w = dc.getWidth();
        var h = dc.getHeight();
        var sw = System.getDeviceSettings().screenWidth;
        var sh = System.getDeviceSettings().screenHeight;
        if (h >= (sh * 80) / 100) {
            _layoutTier = 0;
        } else if (h >= (sh * 42) / 100) {
            _layoutTier = 1;
        } else if (w >= (sw * 80) / 100) {
            _layoutTier = 2;
        } else {
            _layoutTier = 3;
        }
        mProfile.layoutTier = _layoutTier;

        _isDarkBackground = (getBackgroundColor() == Graphics.COLOR_BLACK);
        mProfile.isDarkBackground = _isDarkBackground;
    }

    // ============================================================
    // Skill 031: Timer lifecycle hooks
    // ============================================================
    public function onTimerStart() as Void {
    }

    public function onTimerResume() as Void {
    }

    public function onTimerPause() as Void {
    }

    public function onTimerStop() as Void {
    }

    public function onTimerReset() as Void {
        mLastElapsedDistM = 0.0f;
        mLastTimerSec = 0.0f;
        mLastAlertSec = -9999.0f;
        mEngine.reset();
    }

    // ============================================================
    // Skill 027: compute(info) — 1Hz data accumulation
    // ============================================================
    public function compute(info as Activity.Info) as Void {
        var rawSpeedMps = (info != null && info.currentSpeed != null) ? info.currentSpeed.toFloat() : 0.0f;
        var rawDistM = (info != null && info.elapsedDistance != null) ? info.elapsedDistance.toFloat() : 0.0f;
        var elapsedMs = (info != null && info.timerTime != null) ? info.timerTime : 0;
        var timerState = (info != null && info.timerState != null) ? info.timerState : Activity.TIMER_STATE_OFF;
        var gpsAccuracy = (info != null) ? info.currentLocationAccuracy : null;
        var headingRad = (info != null && info.currentHeading != null) ? info.currentHeading.toFloat() : null;
        var altitudeM = (info != null && info.altitude != null) ? info.altitude.toFloat() : null;
        var cadenceSpm = (info != null) ? info.currentCadence : null;

        var subSport = null;
        var profileInfo = Activity.getProfileInfo();
        if (profileInfo != null) {
            subSport = profileInfo.subSport;
        }

        mLastElapsedDistM = rawDistM;
        mLastTimerSec = elapsedMs > 0 ? (elapsedMs.toFloat() / 1000.0f) : 0.0f;

        var snap = mEngine.updateFromValues(
            rawSpeedMps,
            rawDistM,
            elapsedMs,
            timerState,
            gpsAccuracy,
            headingRad,
            altitudeM,
            cadenceSpm,
            subSport
        );

        updateFitFields(snap);
        checkAlerts(snap);
    }

    // ============================================================
    // Skill 027: onUpdate(dc) — render only when visible
    // ============================================================
    public function onUpdate(dc as Graphics.Dc) as Void {
        _isDarkBackground = (getBackgroundColor() == Graphics.COLOR_BLACK);
        mProfile.isDarkBackground = _isDarkBackground;

        var snapshot = mEngine.getSnapshot();
        mLayoutEngine.render(dc, snapshot);
    }

    // Skill 032: Lap button event
    public function onTimerLap() as Void {
        mEngine.onTimerLap(mLastElapsedDistM, mLastTimerSec);
    }
}
