import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;


class RaVelWatchFaceDelegate extends WatchUi.WatchFaceDelegate {

	function initialize()
	{
		WatchFaceDelegate.initialize();
	}

	function onPress(clickEvent as WatchUi.ClickEvent) as Lang.Boolean 
	{
		var coords = clickEvent.getCoordinates();
		return Application.getApp().View.onPress( coords[0], coords[1]);
	 }
}


