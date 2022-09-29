using Toybox.Time;


class SleepTimeTracker {

	enum {
		LOPOWER_F   = 0,
		VISIBLE_F   = 1,
		BGSLEEP_F   = 2,
		SLEEP_F     = 3,

		NB_FLAGS = 1 + SLEEP_F
	}

	enum {
		LOPOWER_M   = 1 << LOPOWER_F,
		VISIBLE_M   = 1 << VISIBLE_F,
		BGSLEEP_M   = 1 << BGSLEEP_F,
		SLEEP_M     = 1 << SLEEP_F,
	}

	private var _flags as Number;
	private var _lastChangeTimes = new [NB_FLAGS];

	function initialize() {
		_flags = 0;
		for (var i=0; i<NB_FLAGS; i++ ) {
			_lastChangeTimes[i] = 0;
		}
	}

	function onShow() as Void {
		setFlag(VISIBLE_F, 1 );
	}

	function onHide() as Void {
		setFlag(VISIBLE_F, 0 );
	}

	function onExitSleep() as Void {
		setFlag(LOPOWER_F, 0 );
	}

	function onEnterSleep() as Void {
		setFlag(LOPOWER_F, 1 );
	}

	function onBackgroundSleepTime() as Void {
		setFlag(BGSLEEP_F, 1 );
		setFlag(SLEEP_F, 1 );
	}

	function onBackgroundWakeTime() as Void {
		setFlag(BGSLEEP_F, 0 );
		setFlag(SLEEP_F, 0 );
	}

	function onUpdate() {
		// var mask;

		// mask = VISIBLE_M|LOPOWER_M|BGSLEEP_M|SLEEP_M;
		// if ( (self._flags & mask) == VISIBLE_M|LOPOWER_M|BGSLEEP_M|SLEEP_M) {
		// 	var now = Time.now().value();
		// 	var lastChange = self.getLastChangeTime( mask);
		// 	if (now -lastChange > 10) {
		// 		setFlag(SLEEP_F, 0);
		// 	}
		// }
	}

	public function getSleepMode() as Boolean {
		return (self._flags & SLEEP_M ) == SLEEP_M;
	}

	private function setFlag(flag as Number, on) {
		var mask = 1 << flag;
		var maskValue = on ? mask : 0;
		self.setMask( mask, maskValue);
	}

	private function setMask(mask as Number, maskValue as Number) {
		if  (self._flags & mask != maskValue) {

			self._flags = ( self._flags & ~mask) | maskValue;

			for (var i=0; i < NB_FLAGS; i++) {
				if ( (1<<i) & mask) {
					self._lastChangeTimes[i] = Time.now().value();
				}
			}
			
			processFlagsChanged(mask);
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

	private function processFlagsChanged(mask as Number) {
		if ( (mask & SLEEP_M) ) {
			$.gTheme.setLightFactor2(self.getSleepMode() ? 0.9 : 1.0);
		}

		TRACE(
		 Lang.format("Flags: $1$ $2$ $3$ $4$", [
			 (_flags & LOPOWER_M) == LOPOWER_M ? "Lo" : "Hi", 
			 (_flags & VISIBLE_M) == VISIBLE_M ? '1' : '0', 
			 (_flags & BGSLEEP_M) ? "sl" : "aw", 
			 (_flags & SLEEP_M) ? 	"SL" : "AW"
		 ]) );
	}
	
}