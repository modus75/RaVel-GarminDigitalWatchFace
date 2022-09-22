import Toybox.Application;
import Toybox.Activity;
using  Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
using Toybox.WatchUi;
using Toybox.Time.Gregorian;

var gThemeColour;
var gBackgroundColour;
var gLowKeyColor;
var gWarnColor;
var gIconColor;
var gEmptyMeterColour;
var gFullMeterColour;
var gHoursColour;
var gMinutesColour;

enum /* DATA_TYPES */ {
	DATA_TYPE_OFF = 0,

	DATA_TYPE_STEPS = 1,
	DATA_TYPE_ACTIVE_MINUTES = 2,
	DATA_TYPE_FLOORS_CLIMBED = 3,
	DATA_TYPE_NOTIFICATIONS = 4,
	DATA_TYPE_HEART_RATE = 5,
	DATA_TYPE_BATTERY = 6,
	DATA_TYPE_DATE = 7
}


const ICON_STEPS ="0";
const ICON_ACTIVE_MINUTES = "2";
const ICON_FLOORS_UP = "1";
const ICON_HEART_EMPTY = "3";
const ICON_HEART_FULL = "3";
const ICON_NOTIFICATIONS_EMPTY = "5";
const ICON_NOTIFICATIONS_FULL = "5";
const ICON_BELL_EMPTY = ":";
const ICON_BELL_FULL = ":";
const ICON_BATTERY_EMPTY = "4";
const ICON_BATTERY_HALF = "9";
const ICON_BATTERY_FULL = "9";
const ICON_BLUETOOTH_EMPTY = "8";
const ICON_BLUETOOTH_FULL = "8";
const ICON_DONT_DISTURB="?";
/*
const ICON_STEPS="s";
const ICON_ACTIVE_MINUTES = "t";
const ICON_CALORIES = "c";
const ICON_FLOORS_UP = "F";
const ICON_FLOORS_DOWN = "f";
const ICON_HEART_EMPTY = "P";
const ICON_HEART_FULL = "p";
const ICON_BELL_EMPTY = "A";
const ICON_BELL_FULL= "a";
const ICON_NOTIFICATIONS_EMPTY = "N";
const ICON_NOTIFICATIONS_FULL = "n";
const ICON_BATTERY_EMPTY = "k";
const ICON_BATTERY_HALF = "m";
const ICON_BATTERY_FULL = "h";
const ICON_BATTERY_LOADING = "l";
const ICON_BLUETOOTH_EMPTY = "B";
const ICON_BLUETOOTH_FULL = "b";
const ICON_DONT_DISTURB="d";
*/

const BURN_PROTECTION_UNDEFINED = 0;
const BURN_PROTECTION_SHOW_ICON = 1;
const BURN_PROTECTION_SHOW_TEXT = 2;

class RaVelFaceView extends WatchUi.WatchFace {

	private var mBurnProtection = false;
	private var mTime;
	private var mDrawables = {};

	private var mLeftMeterType;
	private var mRightMeterType;

	private var mTopDataType;

	private var mBottomLeftDataType;
	private var mBottomRightDataType;

	private var mIconsFont;

	private var mSecondsDisplayMode;

	private var mShowAlarmIcon;
	private var mShowDontDisturbIcon;
	private var mShowNotificationIcon;

    function initialize() {
        WatchFace.initialize();

        self.onSettingsChanged();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
        mIconsFont = WatchUi.loadResource(Rez.Fonts.IconsFont);

        mDrawables[:LeftGoalMeter] = View.findDrawableById("LeftGoalMeter");
		mDrawables[:RightGoalMeter] = View.findDrawableById("RightGoalMeter");

        mTime = View.findDrawableById("Time");

        self.onSettingsChanged();

    }

    function onUpdate(dc as Dc) as Void {
    	//System.println("onUpdate");

		// Clear any partial update clipping.
		dc.clearClip();

		updateSecondsVisibility();
		updateMeters();

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);

        var values;

