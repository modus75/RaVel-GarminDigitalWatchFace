import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class RaVelFaceApp extends Application.AppBase {
	var mView;
	
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as Array<Views or InputDelegates>? {
    	mView = new RaVelFaceView();
        return [ mView ] as Array<Views or InputDelegates>;
    }

    function onSettingsChanged() as Void {
    	mView.onSettingsChanged();
        WatchUi.requestUpdate();
    }

}

function getApp() as RaVelFaceApp {
    return Application.getApp() as RaVelFaceApp;
}
