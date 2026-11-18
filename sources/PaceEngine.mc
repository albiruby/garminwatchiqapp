import Toybox.Activity;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.System;

enum RPRunMode {
    MODE_AUTO = 0,
    MODE_OUTDOOR_GPS = 1,
    MODE_TRACK = 2,
    MODE_TREADMILL = 3
}

class RPDisplaySnapshot {
    public var state as RPState = STATE_IDLE;
    public var stateLabel as String = "READY";
    public var activeRunMode as Number = MODE_OUTDOOR_GPS;

    public var hasTarget as Boolean = false;
    public var targetDistM as Float = 5000.0f;
    public var targetTimeSec as Float = 1800.0f;
    public var goalPaceSec as Float = 360.0f;

    public var lapPaceSec as Float = 0.0f;
    public var paceUnitStr as String = "/km";
    public var distanceMeters as Float = 0.0f;
    public var elapsedSeconds as Float = 0.0f;
    public var projectedFinishSec as Float = 0.0f;
    public var aheadBehindSec as Float = 0.0f;
    public var isAhead as Boolean = true;
    public var isOnTarget as Boolean = false;
    public var needPaceSec as Float = 0.0f;
    public var hideNeedPace as Boolean = false;
    public var freezeProjections as Boolean = false;

    public var isTrackMode as Boolean = false;
    public var trackLapLengthM as Float = 400.0f;
    public var lapCountText as String = "0/12.5";

    public var debugMode as Boolean = false;
    public var confidence as Float = 0.0f;
    public var isPaceLocked as Boolean = false;
    public var isProjectionLocked as Boolean = false;
    public var rejectionRatePct as Float = 0.0f;
    public var paceVarianceSec as Float = 0.0f;

    // v2.2 display config
    public var isImperial as Boolean = false;
    public var distanceUnitStr as String = "km";
    public var engineName as String = "OUTDOOR";
    public var gpsQuality as Number = 0;
    public var themeMode as Number = 0;
    public var accentIndex as Number = 0;
    public var layoutMode as Number = 0;
    public var alertsEnabled as Boolean = true;

    public function initialize() {}
}

class PaceEngine {
    private var mStateMachine as RunStateMachine;
    private var mGpsEngine as GPSEngine;
    private var mTrackEngine as TrackEngine;
    private var mTreadmillEngine as TreadmillEngine;
    private var mPaceFilter as PaceFilter;
    private var mPredictionBuffer as PredictionBuffer;
    private var mConfidenceScore as ConfidenceScore;
    private var mTelemetry as TelemetryLayer;
    private var mSnapshot as RPDisplaySnapshot;
    private var mNeedPaceBuf as NeedPaceBuffer;

    private var mPresetId as Number = 0;
    private var mCustomDistM as Float = 5000.0f;
    private var mCustomTimeSec as Float = 1800.0f;
    private var mConfiguredRunType as Number = MODE_AUTO;
    private var mTrackLapLenM as Number = 400;
    private var mDebugMode as Boolean = false;

    // v2.2 display config
    private var mIsMetric as Boolean = true;
    private var mAlerts as Boolean = true;
    private var mTheme as Number = 0;
    private var mAccent as Number = 0;
    private var mLayoutMode as Number = 0;

    private var mAutoGpsLatched as Boolean = false;
    private var mHasTarget as Boolean = false;
    private var mTargetDistM as Float = 0.0f;
    private var mTargetTimeSec as Float = 0.0f;

    public function initialize() {
        mStateMachine = new RunStateMachine();
        mGpsEngine = new GPSEngine();
        mTrackEngine = new TrackEngine(400);
        mTreadmillEngine = new TreadmillEngine(100);
        mPaceFilter = new PaceFilter(50);
        mPredictionBuffer = new PredictionBuffer();
        mConfidenceScore = new ConfidenceScore();
        mTelemetry = new TelemetryLayer();
        mSnapshot = new RPDisplaySnapshot();
        mNeedPaceBuf = new NeedPaceBuffer();
        // Default units from device; refine when settings load
        var ds = System.getDeviceSettings();
        if (ds != null) {
            mIsMetric = (ds.paceUnits == System.UNIT_METRIC);
        }
        resolveTarget();
    }

    public function reset() as Void {
        mStateMachine.reset();
        mGpsEngine.reset();
        mTrackEngine.reset();
        mTreadmillEngine.reset();
        mPaceFilter.reset();
        mPredictionBuffer.reset();
        mTelemetry.reset();
        mNeedPaceBuf.reset();
        mAutoGpsLatched = false;
    }

