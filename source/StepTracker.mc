using Toybox.Time;
import Toybox.Lang;


class StepTracker
{
	var _snapValue as Number;
	var _snapTime as Number;

	var PeriodSteps as Number = 0;
	var AvgPeriodSteps as Number or Float = -1;

	function initialize() {
			self._snapValue = 0;
			self._snapTime = 0;
	}

	public function poll(now as Number) as Boolean {
		var snap = ActivityMonitor.getInfo().steps;

		if (snap < self._snapValue || now - self._snapTime > 70) {
			self._snapValue = snap;
			self._snapTime = now;
			self.AvgPeriodSteps = -1;
			return false;
		}

		var periodSteps = snap - self._snapValue;

		if (self.AvgPeriodSteps < 0) {
			self.AvgPeriodSteps = periodSteps;
		}
		else {
			self.AvgPeriodSteps = 0.63 * self.AvgPeriodSteps + 0.37 * self.PeriodSteps;
		}
		self.PeriodSteps = periodSteps;

		self._snapValue = snap;
		self._snapTime = now;

		//TRACE("poll " + now.toString() + " current " + self.PeriodSteps.toString() + " avg " + self.AvgPeriodSteps.toString() );

		return true;
	}

}