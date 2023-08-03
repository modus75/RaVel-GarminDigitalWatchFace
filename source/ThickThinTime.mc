import Toybox.Lang;
using Toybox.Graphics;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Application as App;

class LowPowerProfile {
	public var HourFontDowngradeDelay as Number?;
	public var MinuteFontDowngradeDelay as Number?;

	public function setFontDowngradeDelay(hours, minutes) {
		HourFontDowngradeDelay = hours;
		MinuteFontDowngradeDelay = minutes;
	}
}

class ThickThinTime
{

	private var _largeFonts as Array = [];
	private var _smallFonts as Array = [];

	private var _hourFonts as Array?;
	private var _minuteFonts as Array?;

	private var _currentHourFont, _currentMinuteFont;

	private var _aodPowerProfile = new LowPowerProfile();

	// "y" parameter passed to drawText(), read from layout.xml.
	private var mSecondsY;

	private var _locY as Number;

	// Tight clipping rectangle for drawing seconds during partial update.
	// "y" corresponds to top of glyph, which will be lower than "y" parameter of drawText().
	// drawText() starts from the top of the font ascent, which is above the top of most glyphs.
	private var mSecondsClipRectX;
	private var mSecondsClipRectWidth;
	private var mSecondsClipRectHeight;

	private var mTopFieldY = 40; // for layout of other fields

	private var mHoursAdjustX;
	private var mMinutesAdjustX;

	private var _hideSeconds = false;
	private var _burnProtection = false;
	private var _lastBurnOffsets as Array<Number> = [0,0];
	private var _lastBurnOffsetsChangedTime;
	private var _lastBurnProtectionTime;

	private var _debugLowPowerMode = false;

	function initialize(params as Dictionary, dc as Graphics.Dc) {

		self._locY = Utils.halfScreenHeight;

		if ( params.hasKey("adjustY") ) {
			self._locY += params["adjustY"];
		}

		self.mSecondsY = params["secondsY"];

		self.mSecondsClipRectX = params["secondsX"];
		self.mSecondsClipRectHeight = params["secondsClipHeight"];

		if ( params.hasKey("topFieldY") ) {
			self.mTopFieldY = params["topFieldY"];
		}

		self.mSecondsClipRectWidth = dc.getTextWidthInPixels("00", Graphics.FONT_NUMBER_MEDIUM);

		_largeFonts.add( Ui.loadResource(Rez.Fonts.TimeFont) );
		if (Rez.Fonts has :TimeFont_LoPower) {
			self._largeFonts.add( Ui.loadResource(Rez.Fonts.TimeFont_LoPower) );
		}
		else {
			self._largeFonts.add( self._largeFonts[0] );
		}
		if (Rez.Fonts has :TimeFont_LoPower2) {
			self._largeFonts.add( Ui.loadResource(Rez.Fonts.TimeFont_LoPower2) );
		}
		if (Rez.Fonts has :TimeFont_LoPower3) {
			self._largeFonts.add( Ui.loadResource(Rez.Fonts.TimeFont_LoPower3) );
		}

		self._smallFonts.add( Ui.loadResource(Rez.Fonts.TimeSmallFont) );
		if (Rez.Fonts has :TimeSmallFont_LoPower) {
			self._smallFonts.add( Ui.loadResource(Rez.Fonts.TimeSmallFont_LoPower) );
		}
		else {
			self._smallFonts.add( self._smallFonts[0] );
		}
		if (Rez.Fonts has :TimeSmallFont_LoPower2) {
			self._smallFonts.add( Ui.loadResource(Rez.Fonts.TimeSmallFont_LoPower2) );
		}
		if (Rez.Fonts has :TimeSmallFont_LoPower3) {
			self._smallFonts.add( Ui.loadResource(Rez.Fonts.TimeSmallFont_LoPower3) );
		}

		onSettingsChanged();
	}


	function getHideSeconds() {
		return _hideSeconds;
	}

	function setHideSeconds(hideSeconds) {
		var ret = self._hideSeconds != hideSeconds;
		self._hideSeconds = hideSeconds;
		return ret;
	}

	function enterBurnProtection() {
		self._burnProtection = true;
		self._lastBurnProtectionTime = Time.now().value();
		self._lastBurnOffsetsChangedTime = self._lastBurnProtectionTime;
		self._lastBurnOffsets = [ 0, 0 ];
		resetBurnProtectionStyles( false );
	}

	function exitBurnProtection( sleepMode as Boolean) {
		if (self._burnProtection) {
			 self._burnProtection = false;
			 resetBurnProtectionStyles( sleepMode );
		}
	}

	function getSecondsX() {
		return self.mSecondsClipRectX;
	}

	function getSecondsY() {
		return self.mSecondsY;
	}

	function getSecondsClipRectHeight() as Number {
		return self.mSecondsClipRectHeight;
	}

	function getTopFieldY() {
		return self.mTopFieldY;
	}

