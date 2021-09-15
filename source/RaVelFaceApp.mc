import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class RaVelFaceApp extends Application.AppBase {
	var mView;
	
    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as Array<Views or InputDelegates>? {
    	mView = new RaVelFaceView();
        return [ mView ] as Array<Views or InputDelegates>;
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
    	mView.onSettingsChanged();
        WatchUi.requestUpdate();
    }


	// Return a formatted time dictionary that respects is24Hour and HideHoursLeadingZero settings.
	// - hour: 0-23.
	// - min:  0-59.
	function getFormattedTime(hour, min) {
		var amPm = "";

		if (!System.getDeviceSettings().is24Hour) {

			// #6 Ensure noon is shown as PM.
			var isPm = (hour >= 12);
			if (isPm) {
				
				// But ensure noon is shown as 12, not 00.
				if (hour > 12) {
					hour = hour - 12;
				}
				amPm = "p";
			} else {
				
				// #27 Ensure midnight is shown as 12, not 00.
				if (hour == 0) {
					hour = 12;
				}
				amPm = "a";
			}
		}

		// #10 If in 12-hour mode with Hide Hours Leading Zero set, hide leading zero. Otherwise, show leading zero.
		// #69 Setting now applies to both 12- and 24-hour modes.
		hour = hour.format(getProperty("HideHoursLeadingZero") ? "%d" : "%02d");

		return {
			:hour => hour,
			:min => min.format("%02d"),
			:amPm => amPm
		};
	}
}

function getApp() as TestFaceApp {
    return Application.getApp() as TestFaceApp;
}