using Toybox.Time;
import Toybox.Lang;

class NullSleepTimeTracker {

	function onShow() as Void {}

	function onHide() as Void {}

	function onExitSleep() as Void { }

	function onEnterSleep() as Void {}

	function onBackgroundSleepTime() as Void {}

	function onBackgroundWakeTime() as Void {}

	function onUpdate() as Boolean{
		return true;
	}

	public function getSleepMode() as Boolean {
		return false;
	}

	public function onSettingsChanged() {}
}


class SleepTimeTracker {

	enum {
		LOPOWER_F   = 0,
		VISIBLE_F   = 1,
		NODISTURB_F = 2,
		BGSLEEP_F   = 3,
		
		NB_FLAGS = 4
	}

	enum {
		LOPOWER_M   = 1 << LOPOWER_F,
		VISIBLE_M   = 1 << VISIBLE_F,
		NODISTURB_M = 1 << NODISTURB_F,
		BGSLEEP_M   = 1 << BGSLEEP_F,
	}

	private var _flags as Number;
	private var _lastChangeTimes = new [NB_FLAGS];

	private var _freezeAlwaysOnDisplay;
	private var _freezeAlwaysOnDisplaySteps;
	private var _freezeAlwaysOnDisplayShowEventCount;

	private var _AODTimeout as Number;
	private var _nextAODOffTime as Number;

	function initialize() {
		self._freezeAlwaysOnDisplay = false;
		self._freezeAlwaysOnDisplaySteps = 0;
		self._freezeAlwaysOnDisplayShowEventCount = 0;

		self._AODTimeout = 0;

		self._flags = 0;
		for (var i=0; i<NB_FLAGS; i++ ) {
			_lastChangeTimes[i] = 0;
		}
	}

