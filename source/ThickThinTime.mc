using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Application as App;

class ThickThinTime extends Ui.Drawable {

	private var mHoursFont, mMinutesFont, mSecondsFont;

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
	
	private var AM_PM_X_OFFSET = 2;

	// #10 Adjust position of seconds to compensate for hidden hours leading zero.
	private var mSecondsClipXAdjust = 0;
	
	function initialize(params) {
		Drawable.initialize(params);

		if (params[:adjustY] != null) {
			mAdjustY = params[:adjustY];
		}

		if (params[:amPmOffset] != null) {
			AM_PM_X_OFFSET = params[:amPmOffset];
		}

		mSecondsY = params[:secondsY];

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


	function setHideSeconds(hideSeconds) {
		var ret = mHideSeconds != hideSeconds;
		mHideSeconds = hideSeconds;
		return ret;
	}
	
	function getSecondsX() {
		return mSecondsClipRectX + mSecondsClipXAdjust;
	}

	function getSecondsY() {
		return mSecondsY;
	}

	function getTopFieldY() {
		return mTopFieldY;
	}

	function getLeftFieldAdjustX() {
		return mLeftFieldAdjustX;
	}
	
	function draw(dc) {
		drawHoursMinutes(dc);
		drawSeconds(dc, /* isPartialUpdate */ false);
	}

	function drawHoursMinutes(dc) {
		var clockTime = Sys.getClockTime();
		var formattedTime = App.getApp().getFormattedTime(clockTime.hour, clockTime.min);
		formattedTime[:amPm] = formattedTime[:amPm].toUpper();

		var hours = formattedTime[:hour];
		var minutes = formattedTime[:min];
		//var amPmText = formattedTime[:amPm];

		var halfDCWidth = dc.getWidth() / 2;
		var halfDCHeight = (dc.getHeight() / 2) + mAdjustY;

		//var hoursWidth = dc.getTextWidthInPixels(hours, mHoursFont);
		//var minutesWidth = dc.getTextWidthInPixels(minutes, mMinutesFont);
		
		var x = halfDCWidth;
		
		// Draw hours.
		dc.setColor(gHoursColour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x + mHoursAdjustX,
			halfDCHeight,
			mHoursFont,
			hours,
			Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// Draw minutes.
		dc.setColor(gMinutesColour, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			x + mMinutesAdjustX,
			halfDCHeight,
			mMinutesFont,
			minutes,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);

		// If required, draw AM/PM after minutes, vertically centred.
/*		if (amPmText.length() > 0) {
			dc.setColor(gThemeColour, Graphics.COLOR_TRANSPARENT);
			x += dc.getTextWidthInPixels(minutes, mMinutesFont);
			dc.drawText(
				x + AM_PM_X_OFFSET, // Breathing space between minutes and AM/PM.
				halfDCHeight,
				mSecondsFont,
				amPmText,
				Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
			);
		}*/
	}

	// Called to draw seconds both as part of full draw(), but also onPartialUpdate() of watch face in low power mode.
	// If isPartialUpdate flag is set to true, strictly limit the updated screen area: set clip rectangle before clearing old text
	// and drawing new. Clipping rectangle should not change between seconds.
	function drawSeconds(dc, isPartialUpdate) {
		if (mHideSeconds) {
			return;
		}
		
		var clockTime = Sys.getClockTime();
		var seconds = clockTime.sec.format("%02d");

		if (isPartialUpdate) {

			dc.setClip(
				mSecondsClipRectX + mSecondsClipXAdjust,
				mSecondsY - mSecondsClipRectHeight/2,
				mSecondsClipRectWidth,
				mSecondsClipRectHeight
			);

			// Can't optimise setting colour once, at start of low power mode, at this goes wrong on real hardware: alternates
			// every second with inverse (e.g. blue text on black, then black text on blue).
			dc.setColor(gThemeColour, 
				//Graphics.COLOR_RED
				gBackgroundColour
			);	

			// Clear old rect (assume nothing overlaps seconds text).
			dc.clear();

		} else {

			// Drawing will not be clipped, so ensure background is transparent in case font height overlaps with another
			// drawable.
			dc.setColor(gThemeColour, Graphics.COLOR_TRANSPARENT);
		}

		dc.drawText(
			mSecondsClipRectX + mSecondsClipXAdjust,
			mSecondsY,
			mSecondsFont,
			seconds,
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
		);
		
	}
	
	function onSettingsChanged() {
		var hoursFontType = getApp().getProperty("HoursFontType");
		var minutesFontType = getApp().getProperty("MinutesFontType");
		
		mHoursFont = Ui.loadResource(hoursFontType ? Rez.Fonts.TimeSmallFont : Rez.Fonts.TimeFont);
		
		if (hoursFontType == minutesFontType) {
			mMinutesFont = mHoursFont;
		}
		else {
			mMinutesFont = Ui.loadResource(minutesFontType ? Rez.Fonts.TimeSmallFont : Rez.Fonts.TimeFont);
		}
		
		mHoursAdjustX = 0;
		mMinutesAdjustX = 0;
		
		if (hoursFontType) {
			mHoursAdjustX = -10;
		}
		
		if (minutesFontType) {
			mMinutesAdjustX = 10;
		}
		
		mSecondsFont = Graphics.FONT_NUMBER_MEDIUM;
	}
}