    public function applySettings(
        presetId as Number,
        customDistM as Number,
        customTimeMin as Number,
        runType as Number,
        treadmillCalib as Number,
        trackLapLen as Number,
        paceSmoothing as Number,
        debugMode as Boolean
    ) as Void {
        var targetChanged = (
            mPresetId != presetId ||
            mCustomDistM != customDistM.toFloat() ||
            mCustomTimeSec != (customTimeMin.toFloat() * 60.0f) ||
            mTrackLapLenM != trackLapLen
        );

        mPresetId = presetId;
        mCustomDistM = customDistM > 0 ? customDistM.toFloat() : 5000.0f;
        mCustomTimeSec = customTimeMin > 0 ? (customTimeMin.toFloat() * 60.0f) : 1800.0f;
        // Validate runType: 0=Auto, 1=Outdoor, 2=Track, 3=Treadmill
        if (runType < MODE_AUTO || runType > MODE_TREADMILL) {
            mConfiguredRunType = MODE_AUTO;
        } else {
            mConfiguredRunType = runType;
        }
        mTrackLapLenM = trackLapLen > 0 ? trackLapLen : 400;
        mDebugMode = debugMode;

        mTreadmillEngine.setCalibration(treadmillCalib);
        mTrackEngine.setTrackLapLength(mTrackLapLenM);
        mPaceFilter.setSmoothing(paceSmoothing);

        resolveTarget();
        if (targetChanged) {
            mPredictionBuffer.reset();
        }
    }

    public function onTimerLap(rawDistM as Float, elapsedSec as Float) as Void {
        mTrackEngine.onHardwareLap(rawDistM, elapsedSec);
        mTreadmillEngine.onHardwareLap(rawDistM, elapsedSec);
    }

    // v2.2: display/units/alerts configuration
    public function applyDisplaySettings(units as Number, alerts as Boolean, theme as Number, accent as Number, layoutMode as Number) as Void {
        // units: 0=auto, 1=metric, 2=imperial
        if (units == 1) {
            mIsMetric = true;
        } else if (units == 2) {
            mIsMetric = false;
        } else {
            var ds = System.getDeviceSettings();
            if (ds != null) {
                mIsMetric = (ds.paceUnits == System.UNIT_METRIC);
            }
        }
        mAlerts = alerts;
        mTheme = (theme >= 0 && theme <= 1) ? theme : 0;
        mAccent = (accent >= 0 && accent <= 4) ? accent : 0;
        mLayoutMode = (layoutMode >= 0 && layoutMode <= 3) ? layoutMode : 0;
    }

    private function resolveTarget() as Void {
        if (mPresetId <= 0) {
            mHasTarget = false;
            mTargetDistM = 0.0f;
            mTargetTimeSec = 0.0f;
            return;
        }

        mHasTarget = true;
        if (mPresetId == 45) {
            mTargetDistM = mCustomDistM;
            mTargetTimeSec = mCustomTimeSec;
            return;
        }

        var fiveKMinutes = [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 30, 32, 35] as Array<Number>;
        if (mPresetId >= 1 && mPresetId <= 14) {
            mTargetDistM = 5000.0f;
            mTargetTimeSec = fiveKMinutes[mPresetId - 1].toFloat() * 60.0f;
            return;
        }

        var tenKMinutes = [40, 42, 45, 48, 50, 52, 55, 58, 60, 65, 70] as Array<Number>;
        if (mPresetId >= 15 && mPresetId <= 25) {
            mTargetDistM = 10000.0f;
            mTargetTimeSec = tenKMinutes[mPresetId - 15].toFloat() * 60.0f;
            return;
        }

        var hmMinutes = [80, 85, 90, 95, 100, 105, 110, 120, 135, 150] as Array<Number>;
        if (mPresetId >= 26 && mPresetId <= 35) {
            mTargetDistM = 21097.5f;
            mTargetTimeSec = hmMinutes[mPresetId - 26].toFloat() * 60.0f;
            return;
        }

        var fmMinutes = [150, 165, 180, 195, 210, 225, 240, 270, 300] as Array<Number>;
        if (mPresetId >= 36 && mPresetId <= 44) {
            mTargetDistM = 42195.0f;
            mTargetTimeSec = fmMinutes[mPresetId - 36].toFloat() * 60.0f;
            return;
        }

        mTargetDistM = mCustomDistM;
        mTargetTimeSec = mCustomTimeSec;
    }