		/* top data above clock*/
		if (!self.mBurnProtection) {
			values = self.getValuesForDataType( self.mTopDataType );

			if ( values[:isValid] ) {
				var font = Graphics.FONT_LARGE;
				var x = dc.getWidth()/2;
				var y = mTime.getTopFieldY();
				var textDims = dc.getTextDimensions(values[:text], font);

				if ( values[:icon] != null ) {
					dc.setColor( ( (values[:iconColor]!=null) ? values[:iconColor] : $.gIconColor ), Graphics.COLOR_TRANSPARENT);

					var iconDims = dc.getTextDimensions(values[:icon], self.mIconsFont);
					textDims[0] += iconDims[0]; // center on icon+text

					dc.drawText(
						x - textDims[0]/2,
						y, /* icon higher so that it has more space*/
						self.mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
				}

				dc.setColor( $.gThemeColour , Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x + textDims[0] /2,
					y,
					font, values[:text], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
			}
		}

		/* bottom left below clock */
		if (!self.mBurnProtection) {
			values = self.getValuesForDataType(self.mBottomLeftDataType);

			if ( values[:isValid] ) {
				var font = Graphics.FONT_NUMBER_MEDIUM;

				var x;
				if (self.mTime.getHideSeconds()) {
					x = dc.getWidth()/2;
				}
				else {
					x = self.mTime.getLeftFieldAdjustX() + self.mTime.getSecondsX() / 2;
				}
				var y = self.mTime.getSecondsY();
				var textDims = dc.getTextDimensions(values[:text], font);

				if ( values[:icon] != null && x-textDims[0]/2 > 10 ) {
					dc.setColor( ( (values[:iconColor]!=null) ? values[:iconColor] : $.gIconColor ), Graphics.COLOR_TRANSPARENT);

					var iconDims = dc.getTextDimensions(values[:icon], mIconsFont);
					dc.drawText(
						x - textDims[0]/2,
						y - (textDims[1]*3)/10 + iconDims[1]/2, /* icon higher so that it has more space*/
						self.mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
				}

				dc.setColor( ( (values[:color]!=null) ? values[:color] : $.gThemeColour ), Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x,
					y,
					font, values[:text], Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

			}
		}


		/* very bottom */
		{
			values = self.getValuesForDataType(self.mBottomRightDataType);

			if ( values[:isValid] && (!self.mBurnProtection || values[:burnProtection])) {
				var font = Graphics.FONT_NUMBER_MILD;

				var textDims = dc.getTextDimensions(values[:text], font);

				var x = dc.getWidth()/2;
				var y = dc.getHeight() - textDims[1]/2 + 1;

				if ( values[:icon] != null ) {

					var iconDims = dc.getTextDimensions(values[:icon], self.mIconsFont);
					textDims[0] += iconDims[0]; // center on icon+text

					if (!self.mBurnProtection || values[:burnProtection] & BURN_PROTECTION_SHOW_ICON) {
						dc.setColor( ( (values[:iconColor]!=null) ? values[:iconColor] : $.gIconColor ), Graphics.COLOR_TRANSPARENT);
						dc.drawText(
							x - (textDims[0])/2,
							y,
							self.mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
					}
				}

				if (!self.mBurnProtection || values[:burnProtection] & BURN_PROTECTION_SHOW_TEXT) {
					dc.setColor( ( (values[:color]!=null) ? values[:color] : $.gThemeColour ), Graphics.COLOR_TRANSPARENT);
					dc.drawText(
						x + textDims[0]/2,
						y,
						font, values[:text], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
				}
			}
		}


		/* icons */
		if (!self.mBurnProtection) {
			var icons = "";
			if (self.mShowAlarmIcon) {
				if ( System.getDeviceSettings().alarmCount ) {
					var tmp = icons + ICON_BELL_FULL;
					icons = tmp;
				}
			}

			if (self.mShowDontDisturbIcon) {
				if ( System.getDeviceSettings().doNotDisturb ) {
					var tmp = icons + ICON_DONT_DISTURB;
					icons = tmp;
				}
			}
			if (self.mShowNotificationIcon) {
				if ( System.getDeviceSettings().notificationCount ) {
					var tmp = icons + ICON_NOTIFICATIONS_FULL;
					icons = tmp;
				}
			}

			if ( icons.length() ) {
					dc.setColor( $.gLowKeyColor, Graphics.COLOR_TRANSPARENT );
					dc.drawText(
						dc.getWidth()/2,
						0,
						self.mIconsFont,
						icons,
						Graphics.TEXT_JUSTIFY_CENTER);

			}
		}

	}

	function onPartialUpdate(dc as Dc) as Void{
		//System.println("onPartialUpdate");
		mTime.drawSeconds(dc, /* isPartialUpdate */ true);
	}

	function onShow() as Void {
		System.println("onShow");
	}

	function onHide() as Void {
		System.println("onHide");
	}

	function onExitSleep() as Void {
		System.println("onExitSleep");
		self.mBurnProtection = false;
		self.mTime.setBurnProtection(self.mBurnProtection);
	}

	function onEnterSleep() as Void {
		System.println("onEnterSleep");
		if (System.getDeviceSettings().requiresBurnInProtection) {
			self.mBurnProtection = true;
			self.mTime.setBurnProtection(self.mBurnProtection);
		}
	}


	function onSettingsChanged() {
		var theme = getApp().getProperty("Theme");
		var colors = [];

		switch (theme) {
			case 1:
				colors = [
					Graphics.COLOR_WHITE, Graphics.COLOR_BLACK,
					Graphics.COLOR_LT_GRAY, Graphics.COLOR_ORANGE, Graphics.COLOR_LT_GRAY,
					Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLUE,
					Graphics.COLOR_BLACK, Graphics.COLOR_BLACK
				];
				break;
			default:
				colors = [
					Graphics.COLOR_BLACK, Graphics.COLOR_WHITE,
					Graphics.COLOR_DK_GRAY, Graphics.COLOR_ORANGE, Graphics.COLOR_DK_GRAY,
					Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLUE
				];
		}
		$.gBackgroundColour = colors[0];
		$.gThemeColour = colors[1];

		$.gLowKeyColor = colors[2];
		$.gWarnColor = colors[3];
		$.gIconColor = colors[4];

		$.gEmptyMeterColour = colors[5];
		$.gFullMeterColour = colors[6];

		if (colors.size() > 7) {
			gHoursColour = colors[7];
			gMinutesColour = colors[8];
		}
		else {
			gHoursColour = gThemeColour;
			gMinutesColour = gThemeColour;
		}


		mLeftMeterType = Application.getApp().getProperty("LeftGoalType");
		mRightMeterType = Application.getApp().getProperty("RightGoalType");

		mSecondsDisplayMode = Application.getApp().getProperty("SecondsDisplayMode");

		if (mDrawables.size() > 0) {
			mDrawables[:LeftGoalMeter].onSettingsChanged();
			mDrawables[:RightGoalMeter].onSettingsChanged();

			mTime.onSettingsChanged();

			updateSecondsVisibility();
		}


		mTopDataType = Application.getApp().getProperty("TopDataType");
		mBottomLeftDataType = Application.getApp().getProperty("BottomLeftDataType");
		mBottomRightDataType = Application.getApp().getProperty("BottomDataType");

		mShowAlarmIcon = Application.getApp().getProperty("ShowAlarmIcon");
		mShowDontDisturbIcon = Application.getApp().getProperty("ShowDontDisturbIcon");
		mShowNotificationIcon = Application.getApp().getProperty("ShowNotificationIcon");
	}


	function getValuesForDataType(type) {
		var burnProtection = self.mBurnProtection;
		var values = {
			:isValid => true
		};

		var info = ActivityMonitor.getInfo();
		var settings = System.getDeviceSettings();

		switch (type) {
			case DATA_TYPE_STEPS:
				values[:value] = info.steps;
				values[:icon] = ICON_STEPS;
				break;
			case DATA_TYPE_ACTIVE_MINUTES:
				if (info has :activeMinutesWeek) {
					values[:value] = info.activeMinutesWeek.total;
				}
				values[:icon] = ICON_ACTIVE_MINUTES;
				break;
			case DATA_TYPE_FLOORS_CLIMBED:
				if (info has :floorsClimbed) {
					values[:value] = info.floorsClimbed;
				}
				values[:icon] = ICON_FLOORS_UP;
				break;
			case DATA_TYPE_NOTIFICATIONS:
				values[:value] = settings.notificationCount;
				if (settings.phoneConnected) {
					if (settings.notificationCount == 0) {
						values[:color] = $.gLowKeyColor;
						values[:icon] = ICON_NOTIFICATIONS_EMPTY;
					}
					else {
						values[:icon] = ICON_NOTIFICATIONS_FULL;
						if (burnProtection) {
							values[:iconColor] = $.gThemeColour;
							values[:burnProtection] = BURN_PROTECTION_SHOW_ICON;
						}
					}
				}
				else {
					values[:text] = "-";
					values[:burnProtection] = BURN_PROTECTION_SHOW_ICON;
					values[:color] = $.gWarnColor;
					values[:iconColor] = $.gWarnColor;
					values[:icon] = ICON_BLUETOOTH_EMPTY;
				}
				break;
			case DATA_TYPE_HEART_RATE:
				var activityInfo = Activity.getActivityInfo();
				if (activityInfo.currentHeartRate != null) {
					values[:value] = activityInfo.currentHeartRate;
				} else if (ActivityMonitor has :getHeartRateHistory) {
					var sample = ActivityMonitor.getHeartRateHistory(1, /* newestFirst */ true)
						.next();
					if ((sample != null) && (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
						values[:value] = sample.heartRate;
					}
				}
				values[:icon] = ICON_HEART_FULL;
				break;
			case DATA_TYPE_BATTERY:
				values[:value] = Math.floor(System.getSystemStats().battery);
				values[:text] = values[:value].format("%.0f");
				values[:icon] = ICON_BATTERY_FULL;
				if (values[:value] < 80) {
					values[:icon] = ICON_BATTERY_HALF;
				}
				if (values[:value] < 25) {
					values[:color] = $.gWarnColor;
					values[:icon] = ICON_BATTERY_EMPTY;
					values[:iconColor] = $.gWarnColor;
				}
				break;
			case DATA_TYPE_DATE:
				var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

				var dow = [
						"Sun",
						"Mon",
						"Tue",
						"Wed",
						"Thu",
						"Fri",
						"Sat"
						][now.day_of_week - 1];
				//dow = dow.substring(0,2);

				values[:value] = dow + " " + now.day.format("%d");
				break;

		}

		if (values[:value]==null) {
			values[:isValid] = false;
		}
		if (values[:text]==null && values[:isValid]) {
			values[:text] = values[:value].toString();
		}

		return values;
	}

	static function getValuesForGoalType(type) {
		var values = {
			:current => 0,
			:max => 1,
			:isValid => true
		};

		var info = ActivityMonitor.getInfo();

		switch(type) {
			case GOAL_TYPE_STEPS:
				values[:current] = info.steps;
				values[:max] = info.stepGoal;
				break;

			case GOAL_TYPE_FLOORS_CLIMBED:
				if (info has :floorsClimbed) {
					values[:current] = info.floorsClimbed;
					values[:max] = info.floorsClimbedGoal;
				} else {
					values[:isValid] = false;
				}

				break;

			case GOAL_TYPE_ACTIVE_MINUTES:
				if (info has :activeMinutesWeek) {
					values[:current] = info.activeMinutesWeek.total;
					values[:max] = info.activeMinutesWeekGoal;
				} else {
					values[:isValid] = false;
				}
				break;

			case GOAL_TYPE_BATTERY:
				// #8: floor() battery to be consistent.
				values[:current] = Math.floor(System.getSystemStats().battery);
				values[:max] = 100;
				break;

			case GOAL_TYPE_OFF:
				values[:isValid] = false;
				break;
		}

		// #16: If user has set goal to zero, or negative (in simulator), show as invalid. Set max to 1 to avoid divide-by-zero
		// crash in GoalMeter.getSegmentScale().
		if (values[:max] < 1) {
			values[:max] = 1;
			values[:isValid] = false;
		}

		return values;
	}


	private function updateMeters() {
		var leftValues = getValuesForGoalType(self.mLeftMeterType);
		self.mDrawables[:LeftGoalMeter].setValues(leftValues[:current], leftValues[:max], /* isOff */ self.mLeftMeterType == GOAL_TYPE_OFF || self.mBurnProtection);

		var rightValues = getValuesForGoalType(self.mRightMeterType);
		self.mDrawables[:RightGoalMeter].setValues(rightValues[:current], rightValues[:max], /* isOff */ self.mRightMeterType == GOAL_TYPE_OFF || self.mBurnProtection);
	}

	private function updateSecondsVisibility() {
		var show = true;
		if (self.mSecondsDisplayMode == 2 && System.getDeviceSettings().doNotDisturb) {
			show = false;
		}
		else if (self.mSecondsDisplayMode == 0) {
			show = false;
		}

		if ( self.mTime != null) {
			if (self.mTime.setHideSeconds(!show)) {
				WatchUi.requestUpdate();
			}
		}
	}

}
