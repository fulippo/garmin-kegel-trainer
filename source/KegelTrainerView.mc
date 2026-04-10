// Kegel Trainer View
// Handles display and exercise timer logic

using Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Timer;
using Toybox.System as Sys;
using Toybox.Attention;
using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.ActivityRecording;
using Toybox.Activity;

//! Exercise states
enum {
    STATE_READY,      // Waiting to start
    STATE_COUNTDOWN,  // Initial 3-second countdown
    STATE_HOLD,       // Hold/contract phase
    STATE_PULSE,      // Pulse (metronome vibration) phase
    STATE_REST,       // Rest phase
    STATE_COMPLETE    // Workout finished
}

//! Step type constants (stored in _stepTypes array)
const STEP_HOLD  = 0;
const STEP_PULSE = 1;
const STEP_REST  = 2;

//! Main view class for the Kegel Trainer
class KegelTrainerView extends Ui.View {

    // Initial countdown duration
    private const COUNTDOWN_TIME = 3;

    // Settings (loaded from Properties)
    private var _repsPerSeries as Lang.Number = 10;
    private var _numSeries as Lang.Number = 1;
    private var _activityName as Lang.String = "Kegel";
    private var _activityType as Lang.Number = 0;
    private var _disableRecording as Lang.Boolean = false;

    // Step sequence
    private var _stepTypes     as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    private var _stepDurations as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    private var _stepCount     as Lang.Number = 0;
    private var _stepIndex     as Lang.Number = 0;
    private var _pulseIntervalMs as Lang.Number = 500;

    // State variables
    private var _state as Lang.Number;
    private var _currentRep as Lang.Number;
    private var _currentSeries as Lang.Number;
    private var _timeRemaining as Lang.Number;
    private var _timer as Timer.Timer?;
    private var _pulseTimer as Timer.Timer?;
    private var _session as ActivityRecording.Session?;

    //! Constructor
    function initialize() {
        View.initialize();
        loadSettings();
        _state = STATE_READY;
        _currentRep = 1;
        _currentSeries = 1;
        _stepIndex = 0;
        _timeRemaining = COUNTDOWN_TIME;
        _timer = null;
        _pulseTimer = null;
        _session = null;
    }

    //! Load settings from Properties
    private function loadSettings() {
        _repsPerSeries = Properties.getValue("repsPerSeries") as Lang.Number;
        _numSeries = Properties.getValue("numSeries") as Lang.Number;
        _activityName = Properties.getValue("activityName") as Lang.String;
        _activityType = Properties.getValue("activityType") as Lang.Number;
        _disableRecording = Properties.getValue("disableRecording") as Lang.Boolean;

        // Compute pulse interval from speed setting (0=Slow, 1=Medium, 2=Fast)
        var pulseSpeed = Properties.getValue("pulseSpeed") as Lang.Number;
        if (pulseSpeed == 0) {
            _pulseIntervalMs = 1000;  // Slow: 1/sec
        } else if (pulseSpeed == 2) {
            _pulseIntervalMs = 333;   // Fast: 3/sec
        } else {
            _pulseIntervalMs = 500;   // Medium: 2/sec (default)
        }

        // Build step sequence
        _stepTypes     = [] as Lang.Array<Lang.Number>;
        _stepDurations = [] as Lang.Array<Lang.Number>;

        // Step 1 is always present; type 0=Hold, 1=Pulse, 2=Rest maps to STEP_HOLD/PULSE/REST
        var s1Type = Properties.getValue("step1Type") as Lang.Number;
        var s1Dur  = Properties.getValue("step1Duration") as Lang.Number;
        _stepTypes.add(s1Type);
        _stepDurations.add(s1Dur);

        // Step 2: 0=Off (skip), 1=Hold, 2=Pulse, 3=Rest → actual type = rawValue - 1
        var s2Type = Properties.getValue("step2Type") as Lang.Number;
        var s2Dur  = Properties.getValue("step2Duration") as Lang.Number;
        if (s2Type > 0) {
            _stepTypes.add(s2Type - 1);
            _stepDurations.add(s2Dur);
        }

        // Step 3: 0=Off (skip), 1=Hold, 2=Pulse, 3=Rest → actual type = rawValue - 1
        var s3Type = Properties.getValue("step3Type") as Lang.Number;
        var s3Dur  = Properties.getValue("step3Duration") as Lang.Number;
        if (s3Type > 0) {
            _stepTypes.add(s3Type - 1);
            _stepDurations.add(s3Dur);
        }

        _stepCount = _stepTypes.size();
    }

