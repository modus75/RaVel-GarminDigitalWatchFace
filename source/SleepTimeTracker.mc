using Toybox.Time;


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
}


class SleepTimeTracker {

	enum {
		LOPOWER_F   = 0,
		VISIBLE_F   = 1,
		BGSLEEP_F   = 2,
		NODISTURB_F = 3,
		
		NB_FLAGS = 4
	}

	enum {
		LOPOWER_M   = 1 << LOPOWER_F,
		VISIBLE_M   = 1 << VISIBLE_F,
		BGSLEEP_M   = 1 << BGSLEEP_F,
		NODISTURB_M = 1 << NODISTURB_F,
	}

	private var _flags as Number;
	private var _lastChangeTimes = new [NB_FLAGS];

	private var _freezeAlwaysOnDisplay;
	private var _freezeAlwaysOnDisplaySteps;
	private var _freezeAlwaysOnDisplayShowEventCount;

	function initialize() {
		self._freezeAlwaysOnDisplay = false;
		self._freezeAlwaysOnDisplaySteps = 0;
		self._freezeAlwaysOnDisplayShowEventCount = 0;

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
	}

	function onExitSleep() as Void {
		setMask(LOPOWER_M | NODISTURB_M, (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
	}

	function onEnterSleep() as Void {
		setMask(LOPOWER_M | NODISTURB_M, LOPOWER_M | (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
	}

	function onBackgroundSleepTime() as Void {
		setMask(BGSLEEP_M | NODISTURB_M, BGSLEEP_M | (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
	}

	function onBackgroundWakeTime() as Void {
		setMask(BGSLEEP_M | NODISTURB_M, (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );
	}

	function onUpdate() {
		setMask(NODISTURB_M, (System.getDeviceSettings().doNotDisturb ? NODISTURB_M : 0) );

		if (self._freezeAlwaysOnDisplay && !self.checkUnfreezeAlwaysOnDisplay()) {
			 if (self._flags & (BGSLEEP_M|NODISTURB_M|LOPOWER_M) == LOPOWER_M) {
				return false;
			 }
		}

		return true;
	}

	public function getSleepMode() as Boolean {
		return (self._flags & (BGSLEEP_M|NODISTURB_M) ) == (BGSLEEP_M|NODISTURB_M);
	}


	private function setMask(mask as Number, maskValue as Number) {

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

		if ( mask & (BGSLEEP_M|NODISTURB_M) != 0) {

			var dimNow = self._flags & (BGSLEEP_M|NODISTURB_M) == (BGSLEEP_M|NODISTURB_M);
			var dimPrev= prevFlags   & (BGSLEEP_M|NODISTURB_M) == (BGSLEEP_M|NODISTURB_M);

			if (dimNow != dimPrev) {
				$.gTheme.setLightFactor2(dimNow ? 0.9 : 1.0);
			}
		}

		if (!self._freezeAlwaysOnDisplay) {
			if ( mask & (BGSLEEP_M|NODISTURB_M) != 0 ) {
				if (self._flags & (BGSLEEP_M|NODISTURB_M) == 0 ) {
					
					if (now - self.getLastChangeTime(BGSLEEP_M) < 15 &&
						now - self.getLastChangeTime(NODISTURB_M) < 15 ) {
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
		if (self._freezeAlwaysOnDisplayShowEventCount >= 2 ) {
			self._freezeAlwaysOnDisplay = false;
			return true;
		}

		var steps = ActivityMonitor.getInfo().steps;
		if (steps < self._freezeAlwaysOnDisplaySteps ||
			steps > self._freezeAlwaysOnDisplaySteps + 10) {
			self._freezeAlwaysOnDisplay = false;
			return true;
		}
		return false;
	}
	
}