	public function draw(clockTime as System.ClockTime, dc as Graphics.Dc) {

		var hours = clockTime.hour.format( self._burnProtection ? "%d" : "%02d");
		var minutes =  clockTime.min.format("%02d");

		var x = Utils.halfScreenWidth;
		var y = self._locY;

		if (self._burnProtection) {
			var now = Time.now().value();
			if (self._lastBurnOffsetsChangedTime + 60 <= now) {
				self.updateBurnProtectionStyles( now - self._lastBurnProtectionTime );
				var offsets = [ -6, 0, 12, 18, 12, 0 ];
				var burnInOffset = offsets[clockTime.min % offsets.size()] + (Toybox.Math.rand() % 6 - 3);

				self._lastBurnOffsets = [Toybox.Math.rand() % 12 - 6, burnInOffset];
				self._lastBurnOffsetsChangedTime = now;
			}
			x += self._lastBurnOffsets[0];
			y += self._lastBurnOffsets[1];
		}

		// Draw hours.
		dc.setColor(  $.gTheme.HoursColor, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x + self.mHoursAdjustX,
			y,
			self._currentHourFont,
			hours,
			Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Draw minutes.
		dc.setColor(  $.gTheme.MinutesColor, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x + self.mMinutesAdjustX,
			y,
			self._currentMinuteFont,
			minutes,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		self.drawSeconds(clockTime.sec, dc, false);
	}

	// Called to draw seconds both as part of full draw(), but also onPartialUpdate() of watch face in low power mode.
	// If isPartialUpdate flag is set to true, strictly limit the updated screen area: set clip rectangle before clearing old text
	// and drawing new. Clipping rectangle should not change between seconds.
	function drawSeconds(sec as Number, dc as Graphics.Dc, isPartialUpdate as Boolean) {
		if (self._hideSeconds /*|| self._burnProtection*/) {
			return;
		}

		var seconds = sec.format("%02d");

		if (self._burnProtection){
			if (_debugLowPowerMode && sec != 0) {
				dc.drawText(
					self.mSecondsClipRectX,
					self.mSecondsY + self._lastBurnOffsets[1],
					Graphics.FONT_TINY,
					seconds,
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}
			return;
		}

		if ( isPartialUpdate ) {

			dc.setClip(
				self.mSecondsClipRectX,
				self.mSecondsY - self.mSecondsClipRectHeight/2,
				self.mSecondsClipRectWidth,
				self.mSecondsClipRectHeight
			);

			dc.setColor($.gTheme.ForeColor, $.gTheme.BackgroundColor );
			//dc.setColor($.gTheme.ForeColor, Graphics.COLOR_RED ); // debug

			// Clear old rect (assume nothing overlaps seconds text).
			dc.clear();

		} else {
			dc.setColor($.gTheme.ForeColor, Graphics.COLOR_TRANSPARENT);
			//dc.setColor($.gTheme.ForeColor, Graphics.COLOR_RED); // debug
		}

		dc.drawText(
			self.mSecondsClipRectX,
			self.mSecondsY,
			Graphics.FONT_NUMBER_MEDIUM,
			seconds,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

	}

	private function resetBurnProtectionStyles( sleepMode as Boolean ) {
		if (!self._burnProtection && !sleepMode){
			self._currentHourFont = self._hourFonts[0];
			self._currentMinuteFont = self._minuteFonts[0];
		}
		else{
			self._currentHourFont = self._hourFonts[1];
			self._currentMinuteFont = self._minuteFonts[1];
		}
	}


	private function updateBurnProtectionStyles( duration as Number) {
			var durationMin = duration / 60;

			var index = 1 + durationMin / _aodPowerProfile.HourFontDowngradeDelay;
			if (index >= self._hourFonts.size()) {
				index = self._hourFonts.size() - 1;
			}
			self._currentHourFont = self._hourFonts[index];

			index = 1 + durationMin / _aodPowerProfile.MinuteFontDowngradeDelay;
			if (index >= self._minuteFonts.size()) {
				index = self._minuteFonts.size() - 1;
			}
			self._currentMinuteFont = self._minuteFonts[index];
	}


	function onSettingsChanged() {
		self._debugLowPowerMode = Application.Properties.getValue("DebugLowPowerMode");
		var hoursFontType = Application.Properties.getValue("HoursFontType");
		var minutesFontType = Application.Properties.getValue("MinutesFontType");

		self._hourFonts = hoursFontType ? self._smallFonts : self._largeFonts;
		self._minuteFonts = minutesFontType ? self._smallFonts : self._largeFonts;

		self.mHoursAdjustX = 0;
		self.mMinutesAdjustX = 0;

		if (hoursFontType) {
			self.mHoursAdjustX = -10;
		}

		if (minutesFontType) {
			self.mMinutesAdjustX = 10;
		}

		if (System.getDeviceSettings().screenWidth > 400){
			self.mHoursAdjustX -= 5;
			self.mMinutesAdjustX += 5;
		}

		var aodPowerSaverLevel = Application.Properties.getValue("AODPowerSaver");
		if (aodPowerSaverLevel == 0) {
			_aodPowerProfile.setFontDowngradeDelay(1440, 1440);
		}
		else	if (aodPowerSaverLevel == 1) {
			_aodPowerProfile.setFontDowngradeDelay(2, 10);
		}
		else	if (aodPowerSaverLevel == 2) {
			_aodPowerProfile.setFontDowngradeDelay(1, 3);
		}
		else	if (aodPowerSaverLevel >= 3) {
			_aodPowerProfile.setFontDowngradeDelay(1, 1);
		}
		resetBurnProtectionStyles( false );
	}


}