    //! Called when the view is brought to the foreground
    function onShow() {
        loadSettings();
        // Create timer if not exists
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
    }

    //! Called when the view is removed from the screen
    function onHide() {
        stopTimer();
        stopPulseTimer();
        // Only discard if not in complete state (user hasn't chosen yet)
        if (_state != STATE_COMPLETE) {
            discardSession();
        }
    }

    //! Start the exercise routine
    function startExercise() {
        if (_state == STATE_READY || _state == STATE_COMPLETE) {
            loadSettings();
            _state = STATE_COUNTDOWN;
            _currentRep = 1;
            _currentSeries = 1;
            _stepIndex = 0;
            _timeRemaining = COUNTDOWN_TIME;
            startSession();
            startTimer();
            Ui.requestUpdate();
        }
    }

    //! Start activity recording session (keeps display active)
    private function startSession() {
        if (_disableRecording) {
            if (Attention has :backlight) {
                Attention.backlight(true);
            }
            return;
        }

        if (Toybox has :ActivityRecording) {
            if (_session == null || !_session.isRecording()) {
                var sport = Activity.SPORT_TRAINING;
                var subSport = Activity.SUB_SPORT_BREATHING;

                switch (_activityType) {
                    case 1:
                        subSport = Activity.SUB_SPORT_YOGA;
                        break;
                    case 2:
                        subSport = Activity.SUB_SPORT_CARDIO_TRAINING;
                        break;
                    case 3:
                        subSport = Activity.SUB_SPORT_FLEXIBILITY_TRAINING;
                        break;
                    case 4:
                        sport = Activity.SPORT_GENERIC;
                        subSport = Activity.SUB_SPORT_GENERIC;
                        break;
                }

                _session = ActivityRecording.createSession({
                    :name => _activityName,
                    :sport => sport,
                    :subSport => subSport
                });
                _session.start();
            }
        }
    }

    //! Stop and save activity session
    function saveSession() {
        if (_session != null && _session.isRecording()) {
            _session.stop();
            _session.save();
            _session = null;
        }
    }

    //! Stop and discard activity session
    function discardSession() {
        if (_session != null && _session.isRecording()) {
            _session.stop();
            _session.discard();
            _session = null;
        }
    }

    //! Show save confirmation dialog
    private function showSaveConfirmation() {
        var message = WatchUi.loadResource(Rez.Strings.SaveWorkout);
        var dialog = new Ui.Confirmation(message);
        Ui.pushView(dialog, new SaveConfirmationDelegate(self), Ui.SLIDE_UP);
    }

    //! Start the main 1-second interval timer
    private function startTimer() {
        if (_timer != null) {
            _timer.start(method(:onTimerTick), 1000, true);
        }
    }

    //! Stop the main interval timer
    private function stopTimer() {
        if (_timer != null) {
            _timer.stop();
        }
    }

    //! Start the pulse vibration timer
    private function startPulseTimer() as Void {
        stopPulseTimer();
        _pulseTimer = new Timer.Timer();
        _pulseTimer.start(method(:onPulseTick), _pulseIntervalMs, true);
    }

    //! Stop the pulse vibration timer
    private function stopPulseTimer() as Void {
        if (_pulseTimer != null) {
            _pulseTimer.stop();
            _pulseTimer = null;
        }
    }

    //! Pulse timer callback — fires at configurable interval during PULSE state
    //! Must be non-private to be referenced via method(:onPulseTick)
    function onPulseTick() as Void {
        doVibratePulse();
    }

