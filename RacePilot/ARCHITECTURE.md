# RacePilot Architecture

## Overview
RacePilot is a premium race-pacing data field for Garmin Connect IQ, targeting FR165 (390x390 round AMOLED). It provides 4 real-time metrics: Lap Pace, Distance/Time, Projected Finish, and Need Pace.

## File Structure
```
sources/
  PaceEngine.mc        - Unified orchestrator, routes to sub-engines
  GPSEngine.mc         - Outdoor GPS pace with recovery, corner+, grade
  TrackEngine.mc       - Track Run (400m laps, lap blending, prediction)
  TreadmillEngine.mc   - Treadmill with calibration
  RunStateMachine.mc   - Activity state machine (11 states)
  ConfidenceScore.mc   - 5-factor confidence (0-100%)
  PaceFilter.mc        - Unified EWMA + median + rate limiter + lock
  PredictionBuffer.mc  - Multi-source weighted pace + projection lock
  NeedPaceBuffer.mc    - Buffered need pace (5s refresh)
  Layout.mc            - Responsive layout engine
  RacePilotView.mc     - Main rendering view
  RacePilotApp.mc      - App entry, settings validation
  DebugLogger.mc       - Circular log buffer
  TelemetryLayer.mc    - Algorithm performance tracking
  UnitTestRunner.mc    - Synthetic test scenarios
```

## Data Flow
```
compute(info) [1Hz]
  -> detectActivityType(info) -> GPSEngine | TrackEngine | TreadmillEngine
  -> RunStateMachine.update(info, mode, gps, ...)
  -> ConfidenceScore.compute(info, pace, hasGps)
  -> computeDistanceAndTime(info)
  -> computeProjectedFinish() [frozen if paused/GPS loss]
  -> computeNeedPace(info) [hidden if paused/countdown]
  -> TelemetryLayer.recordPaceUpdate(...)
```

## State Machine
```
NO_TARGET -> IDLE -> GPS_ACQUIRING -> COUNTDOWN -> RACING -> PAUSED -> FINISHING -> FINISHED -> LOCKED
```

- **GPS_ACQUIRING**: Waiting for first GPS lock
- **COUNTDOWN**: 3s countdown after GPS acquired
- **RACING**: Normal operation
- **AUTO_PAUSED/MANUAL_PAUSED**: Freeze projections, hide Need Pace
- **FINISHING**: Last 200m, motivational messages
- **FINISHED/LOCKED**: Display frozen for 5s

## Confidence Engine
5-factor weighted score (0-100%):
- GPS quality (35%)
- Cadence stability (15%)
- Heading variance (15%)
- Distance consistency (15%)
- Pace variance (20%)

## Adaptive Smoothing
- EWMA with alpha adapted by confidence
- Median filter for outlier rejection (20-sample buffer)
- Rate limiter (3 sec/sec max)
- Hysteresis (0.5 sec/km deadband)
- Pace lock (stable pace locks after 5 samples)

## Projection Lock
- Minimum 3 sec change threshold
- 5-second time-based refresh
- Prevents jitter in projected finish

## Multi-Source Prediction
Weighted combination:
- Instant pace (20%)
- Lap pace (30%)
- EWMA pace (30%)
- History average (20%)

## Grade Compensation
- 5-sample altitude buffer for smooth grade estimation
- Grade factor: 1% grade ~ 2.5% pace adjustment
- Clamped to +/-15%

## GPS Recovery
- Gradual blend over 10 seconds after signal loss
- Uses last valid pace as recovery baseline
- Corner protection via heading buffer analysis

## Battery Optimization
- Frame hash comparison (skip unchanged frames)
- Telemetry only when enabled
- Debug logger only when debugMode=true
