// Kegel Trainer Input Delegate
// Handles button presses and user input

using Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;

//! Confirmation delegate for save workout dialog
class SaveConfirmationDelegate extends Ui.ConfirmationDelegate {

    private var _view as KegelTrainerView;

    //! Constructor
    //! @param view Reference to the main view
    function initialize(view as KegelTrainerView) {
        ConfirmationDelegate.initialize();
        _view = view;
    }

    //! Handle the user's response to the confirmation dialog
    //! @param response The user's response (CONFIRM_YES or CONFIRM_NO)
    //! @return true
    function onResponse(response) as Lang.Boolean {
        if (response == Ui.CONFIRM_YES) {
            _view.saveSession();
        } else {
            _view.discardSession();
        }
        return true;
    }
}

//! Input delegate for handling user interactions
class KegelTrainerDelegate extends Ui.BehaviorDelegate {

    private var _view as KegelTrainerView;

    //! Constructor
    //! @param view Reference to the main view
    function initialize(view as KegelTrainerView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    //! Handle the select/enter button press (START button on most devices)
    //! @return true if the event was handled
    function onSelect() as Lang.Boolean {
        _view.startExercise();
        return true;
    }

    //! Handle the back button press
    //! @return true if the event was handled, false to allow default behavior
    function onBack() as Lang.Boolean {
        if (_view.isExerciseActive()) {
            // If exercise is in progress, reset instead of exiting
            _view.resetExercise();
            return true;
        }
        // Allow default back behavior (exit app) when not active
        return false;
    }

    //! Handle key events
    //! @param evt The key event
    //! @return true if the event was handled
    function onKey(evt as Ui.KeyEvent) as Lang.Boolean {
        var key = evt.getKey();
        
        if (key == Ui.KEY_ENTER || key == Ui.KEY_START) {
            _view.startExercise();
            return true;
        }
        
        return false;
    }

    //! Handle touch tap events (for touchscreen devices)
    //! @param evt The click event
    //! @return true if the event was handled
    function onTap(evt as Ui.ClickEvent) as Lang.Boolean {
        // Tap anywhere to start when in ready state
        if (_view.getState() == STATE_READY || _view.getState() == STATE_COMPLETE) {
            _view.startExercise();
            return true;
        }
        return false;
    }
}