    //! Execute the step at the given index, updating state and starting timers
    private function executeStep(index as Lang.Number) as Void {
        var t = _stepTypes[index] as Lang.Number;
        _timeRemaining = _stepDurations[index] as Lang.Number;
        if (t == STEP_HOLD) {
            _state = STATE_HOLD;
            stopPulseTimer();
            doVibrate();
        } else if (t == STEP_PULSE) {
            _state = STATE_PULSE;
            startPulseTimer();
            doVibrate();
        } else {
            _state = STATE_REST;
            stopPulseTimer();
            doVibrateRelax();
        }
    }

    //! Main timer callback — called every second
    //! Must be non-private to be referenced via method(:onTimerTick)
    function onTimerTick() as Void {
        if (_state == STATE_COUNTDOWN ||
            _state == STATE_HOLD      ||
            _state == STATE_PULSE     ||
            _state == STATE_REST) {

            _timeRemaining--;

            // Keep display on when recording is disabled
            if (_disableRecording && (Attention has :backlight)) {
                Attention.backlight(true);
            }

            if (_timeRemaining <= 0) {
                transitionState();
            }

            Ui.requestUpdate();
        }
    }

    //! Handle state transitions
    private function transitionState() {
        if (_state == STATE_COUNTDOWN) {
            // Countdown finished — start first step of first rep
            _stepIndex = 0;
            executeStep(0);
        } else {
            // Current step finished — advance to next step in the sequence
            _stepIndex++;
            if (_stepIndex >= _stepCount) {
                // End of this rep's step sequence
                _stepIndex = 0;
                if (_currentRep >= _repsPerSeries) {
                    // Last rep of this series
                    _currentRep = 1;
                    if (_currentSeries >= _numSeries) {
                        // All series complete!
                        stopPulseTimer();
                        _state = STATE_COMPLETE;
                        stopTimer();
                        doVibrateComplete();
                        if (!_disableRecording) {
                            showSaveConfirmation();
                        }
                    } else {
                        _currentSeries++;
                        executeStep(0);
                    }
                } else {
                    _currentRep++;
                    executeStep(0);
                }
            } else {
                executeStep(_stepIndex);
            }
        }
    }

    //! Trigger a single short vibration for Hold/Contract start
    private function doVibrate() {
        if (Attention has :vibrate) {
            var vibeData = [new Attention.VibeProfile(50, 200)];
            Attention.vibrate(vibeData);
        }
    }

