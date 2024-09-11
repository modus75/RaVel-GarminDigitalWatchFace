using Toybox.Time;
import Toybox.Lang;

class NullSleepTimeTracker {

	function onShow() as Void {}

	function onHide() as Void {}

	function onExitSleep() as Void { }

	function onEnterSleep() as Void {}

	function onBackgroundSleepTime() as Void {}

	function onBackgroundWakeTime() as Void {}

	function onUpdate(now as Number) as Boolean{
		return true;
	}

	public function unfreezeMorningAOD() as Void {}
	public function unfreezeEveningAOD() as Void {}

	public function onSettingsChanged() as Void {}
}


class SleepTimeTracker {

	private const WAKE_UP_TIMES = "WakeUpTimes";
	private const SLEEP_TIMES = "SleepTimes";

	private var _loPower as Boolean = false;

	private var _wakeUpTimes as Array<Number?>;
	private var _nextWakeUpTime as Number = 0;
	private var _sleepTimes as Array<Number?>;
	private var _nextSleepTime as Number = 0;

	private var _aodOffBeforeSleep as Number = 0;

	private var _freezeMorningAOD;
	private var _freezeMorningAODSteps;
	private var _freezeMorningAODShowEventCount;

	private var _screenOffTimeout as Number;
	private var _nexScreenOffTime as Number;


	function initialize() {
		self._freezeMorningAOD = false;
		self._freezeMorningAODSteps = 0;
		self._freezeMorningAODShowEventCount = 0;

		var now = Time.now().value();
		self._screenOffTimeout = 86400;
		self._nexScreenOffTime = now + 86400;

		self._wakeUpTimes = Application.Storage.getValue(WAKE_UP_TIMES);
		if (self._wakeUpTimes == null) {
			self._wakeUpTimes = new Array<Number?>[7];
		}

		self._sleepTimes = Application.Storage.getValue(SLEEP_TIMES);
		if (self._sleepTimes == null) {
			self._sleepTimes = new Array<Number?>[7];
		}

		self.computeNextWakeUpTime( new Time.Moment(now) );
		self.computeNextSleepTime( new Time.Moment(now) );
	}

	function onShow() as Void {
		self._freezeMorningAODShowEventCount++;
		self.checkUnfreezeMorningAOD();
	}

	function onHide() as Void {
		self.delayScreenOffTime( Time.now().value() + 60 );
	}

	function onExitSleep() as Void {
		self._loPower = false;
	}

	function onEnterSleep() as Void {
		self._loPower = true;
		self._nexScreenOffTime = Time.now().value() + self._screenOffTimeout;
	}

	function onBackgroundSleepTime() as Void {
		var now = Time.now();
		if ( self.updateSleepEventSchedule(self._sleepTimes, now) ) {
			Application.Storage.setValue( SLEEP_TIMES, self._sleepTimes);
		}

		self.computeNextWakeUpTime( now );
		self.computeNextSleepTime( now.add(new Time.Duration(60)) );
	}

	function onBackgroundWakeTime() as Void {
		var now = Time.now();
		if ( self.updateSleepEventSchedule(self._wakeUpTimes, now) ) {
			Application.Storage.setValue( WAKE_UP_TIMES, self._wakeUpTimes);
		}

		self.computeNextWakeUpTime( now.add(new Time.Duration(60)) );
		self.computeNextSleepTime( now );

		self._freezeMorningAOD = true;
		self._freezeMorningAODSteps = ActivityMonitor.getInfo().steps;
		self._freezeMorningAODShowEventCount = 0;
	}


	public function onUpdate(now as Number) as Boolean
	{
		if ( now >= self._nextWakeUpTime && now <= self._nextWakeUpTime + 5 ) {
			return false;
		}

		if ( self._loPower ) {

			if (self._freezeMorningAOD && !self.checkUnfreezeMorningAOD()) {
				return false;
			}

			if ( now < self._nextSleepTime && now + self._aodOffBeforeSleep > self._nextSleepTime ) {
				return false;
			}

			if ( now % 60 >= 2) {
				// as of 2023-01
				//  -  in wrist gesture on draw is called on small movements even if the full high power mode is not triggered
				//  - when a message is received there is a bug and draw is called every second until a hi power mode is triggered
				self.delayScreenOffTime( now + 1 );
			}

			if ( now >= self._nexScreenOffTime ) {
				return false;
			}
		}

		return true;
	}

