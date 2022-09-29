using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

	private var mHoursFont, mMinutesFont, mSecondsFont;
	private var mHoursFontOutline, mMinutesFontOutline;

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

	private var mHideSeconds = false;
	private var mBurnProtection = false;
	private var mLastBurnOffsets = [0,0];
	private var mLastBurnOffsetsChangedMinute = 0;

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

		onSettingsChanged();
	}


	function getHideSeconds() {
		return mHideSeconds;
	}

	function setHideSeconds(hideSeconds) {
		var ret = self.mHideSeconds != hideSeconds;
		self.mHideSeconds = hideSeconds;
		return ret;
	}

	function setBurnProtection(burnProtection) {
		self.mBurnProtection = burnProtection;
		self.mLastBurnOffsetsChangedMinute = Sys.getClockTime().min;
		self.mLastBurnOffsets = [0,0];
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
		
		if (self.mBurnProtection) {
			if (self.mLastBurnOffsetsChangedMinute != clockTime.min) {
				var offsets = [ -6, 0, 12, 18, 12, 0 ];
				var burnInOffset = offsets[clockTime.min % offsets.size()] + (Toybox.Math.rand() % 6 - 3);

				self.mLastBurnOffsets = [Toybox.Math.rand() % 12 - 6, burnInOffset];
				self.mLastBurnOffsetsChangedMinute = clockTime.min;
			}
			x += self.mLastBurnOffsets[0];
			y += self.mLastBurnOffsets[1];
		}

		// Draw hours.
		dc.setColor($.gTheme.HoursColor, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x + self.mHoursAdjustX,
			y,
			self.mBurnProtection ? self.mHoursFontOutline : self.mHoursFont,
			hours,
			Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Draw minutes.
		dc.setColor($.gTheme.MinutesColor, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x + self.mMinutesAdjustX,
			y,
			self.mBurnProtection ? self.mMinutesFontOutline : self.mMinutesFont,
			minutes,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

	}

	// Called to draw seconds both as part of full draw(), but also onPartialUpdate() of watch face in low power mode.
	// If isPartialUpdate flag is set to true, strictly limit the updated screen area: set clip rectangle before clearing old text
	// and drawing new. Clipping rectangle should not change between seconds.
	function drawSeconds(dc, isPartialUpdate) {
		if (self.mHideSeconds || self.mBurnProtection) {
			return;
		}

		var clockTime = Sys.getClockTime();
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
			self.mSecondsFont,
			seconds,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

	}

	function onSettingsChanged() {
		var hoursFontType = getApp().getProperty("HoursFontType");
		var minutesFontType = getApp().getProperty("MinutesFontType");

		self.mHoursFont = Ui.loadResource(hoursFontType ? Rez.Fonts.TimeSmallFont : Rez.Fonts.TimeFont);

		if (Rez.Fonts has :TimeFontOutline && Rez.Fonts has :TimeSmallFontOutline) {
			self.mHoursFontOutline = Ui.loadResource(hoursFontType ? Rez.Fonts.TimeSmallFontOutline : Rez.Fonts.TimeFontOutline);
		}
		else {
			self.mHoursFontOutline = self.mHoursFont;
		}

		if (hoursFontType == minutesFontType) {
			self.mMinutesFont = self.mHoursFont;
			self.mMinutesFontOutline = self.mHoursFontOutline;
		}
		else {
			self.mMinutesFont = Ui.loadResource(minutesFontType ? Rez.Fonts.TimeSmallFont : Rez.Fonts.TimeFont);
			if (Rez.Fonts has :TimeFontOutline && Rez.Fonts has :TimeSmallFontOutline) {
				self.mMinutesFontOutline = Ui.loadResource(minutesFontType ? Rez.Fonts.TimeSmallFontOutline : Rez.Fonts.TimeFontOutline);
			}
			else {
				self.mMinutesFontOutline = self.mMinutesFont;
			}
		}

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

		self.mSecondsFont = Graphics.FONT_NUMBER_MEDIUM;
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

		hour = hour.format( self.mBurnProtection ? "%d" : "%02d");

		return {
			:hour => hour,
			:min => min.format("%02d"),
			:amPm => amPm
		};
	}

}