    //! Trigger a short pulse vibration (used by pulse timer)
    private function doVibratePulse() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(75, 80)]);
        }
    }

    //! Trigger two short vibrations for Rest start
    private function doVibrateRelax() {
        if (Attention has :vibrate) {
            var vibeData = [
                new Attention.VibeProfile(50, 200),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(50, 200)
            ];
            Attention.vibrate(vibeData);
        }
    }

    //! Trigger a longer vibration pattern on completion
    private function doVibrateComplete() {
        if (Attention has :vibrate) {
            var vibeData = [
                new Attention.VibeProfile(100, 200),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 200),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 200)
            ];
            Attention.vibrate(vibeData);
        }
    }

    //! Reset the exercise to initial state
    function resetExercise() {
        stopTimer();
        stopPulseTimer();
        discardSession();
        _state = STATE_READY;
        _currentRep = 1;
        _currentSeries = 1;
        _stepIndex = 0;
        _timeRemaining = COUNTDOWN_TIME;
        Ui.requestUpdate();
    }

    //! Update the display
    //! @param dc The device context for drawing
    function onUpdate(dc as Gfx.Dc) as Void {
        // Clear the screen
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var centerY = height / 2;

        switch (_state) {
            case STATE_READY:
                drawReadyScreen(dc, centerX, centerY);
                break;
            case STATE_COUNTDOWN:
                drawCountdownScreen(dc, centerX, centerY);
                break;
            case STATE_HOLD:
                drawExerciseScreen(dc, centerX, centerY, STATE_HOLD);
                break;
            case STATE_PULSE:
                drawExerciseScreen(dc, centerX, centerY, STATE_PULSE);
                break;
            case STATE_REST:
                drawExerciseScreen(dc, centerX, centerY, STATE_REST);
                break;
            case STATE_COMPLETE:
                drawCompleteScreen(dc, centerX, centerY);
                break;
        }
    }

    //! Draw the ready/start screen
    private function drawReadyScreen(dc as Gfx.Dc, centerX as Lang.Number, centerY as Lang.Number) {
        var screenHeight = dc.getHeight();

        var hMedium = dc.getFontHeight(Gfx.FONT_MEDIUM);
        var hSmall  = dc.getFontHeight(Gfx.FONT_SMALL);

        // --- TITLE ---
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var title1Y = (screenHeight * 0.15).toNumber();
        dc.drawText(centerX, title1Y, Gfx.FONT_MEDIUM, WatchUi.loadResource(Rez.Strings.AppTitle1), Gfx.TEXT_JUSTIFY_CENTER);

        var title2Y = title1Y + (hMedium * 0.8).toNumber();
        dc.drawText(centerX, title2Y, Gfx.FONT_MEDIUM, WatchUi.loadResource(Rez.Strings.AppTitle2), Gfx.TEXT_JUSTIFY_CENTER);

        // --- WORKOUT INFO ---
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);

        var repsY = (screenHeight * 0.45).toNumber();
        var repsText = _repsPerSeries + " reps x " + _numSeries + " series";
        dc.drawText(centerX, repsY, Gfx.FONT_SMALL, repsText, Gfx.TEXT_JUSTIFY_CENTER);

        // Step sequence summary line (e.g. "HOLD 10s > REST 5s")
        var stepLabels = ["HOLD", "PULSE", "REST"];
        var summary = "";
        for (var i = 0; i < _stepCount; i++) {
            if (i > 0) {
                summary = summary + " > ";
            }
            var sType = _stepTypes[i] as Lang.Number;
            var sDur  = _stepDurations[i] as Lang.Number;
            summary = summary + stepLabels[sType] + " " + sDur + "s";
        }
        var detailsY = repsY + hSmall;
        dc.drawText(centerX, detailsY, Gfx.FONT_TINY, summary, Gfx.TEXT_JUSTIFY_CENTER);

        // --- START PROMPT ---
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        var promptY = (screenHeight * 0.75).toNumber();
        dc.drawText(centerX, promptY, Gfx.FONT_SMALL, WatchUi.loadResource(Rez.Strings.PressStart), Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Draw the initial countdown screen
    private function drawCountdownScreen(dc as Gfx.Dc, centerX as Lang.Number, centerY as Lang.Number) {
        var hNumber = dc.getFontHeight(Gfx.FONT_NUMBER_HOT);
        var hSmall = dc.getFontHeight(Gfx.FONT_SMALL);

        // --- GET READY text ---
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        var readyY = centerY - (hNumber / 2) - (hSmall * 0.9).toNumber();
        dc.drawText(centerX, readyY, Gfx.FONT_SMALL, WatchUi.loadResource(Rez.Strings.GetReady), Gfx.TEXT_JUSTIFY_CENTER);

        // --- Countdown number ---
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        var timerY = centerY - (hNumber / 2);
        dc.drawText(centerX, timerY, Gfx.FONT_NUMBER_HOT, _timeRemaining.toString(), Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Draw the exercise screen during Hold / Pulse / Rest phases
    //! @param state  One of STATE_HOLD, STATE_PULSE, STATE_REST
    private function drawExerciseScreen(dc as Gfx.Dc, centerX as Lang.Number, centerY as Lang.Number, state as Lang.Number) {
        var width = dc.getWidth();

        // Arc parameters
        var penWidth = (width * 0.05).toNumber();
        if (penWidth < 4) { penWidth = 4; }
        var arcRadius = (width / 2) - (penWidth / 2) - 2;

        // Font metrics
        var hNumber = dc.getFontHeight(Gfx.FONT_NUMBER_HOT);
        var hSmall  = dc.getFontHeight(Gfx.FONT_SMALL);

        // Colour and label based on current step type
        var arcColor;
        var stateText;
        if (state == STATE_HOLD) {
            arcColor  = Gfx.COLOR_RED;
            stateText = WatchUi.loadResource(Rez.Strings.Hold);
        } else if (state == STATE_PULSE) {
            arcColor  = Gfx.COLOR_ORANGE;
            stateText = WatchUi.loadResource(Rez.Strings.Pulse);
        } else {
            arcColor  = Gfx.COLOR_GREEN;
            stateText = WatchUi.loadResource(Rez.Strings.Rest);
        }

        // --- DRAW ARC ---
        dc.setPenWidth(penWidth);

        // Background arc
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, arcRadius, Gfx.ARC_CLOCKWISE, 90, -270);

        // Progress arc
        var totalTime = _stepDurations[_stepIndex] as Lang.Number;
        var progress = (totalTime - _timeRemaining).toFloat() / totalTime.toFloat();
        var endAngle = 90 - (progress * 360).toNumber();

        dc.setColor(arcColor, Gfx.COLOR_TRANSPARENT);
        if (progress > 0) {
            dc.drawArc(centerX, centerY, arcRadius, Gfx.ARC_CLOCKWISE, 90, endAngle);
        }

        // --- DRAW TEXT ---

        // Timer
        var timerY = centerY - (hNumber / 2);
        dc.setColor(arcColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(centerX, timerY, Gfx.FONT_NUMBER_HOT, _timeRemaining.toString(), Gfx.TEXT_JUSTIFY_CENTER);

        // State label
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var stateY = timerY - (hSmall * 0.9).toNumber();
        dc.drawText(centerX, stateY, Gfx.FONT_SMALL, stateText, Gfx.TEXT_JUSTIFY_CENTER);

        // Rep and series counter
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        var repText;
        if (_numSeries > 1) {
            repText = WatchUi.loadResource(Rez.Strings.Rep) + " " + _currentRep + "/" + _repsPerSeries + " - " + WatchUi.loadResource(Rez.Strings.Series) + " " + _currentSeries + "/" + _numSeries;
        } else {
            repText = WatchUi.loadResource(Rez.Strings.Rep) + " " + _currentRep + " " + WatchUi.loadResource(Rez.Strings.Of) + " " + _repsPerSeries;
        }
        var repY = timerY + hNumber;
        dc.drawText(centerX, repY, Gfx.FONT_SMALL, repText, Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Draw the completion screen
    private function drawCompleteScreen(dc as Gfx.Dc, centerX as Lang.Number, centerY as Lang.Number) {
        var height = dc.getHeight();
        var hMedium = dc.getFontHeight(Gfx.FONT_MEDIUM);

        // --- SUCCESS TITLE ---
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        var yComplete = (height * 0.25).toNumber();
        dc.drawText(centerX, yComplete, Gfx.FONT_LARGE, WatchUi.loadResource(Rez.Strings.Complete), Gfx.TEXT_JUSTIFY_CENTER);

        // --- CENTRAL MESSAGE ---
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        var yGreatJob = centerY - (hMedium / 2);
        dc.drawText(centerX, yGreatJob, Gfx.FONT_MEDIUM, WatchUi.loadResource(Rez.Strings.GreatJob), Gfx.TEXT_JUSTIFY_CENTER);

        // --- INSTRUCTIONS ---
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        var yInstructions = (height * 0.75).toNumber();
        dc.drawText(centerX, yInstructions, Gfx.FONT_TINY, WatchUi.loadResource(Rez.Strings.Instructions), Gfx.TEXT_JUSTIFY_CENTER);
    }

    //! Check if exercise is in progress
    function isExerciseActive() as Lang.Boolean {
        return (_state == STATE_COUNTDOWN ||
                _state == STATE_HOLD      ||
                _state == STATE_PULSE     ||
                _state == STATE_REST);
    }

    //! Get current state
    function getState() as Lang.Number {
        return _state;
    }
}
