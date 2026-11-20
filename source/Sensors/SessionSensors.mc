import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;

//! Heart rate and beat-to-beat intervals recorded during one session.
//! Only runs when the user turned "HR & HRV" on; every failure (no sensor,
//! no permission, listener already taken) simply leaves the values null.
class SessionSensors {

    const HRV_WINDOW_MS = 120000;   // RMSSD over the first and last 2 minutes
    const MAX_BEATS = 1500;         // ~20 min at 75 bpm; oldest dropped beyond
    const MIN_SESSION_FOR_DELTA_MS = 300000;  // start/end windows need >= 5 min

    hidden var _active as Boolean = false;
    hidden var _rr as Array = [];
    hidden var _rrHead as Array = [];  // first window, kept even if _rr overflows
    hidden var _headMs as Number = 0;
    hidden var _hrSum as Number = 0;
    hidden var _hrCount as Number = 0;
    hidden var _hrMin = null;
    hidden var _lastSampleMs = null;

    function initialize() {
    }

    function start() as Void {
        if (!SettingsRepository.hrSnapshot()) {
            return;
        }
        _active = true;
        try {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        } catch (e) {
        }
        if (SensorAvailability.hasBeatIntervals()) {
            try {
                Sensor.registerSensorDataListener(method(:onData), {
                    :period => 1,
                    :heartBeatIntervals => {:enabled => true}
                });
            } catch (e) {
            }
        }
    }

    function stop() as Void {
        if (!_active) {
            return;
        }
        _active = false;
        try {
            Sensor.unregisterSensorDataListener();
        } catch (e) {
        }
    }

    //! Beat intervals arrive about once a second.
    function onData(data as Sensor.SensorData) as Void {
        if (!_active || data == null || data.heartRateData == null) {
            return;
        }
        var beats = data.heartRateData.heartBeatIntervals;
        if (beats == null) {
            return;
        }
        for (var i = 0; i < beats.size(); i++) {
            var v = beats[i];
            if (v == null || v <= 0) {
                continue;
            }
            _rr.add(v);
            if (_headMs < HRV_WINDOW_MS) {
                _rrHead.add(v);
                _headMs += v;
            }
        }
        if (_rr.size() > MAX_BEATS) {
            _rr = _rr.slice(_rr.size() - MAX_BEATS, _rr.size());
        }
    }

    //! Called once per engine tick (about 1 s) while the session runs.
    function sampleHr() as Void {
        if (!_active) {
            return;
        }
        var now = System.getTimer();
        if (_lastSampleMs != null && now - _lastSampleMs < 1000) {
            return;   // frames run at 125 ms while animating; sample once a second
        }
        _lastSampleMs = now;
        var hr = HeartRateProvider.current();
        if (hr == null) {
            return;
        }
        _hrSum += hr;
        _hrCount++;
        if (_hrMin == null || hr < _hrMin) {
            _hrMin = hr;
        }
    }

    //! Adds the optional sensor fields to a session record. Nothing is added
    //! for data that was not measured.
    function addTo(record as Dictionary, activeMs as Number) as Void {
        if (_hrCount > 0) {
            record.put(Models.K_HR_AVG, MetricValidator.roundedMean(_hrSum, _hrCount));
            record.put(Models.K_HR_MIN, _hrMin);
        }
        if (activeMs >= MIN_SESSION_FOR_DELTA_MS) {
            var s = HrvCalculator.rmssd(_rrHead);
            var e = HrvCalculator.rmssd(HrvCalculator.tail(_rr, HRV_WINDOW_MS));
            if (s != null) {
                record.put(Models.K_HRV_START, s);
            }
            if (e != null) {
                record.put(Models.K_HRV_END, e);
            }
        } else {
            // short session: one value over everything, stored as the end value
            var all = HrvCalculator.rmssd(_rr);
            if (all != null) {
                record.put(Models.K_HRV_END, all);
            }
        }
    }
}
