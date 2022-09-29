import Toybox.Application;
import Toybox.Time;

class LightDimmer
{
	protected var _dimmerActive = false;

	function check( time ) as Boolean {
		return false;
	}

	function onSettingsChanged() {
	}
}


class TimeBasedDimmer extends LightDimmer
{
	private var _startTimes = new [7];
	private var _endTimes = new [7];

	private var _currentDayOfWeekIndex = 0;
	private var _currentDayOfWeekCheckHour = -1;

	function initialize() {
		LightDimmer.initialize();
	}

	function check( now ) as Boolean {
		if (now.hour != self._currentDayOfWeekCheckHour) {
			self.updateCurrentDayOfWeek();
		}

		var active = false;

		var nowhm = now.hour * 100 + now.min;
		if (nowhm >= self._startTimes[self._currentDayOfWeekIndex]
			|| nowhm < self._endTimes[self._currentDayOfWeekIndex] ) {
			active = true;
		}

		if (self._dimmerActive != active) {
			self._dimmerActive = active;
			TRACE("Dimmer set to " + active.toString() );
			$.gTheme.setLightFactor(self._dimmerActive ? 0.75 : 1.0);
			return true;
		}
		return false;
	}

	function onSettingsChanged() {
		var valStart = Application.getApp().getProperty("LightDimmerStartTime").toNumber();
		var valEnd = Application.getApp().getProperty("LightDimmerEndTime").toNumber();

		var valEndWE = Application.getApp().getProperty("LightDimmerWEEndTime").toNumber();

		if (valStart == null) {
			valStart = 2400;
		}
		if (valEnd == null) {
			valEnd = 0;
		}
		if (valEndWE == null) {
			valEndWE = 0;
		}

		for (var i=0; i<7; i++) {
			self._startTimes[i] = valStart;
			self._endTimes[i] = valEnd;
		}

		self._endTimes[0] = valEndWE;
		self._endTimes[6] = valEndWE;

		updateCurrentDayOfWeek();
	}

	private function updateCurrentDayOfWeek() {
		var now = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
		self._currentDayOfWeekIndex = now.day_of_week - 1; // Sunday first
		self._currentDayOfWeekCheckHour = now.hour;
	}

}