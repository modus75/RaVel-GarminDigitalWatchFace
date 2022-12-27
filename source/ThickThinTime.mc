using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;
import Toybox.Lang;

class LowPowerProfile {
	public var HourFontDowngradeDelay as Number?;
	public var MinuteFontDowngradeDelay as Number?;

	public var HourAlphaParams = [0, 0, 0];
	public var MinuteAlphaParams = [0, 0, 0];

	public function setFontDowngradeDelay(hours, minutes) {
		HourFontDowngradeDelay = hours;
		MinuteFontDowngradeDelay = minutes;
	}

	public function setHourAlpha(mult, offset, cap) {
		self.HourAlphaParams = [mult, offset, cap];
	}
	public function setMinuteAlpha(mult, offset, cap) {
		self.MinuteAlphaParams = [mult, offset, cap];
	}

	public function computeColor( alphaParams, x, originalColor) {
		var factor = alphaParams[0] * x + alphaParams[1];
		if (factor <= 0) {
			return originalColor;
		}
		else 	if (factor > alphaParams[2]) {
			factor = alphaParams[2];
		}
		factor = 1 - factor;
		var r = Math.round( factor * ( (originalColor >> 16) & 0xff) ).toNumber();
		var g = Math.round( factor * ( (originalColor >> 8) & 0xff) ).toNumber();
		var b = Math.round( factor * ( originalColor & 0xff) ).toNumber();
		return (r << 16)  + (g << 8) + b;
	}
}

class ThickThinTime extends Ui.Drawable {

	private var _largeFonts = [];
	private var _smallFonts = [];

	private var _hourFonts;
	private var _minuteFonts;

	private var _currentHourFont, _currentMinuteFont;
	private var _currentHourColor, _currentMinuteColor;
	
	private var _aodPowerProfile = new LowPowerProfile();

	// "y" parameter passed to drawText(), read from layout.xml.
	private var mSecondsY;

	// Wide rectangle: time should be moved up slightly to centre within available space.
	private var mAdjustY = 0;

	// Tight clipping rectangle for drawing seconds during partial update.
	// "y" corresponds to top of glyph, which will be lower than "y" parameter of drawText().
	// drawText() starts from the top of the font ascent, which is above the top of most glyphs.
	private var mSecondsClipRectX;
	private var mSecondsClipRectWidth;
	private var mSecondsClipRectHeight;

	private var mTopFieldY = 40; // for layout of other fields
	private var mLeftFieldAdjustX = 0; // for layout of other fields

	private var mHoursAdjustX;
	private var mMinutesAdjustX;

	private var _hideSeconds = false;
	private var _burnProtection = false;
	private var _lastBurnOffsets = [0,0];
	private var _lastBurnOffsetsChangedTime;
	private var _lastBurnProtectionTime;

	private var _debugLowPowerMode = false;