	function onShow() as Void {
		self._freezeAlwaysOnDisplayShowEventCount++;
		setMask(VISIBLE_M | NODISTURB_M, VISIBLE_M | (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
	}

	function onHide() as Void {
		setMask(VISIBLE_M | NODISTURB_M, (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
		var newOffTime = self._lastChangeTimes[VISIBLE_F] + 120;
		if (newOffTime > self._nextAODOffTime) {
			self._nextAODOffTime = newOffTime;
		}
	}

	function onExitSleep() as Void {
		setMask(LOPOWER_M | NODISTURB_M, (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
	}

	function onEnterSleep() as Void {
		setMask(LOPOWER_M | NODISTURB_M, LOPOWER_M | (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
		self._nextAODOffTime = 	self._lastChangeTimes[LOPOWER_F] + self._AODTimeout;
	}

	function onBackgroundSleepTime() as Void {
		setMask(BGSLEEP_M | NODISTURB_M, BGSLEEP_M | (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
	}

	function onBackgroundWakeTime() as Void {
		setMask(BGSLEEP_M | NODISTURB_M, (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
	}

	function onUpdate() {

		var doNotDisturb = System.getDeviceSettings().doNotDisturb;
		setMask(NODISTURB_M, (doNotDisturb ? NODISTURB_M : 0) );

		if ( !doNotDisturb && self._flags & (BGSLEEP_M|LOPOWER_M) == BGSLEEP_M|LOPOWER_M ) {
			// doNotDisturb changed to off - maybe first redraws in the morning but just before wake up time is sent in backround ?
			var now = Time.now().value();

			if ( now - self.getLastChangeTime(NODISTURB_M) < 10 ) {
				return false;
			}
		}

		if (self._freezeAlwaysOnDisplay && !self.checkUnfreezeAlwaysOnDisplay()) {
			 if (self._flags & (BGSLEEP_M|NODISTURB_M|LOPOWER_M) == LOPOWER_M) {
				return false;
			 }
		}

		if ( self._flags & (LOPOWER_M) == LOPOWER_M ) {
				var now = Time.now().value();
				if ( now > self._nextAODOffTime ) {
					return false;
			}
		}

		return true;
	}

	public function getSleepMode() as Boolean {
		return (self._flags & (BGSLEEP_M|NODISTURB_M) ) == (BGSLEEP_M|NODISTURB_M);
	}


	private function setMask(mask as Number, maskValue as Number) as Void {

		mask = (self._flags ^ maskValue) & mask; // keep in mask only bits that changed

		if  (mask != 0) {
			maskValue &= mask; 

			var prevFlags = self._flags;

			self._flags = ( self._flags & ~mask) | maskValue;

			var now = Time.now().value();
			for (var i=0; i < NB_FLAGS; i++) {
				if ( (1<<i) & mask) {
					self._lastChangeTimes[i] = now;
				}
			}
			
			processFlagsChanged(mask, prevFlags, now);
		}
	}

	private function getLastChangeTime(mask as Number) {
		var last = 0;
		for (var i=0; i< NB_FLAGS; i++) {
			if (mask & (1<<i) ) {
				if (last < self._lastChangeTimes[i]) {
					last = self._lastChangeTimes[i];
				}
			}
		}
		return last;
	}

	private function processFlagsChanged(mask as Number, prevFlags as Number, now) {

		// if ( (now/3600)%24 <= 8 && (now/60) % 60 >=24 && (now/60) % 60 <= 40 ) {
		// 	TRACE( "flagsChanged " + self._flags.format("%o"));
		// }

		if ( mask & (BGSLEEP_M|NODISTURB_M) != 0) {

			var dimNow = self._flags & (BGSLEEP_M|NODISTURB_M) == (BGSLEEP_M|NODISTURB_M);
			var dimPrev= prevFlags   & (BGSLEEP_M|NODISTURB_M) == (BGSLEEP_M|NODISTURB_M);

			if (dimNow != dimPrev) {
				TRACE("Night dimmer = " + dimNow.toString() );
				$.gTheme.setLightFactor2(dimNow ? 0.85 : 1.0);
			}
		}

		if (!self._freezeAlwaysOnDisplay) {
			if ( mask & (BGSLEEP_M|NODISTURB_M) != 0 ) {
				if (self._flags & (BGSLEEP_M|NODISTURB_M) == 0 ) {
					
					if (now - self.getLastChangeTime(BGSLEEP_M) <= 10 &&
						now - self.getLastChangeTime(NODISTURB_M) <= 10 ) {
							self._freezeAlwaysOnDisplay = true;
							self._freezeAlwaysOnDisplaySteps = ActivityMonitor.getInfo().steps;
							self._freezeAlwaysOnDisplayShowEventCount = 0;
						}
				}
			}
		}
		else {
			checkUnfreezeAlwaysOnDisplay();
		}
	}


	private function checkUnfreezeAlwaysOnDisplay() as Boolean {
		if (self._freezeAlwaysOnDisplayShowEventCount >= 3 ) {
			self._freezeAlwaysOnDisplay = false;
			TRACE("Unfreeze wake time show events = " + self._freezeAlwaysOnDisplayShowEventCount.toString() );
			return true;
		}

		var steps = ActivityMonitor.getInfo().steps;
		if (steps < self._freezeAlwaysOnDisplaySteps ||
			steps > self._freezeAlwaysOnDisplaySteps + 10) {
			self._freezeAlwaysOnDisplay = false;
			TRACE( Lang.format("Unfreeze wake time steps $1$ $2$", [self._freezeAlwaysOnDisplaySteps , steps] ) );
			return true;
		}
		return false;
	}

	public function onSettingsChanged() {
		var aodPowerSaverLevel = getApp().getProperty("AODPowerSaver");
		if (aodPowerSaverLevel == 0) {
			self._AODTimeout = 86400;
		}
		else if (aodPowerSaverLevel == 1){
			self._AODTimeout = 3600;
		}
		else if (aodPowerSaverLevel == 2){
			self._AODTimeout = 1800;
		}
		else if (aodPowerSaverLevel == 3){
			self._AODTimeout = 900;
		}

		self._nextAODOffTime = Time.now().value() + self._AODTimeout;

	}
	
}