	private function updateSleepEventSchedule(schedule as Array<Number>, now as Time.Moment) as Boolean
	{
		var nowInfo = Time.Gregorian.info( now, Time.FORMAT_SHORT );
		var eventTIme = nowInfo.hour * 60 + nowInfo.min;
		if ( !eventTIme.equals( schedule[ nowInfo.day_of_week - 1] )) {
			if (schedule[ nowInfo.day_of_week - 1] == null) {
				if (nowInfo.day_of_week==1 || nowInfo.day_of_week==6) {
					schedule[0] = eventTIme;
					schedule[6] = eventTIme;
				} else {
					for (var i=1; i<=5; i++) {
						schedule[i] = eventTIme;
					}
				}
			}
			else {
				schedule[ nowInfo.day_of_week - 1] = eventTIme;
			}
			return true;
		}
		return false;
	}


	private function computeNextWakeUpTime(now as Time.Moment) as Void
	{
		var time = computeNextSleepEventTime( self._wakeUpTimes, now);
		if (time != null)
		{
			self._nextWakeUpTime = time;
		}
	}

	private function computeNextSleepTime(now as Time.Moment) as Void
	{
		var time = computeNextSleepEventTime( self._sleepTimes, now);
		if (time != null)
		{
			self._nextSleepTime = time;
		}
	}

	private function computeNextSleepEventTime(schedule as Array<Number>, now as Time.Moment) as Number?
	{
		var day = Time.today().value();
		var info = Time.Gregorian.info(now, Time.FORMAT_SHORT);
		var wakeUpTime = schedule[ info.day_of_week - 1];
		if (wakeUpTime != null && wakeUpTime < info.hour * 60 + info.min) {
			wakeUpTime = schedule[ info.day_of_week % 7 ];
			day += Time.Gregorian.SECONDS_PER_DAY;
		}

		if (wakeUpTime != null) {
			return day + wakeUpTime * 60;
		}
		return 0/*null*/;
	}


	private function processFlagsChanged(mask as Number, prevFlags as Number) {
		if (self._freezeMorningAOD) {
			checkUnfreezeMorningAOD();
		}
	}

	public function unfreezeMorningAOD() as Void
	{
		self._freezeMorningAOD = false;
	}

	public function unfreezeEveningAOD() as Void
	{
		var now = Time.now().value();
		if ( now + self._aodOffBeforeSleep > self._nextSleepTime && now < self._nextSleepTime ) {
			self._nextSleepTime = self._nextSleepTime + self._aodOffBeforeSleep;
		}
	}

	private function checkUnfreezeMorningAOD() as Boolean {
		if (self._freezeMorningAODShowEventCount > 3 ) {
			self._freezeMorningAOD = false;
			return true;
		}

		var steps = ActivityMonitor.getInfo().steps;
		if (steps < self._freezeMorningAODSteps ||
			steps > self._freezeMorningAODSteps + 10) {
			self._freezeMorningAOD = false;
			return true;
		}
		return false;
	}

	private function delayScreenOffTime(until) {
		if (until > self._nexScreenOffTime) {
			self._nexScreenOffTime = until;
		}
	}

	public function onSettingsChanged() {
		self._aodOffBeforeSleep =  Application.Properties.getValue("AODOffBeforeSleep");

		var aodPowerSaverLevel = Application.Properties.getValue("AODPowerSaver");

		if (aodPowerSaverLevel == 0) {
			self._screenOffTimeout = 86400;
		}
		else if (aodPowerSaverLevel == 1){
			self._screenOffTimeout = 3600;
		}
		else if (aodPowerSaverLevel == 2){
			self._screenOffTimeout = 270;
		}
		else if (aodPowerSaverLevel == 3){
			self._screenOffTimeout = 90;
		}
		else if (aodPowerSaverLevel == 4){
			self._screenOffTimeout = 30;
		}

		self._nexScreenOffTime = Time.now().value() + self._screenOffTimeout;
	}

}