	function initialize(params) {
		Drawable.initialize(params);

		if (params[:adjustY] != null) {
			self.mAdjustY = params[:adjustY];
		}

		self.mSecondsY = params[:secondsY];

		mSecondsClipRectX = params[:secondsX];
		mSecondsClipRectWidth = params[:secondsClipWidth];
		mSecondsClipRectHeight = params[:secondsClipHeight];

		if ( params[:topFieldY] != null) {
			mTopFieldY = params[:topFieldY];
		}
		if ( params[:leftFieldAdjustX] != null) {
			mLeftFieldAdjustX = params[:leftFieldAdjustX];
		}

		_largeFonts.add( Ui.loadResource(Rez.Fonts.TimeFont) );
		if (Rez.Fonts has :TimeFont_LoPower) {
			self._largeFonts.add( Ui.loadResource(Rez.Fonts.TimeFont_LoPower) );
		}
		else {
			self._largeFonts.add( _largeFonts[0] );
		}
		if (Rez.Fonts has :TimeFont_LoPower2) {
			self._largeFonts.add( Ui.loadResource(Rez.Fonts.TimeFont_LoPower2) );
		}
		if (Rez.Fonts has :TimeFont_LoPower3) {
			self._largeFonts.add( Ui.loadResource(Rez.Fonts.TimeFont_LoPower3) );
		}

		_smallFonts.add( Ui.loadResource(Rez.Fonts.TimeSmallFont) );
		if (Rez.Fonts has :TimeSmallFont_LoPower) {
			self._smallFonts.add( Ui.loadResource(Rez.Fonts.TimeSmallFont_LoPower) );
		}
		else {
			self._smallFonts.add( _smallFonts[0] );
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
		resetBurnProtectionStyles();
	}

	function exitBurnProtection() {
		if (self._burnProtection) {
			 self._burnProtection = false;
			 resetBurnProtectionStyles();
		}
	}

	function getSecondsX() {
		return self.mSecondsClipRectX;
	}

	function getSecondsY() {
		return self.mSecondsY;
	}

	function getTopFieldY() {
		return self.mTopFieldY;
	}

	function getLeftFieldAdjustX() {
		return self.mLeftFieldAdjustX;
	}

	function draw(dc) {
		drawHoursMinutes(dc);
		drawSeconds(dc, /* isPartialUpdate */ false);
	}

	function drawHoursMinutes(dc) {
		var clockTime = Sys.getClockTime();
		var formattedTime = self.getFormattedTime(clockTime.hour, clockTime.min);
		formattedTime[:amPm] = formattedTime[:amPm].toUpper();

		var hours = formattedTime[:hour];
		var minutes = formattedTime[:min];

		var x = dc.getWidth() / 2;
		var y = (dc.getHeight() / 2) + self.mAdjustY;
		
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
		dc.setColor( self._currentHourColor, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x + self.mHoursAdjustX,
			y,
			self._currentHourFont,
			hours,
			Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Draw minutes.
		dc.setColor( self._currentMinuteColor, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x + self.mMinutesAdjustX,
			y,
			self._currentMinuteFont,
			minutes,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

	}

	// Called to draw seconds both as part of full draw(), but also onPartialUpdate() of watch face in low power mode.
	// If isPartialUpdate flag is set to true, strictly limit the updated screen area: set clip rectangle before clearing old text
	// and drawing new. Clipping rectangle should not change between seconds.
	function drawSeconds(dc, isPartialUpdate) {
		if (self._hideSeconds /*|| self._burnProtection*/) {
			return;
		}

		var clockTime = Sys.getClockTime();

		if (self._burnProtection){
			if (_debugLowPowerMode && clockTime.sec != 0) {
				dc.drawText(
					self.mSecondsClipRectX,
					self.mSecondsY + self._lastBurnOffsets[1],
					Graphics.FONT_TINY,
					clockTime.sec.format("%02d"),
					Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
				);
			}
			return;
		}

		var seconds = clockTime.sec.format("%02d");

		if (isPartialUpdate) {

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

	function resetBurnProtectionStyles() {
		if (!self._burnProtection){
			self._currentHourFont = self._hourFonts[0];
			self._currentMinuteFont = self._minuteFonts[0];
		}
		else{
			self._currentHourFont = self._hourFonts[1];
			self._currentMinuteFont = self._minuteFonts[1];
		}
		self._currentHourColor = $.gTheme.HoursColor;
		self._currentMinuteColor = $.gTheme.MinutesColor;
	}


	function updateBurnProtectionStyles( duration as Number) {
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


			self._currentHourColor =  _aodPowerProfile.computeColor(_aodPowerProfile.HourAlphaParams, durationMin, $.gTheme.HoursColor );
			self._currentMinuteColor =  _aodPowerProfile.computeColor(_aodPowerProfile.MinuteAlphaParams, durationMin, $.gTheme.MinutesColor );
	}

	
	function onSettingsChanged() {
		self._debugLowPowerMode = getApp().getProperty("DebugLowPowerMode");
		var hoursFontType = getApp().getProperty("HoursFontType");
		var minutesFontType = getApp().getProperty("MinutesFontType");

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

		var aodPowerSaverLevel = getApp().getProperty("AODPowerSaver");
		if (aodPowerSaverLevel == 0) {
			_aodPowerProfile.setFontDowngradeDelay(1440, 1440);
			_aodPowerProfile.setHourAlpha(0, 0, 0);
			_aodPowerProfile.setMinuteAlpha(0, 0, 0);
		}
		else	if (aodPowerSaverLevel == 1) {
			_aodPowerProfile.setFontDowngradeDelay(2, 10);
			_aodPowerProfile.setHourAlpha(0.01, -0.02, 0.25);
			_aodPowerProfile.setMinuteAlpha(0.005, -0.01, 0.15);
		}
		else	if (aodPowerSaverLevel == 2) {
			_aodPowerProfile.setFontDowngradeDelay(1, 5);
			_aodPowerProfile.setHourAlpha(0.02, -0.02, 0.3);
			_aodPowerProfile.setMinuteAlpha(0.01, -0.01, 0.2);
		}
		else	if (aodPowerSaverLevel >= 3) {
			_aodPowerProfile.setFontDowngradeDelay(1, 3);
			_aodPowerProfile.setHourAlpha(0.025, 0, 0.35);
			_aodPowerProfile.setMinuteAlpha(0.01, -0.01, 0.25);
		}
		resetBurnProtectionStyles();
	}


	function getFormattedTime(hour, min) {
		var amPm = "";

		if (!System.getDeviceSettings().is24Hour) {

			// #6 Ensure noon is shown as PM.
			var isPm = (hour >= 12);
			if (isPm) {
				
				// But ensure noon is shown as 12, not 00.
				if (hour > 12) {
					hour = hour - 12;
				}
				amPm = "p";
			} else {
				
				// #27 Ensure midnight is shown as 12, not 00.
				if (hour == 0) {
					hour = 12;
				}
				amPm = "a";
			}
		}

		hour = hour.format( self._burnProtection ? "%d" : "%02d");

		return {
			:hour => hour,
			:min => min.format("%02d"),
			:amPm => amPm
		};
	}

		

}