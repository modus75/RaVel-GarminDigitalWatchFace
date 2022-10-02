import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Background;


(:background)
class RaVelFaceApp extends Application.AppBase {
	var mView as RaVelFaceView;
	
	function initialize() {
		AppBase.initialize();
	}

	function onStart(state as Dictionary?) as Void {
		// Background service method. Don't access anything
	}

	function onStop(state as Dictionary?) as Void {
		// Background service method. Don't access anything
	}

	function getInitialView() as Array<Views or InputDelegates>? {
		
		if (System has :ServiceDelegate) {  
			TRACE("App: registering for background events");   
			Background.registerForSleepEvent();
			Background.registerForWakeEvent();
			Background.registerForStepsEvent();
			TRACE("App: getSleepEventRegistered=" + Background.getSleepEventRegistered().toString() );  
		}
		else {
			TRACE("App: no ServiceDelegate");
		}

		mView = new RaVelFaceView();
		return [ mView ] as Array<Views or InputDelegates>;
	}

	function onSettingsChanged() as Void {
		mView.onSettingsChanged();
		WatchUi.requestUpdate();
	}

	function getServiceDelegate(){
		return [new RaVelServiceDelegate()];
	}

	 function onBackgroundData(data) as Void {
		TRACE("App: onBackgroundData " + data.toString() );
		if (data==0) {
			mView.onBackgroundSleepTime();
		}
		else {
			mView.onBackgroundWakeTime();
		}
	 }
}

(:background)
class RaVelServiceDelegate extends System.ServiceDelegate {

	public function initialize() {
		System.ServiceDelegate.initialize();
	}

	public function onSleepTime() as Void {
		Background.exit(0);
	}

	public function onWakeTime() as Void {
		Background.exit(1);
	}

	public function onSteps() as Void {
		Background.exit(2);
	}
}


function getApp() as RaVelFaceApp {
	return Application.getApp() as RaVelFaceApp;
}