    public function detectActiveRunMode(gpsAccuracy as Number?, subSport as Number?) as Number {
        if (mConfiguredRunType == MODE_OUTDOOR_GPS ||
            mConfiguredRunType == MODE_TRACK ||
            mConfiguredRunType == MODE_TREADMILL) {
            return mConfiguredRunType;
        }

        if (subSport != null) {
            if (subSport == Activity.SUB_SPORT_TRACK) {
                return MODE_TRACK;
            }
            if (subSport == Activity.SUB_SPORT_TREADMILL || subSport == Activity.SUB_SPORT_INDOOR_RUNNING) {
                return MODE_TREADMILL;
            }
        }

        // Latch OUTDOOR once a real GPS fix has been seen this session, so a
        // tunnel / signal dropout cannot flip the run into treadmill mode
        // (which would apply treadmill calibration to outdoor distance).
        if (gpsAccuracy != null && gpsAccuracy >= Position.QUALITY_POOR) {
            mAutoGpsLatched = true;
        }
        if (mAutoGpsLatched) {
            return MODE_OUTDOOR_GPS;
        }
        if (gpsAccuracy == null || gpsAccuracy <= Position.QUALITY_NOT_AVAILABLE) {
            return MODE_TREADMILL;
        }
        return MODE_OUTDOOR_GPS;
    }

    public function updateFromValues(
        rawSpeedMps as Float,
        rawDistM as Float,
        elapsedMs as Number,
        timerState as Number,
        gpsAccuracy as Number?,
        headingRad as Float?,
        altitudeM as Float?,
        cadenceSpm as Number?,
        subSport as Number?
    ) as RPDisplaySnapshot {
        var activeMode = detectActiveRunMode(gpsAccuracy, subSport);
        var elapsedSec = elapsedMs > 0 ? (elapsedMs.toFloat() / 1000.0f) : 0.0f;

        var effectiveDistM = rawDistM > 0.0f ? rawDistM : 0.0f;
        if (activeMode == MODE_TREADMILL) {
            effectiveDistM = mTreadmillEngine.getCalibratedDistanceM(effectiveDistM);
        }

        var needsGps = (activeMode == MODE_OUTDOOR_GPS);
        var hasGpsLock = (gpsAccuracy != null && gpsAccuracy >= Position.QUALITY_USABLE);

        var state = mStateMachine.update(
            mHasTarget,
            needsGps,
            hasGpsLock,
            timerState,
            effectiveDistM,
            mTargetDistM,
            rawSpeedMps,
            elapsedMs
        );

        var unitLenM = (activeMode == MODE_TRACK) ? mTrackEngine.getTrackLapLengthM() : 1000.0f;
        var unitStr;
        if (activeMode == MODE_TRACK) {
            unitStr = "/" + mTrackLapLenM.format("%d") + "m";
        } else {
            unitStr = mIsMetric ? "/km" : "/mi";
        }

        var engineSpeedMps = 0.0f;
        var rawUnitPaceSec = 0.0f;
        var wasRejected = false;
        var hysteresisSec = 1.5f;

        if (activeMode == MODE_TRACK) {
            rawUnitPaceSec = mTrackEngine.update(effectiveDistM, elapsedSec, rawSpeedMps);
            if (rawUnitPaceSec > 0.0f) {
                engineSpeedMps = unitLenM / rawUnitPaceSec;
            }
            hysteresisSec = mTrackEngine.getHysteresisSec();
        } else if (activeMode == MODE_TREADMILL) {
            engineSpeedMps = mTreadmillEngine.update(rawSpeedMps, rawDistM, elapsedSec);
            wasRejected = mTreadmillEngine.wasLastSampleRejected();
            if (engineSpeedMps > 0.0f) {
                rawUnitPaceSec = 1000.0f / engineSpeedMps;
            }
        } else {
            engineSpeedMps = mGpsEngine.update(
                rawSpeedMps,
                effectiveDistM,
                elapsedMs,
                gpsAccuracy,
                headingRad,
                altitudeM,
                cadenceSpm
            );
            wasRejected = mGpsEngine.wasLastSampleRejected();
            if (engineSpeedMps > 0.0f) {
                rawUnitPaceSec = 1000.0f / engineSpeedMps;
            }
        }

        mTelemetry.recordSample(rawUnitPaceSec, wasRejected, gpsAccuracy);
        var varianceSec = mTelemetry.getPaceVarianceSec();
        var confidence = mConfidenceScore.compute(
            activeMode,
            gpsAccuracy,
            engineSpeedMps,
            varianceSec,
            cadenceSpm
        );

        var filteredPaceSec = mPaceFilter.filter(rawUnitPaceSec, confidence, hysteresisSec);
        var ewmaPaceSec = mPaceFilter.getEwmaPaceSec();
        var ewmaSpeedMps = (ewmaPaceSec > 0.0f) ? (unitLenM / ewmaPaceSec) : engineSpeedMps;
        var filteredSpeedMps = (filteredPaceSec > 0.0f) ? (unitLenM / filteredPaceSec) : engineSpeedMps;

        var freezeProj = mStateMachine.shouldFreezeProjections();
        var projectedFinishSec = 0.0f;
        var aheadBehindSec = 0.0f;
        var needPaceSec = 0.0f;

        if (mHasTarget && mTargetDistM > 0.0f && mTargetTimeSec > 0.0f) {
            projectedFinishSec = mPredictionBuffer.computeProjectedFinish(
                mTargetDistM,
                effectiveDistM,
                elapsedSec,
                engineSpeedMps,
                filteredSpeedMps,
                ewmaSpeedMps,
                confidence,
                freezeProj
            );

            if (projectedFinishSec > 0.0f) {
                aheadBehindSec = mTargetTimeSec - projectedFinishSec;
            }

            var remainingDistM = mTargetDistM - effectiveDistM;
            var remainingTimeSec = mTargetTimeSec - elapsedSec;
            if (remainingDistM > 1.0f && remainingTimeSec > 0.0f) {
                var remainingUnits = remainingDistM / unitLenM;
                if (remainingUnits > 0.01f) {
                    var rawNeedPace = remainingTimeSec / remainingUnits;
                    // Buffer need pace to prevent per-second jitter
                    needPaceSec = mNeedPaceBuf.updatePace(rawNeedPace, elapsedSec);
                }
            }
        }

        mSnapshot.state = state;
        mSnapshot.stateLabel = mStateMachine.getStateLabel();
        mSnapshot.activeRunMode = activeMode;
        mSnapshot.hasTarget = mHasTarget;
        mSnapshot.targetDistM = mTargetDistM;
        mSnapshot.targetTimeSec = mTargetTimeSec;
        mSnapshot.goalPaceSec = (mHasTarget && mTargetDistM > 0.0f)
            ? (mTargetTimeSec / (mTargetDistM / unitLenM))
            : 0.0f;

        mSnapshot.lapPaceSec = filteredPaceSec;
        mSnapshot.paceUnitStr = unitStr;
        mSnapshot.distanceMeters = effectiveDistM;
        mSnapshot.elapsedSeconds = elapsedSec;
        mSnapshot.projectedFinishSec = projectedFinishSec;
        mSnapshot.aheadBehindSec = aheadBehindSec;
        mSnapshot.isOnTarget = (aheadBehindSec.abs() <= 2.0f);
        mSnapshot.isAhead = (aheadBehindSec >= -2.0f);
        mSnapshot.needPaceSec = needPaceSec;
        mSnapshot.hideNeedPace = mStateMachine.shouldHideNeedPace() || (needPaceSec <= 0.0f);
        mSnapshot.freezeProjections = freezeProj;

        mSnapshot.isTrackMode = (activeMode == MODE_TRACK);
        mSnapshot.trackLapLengthM = mTrackEngine.getTrackLapLengthM();
        mSnapshot.lapCountText = mTrackEngine.formatLapCount(effectiveDistM, mTargetDistM);

        mSnapshot.debugMode = mDebugMode;
        mSnapshot.confidence = confidence;
        mSnapshot.isPaceLocked = mPaceFilter.isLocked();
        mSnapshot.isProjectionLocked = mPredictionBuffer.isProjectionLocked();
        mSnapshot.rejectionRatePct = mTelemetry.getRejectionRatePct();
        mSnapshot.paceVarianceSec = varianceSec;

        // v2.2 display config
        mSnapshot.isImperial = !mIsMetric;
        mSnapshot.distanceUnitStr = mIsMetric ? "km" : "mi";
        mSnapshot.engineName = (activeMode == MODE_TRACK) ? "TRACK" : ((activeMode == MODE_TREADMILL) ? "TREADMILL" : "OUTDOOR");
        mSnapshot.gpsQuality = (gpsAccuracy != null) ? gpsAccuracy : 0;
        mSnapshot.themeMode = mTheme;
        mSnapshot.accentIndex = mAccent;
        mSnapshot.layoutMode = mLayoutMode;
        mSnapshot.alertsEnabled = mAlerts;

        return mSnapshot;
    }

    public function getSnapshot() as RPDisplaySnapshot {
        return mSnapshot;
    }
}
