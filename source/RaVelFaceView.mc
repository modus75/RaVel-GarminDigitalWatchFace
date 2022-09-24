import Toybox.Application;
import Toybox.Activity;
using  Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
using Toybox.WatchUi;
using Toybox.Time.Gregorian;
using Toybox.SensorHistory;


var gTheme = new Theme();


enum /* DATA_TYPES */ {
	DATA_TYPE_OFF = 0,

	DATA_TYPE_STEPS = 1,
	DATA_TYPE_ACTIVE_MINUTES = 2,
	DATA_TYPE_FLOORS_CLIMBED = 3,
	DATA_TYPE_NOTIFICATIONS = 4,
	DATA_TYPE_HEART_RATE = 5,
	DATA_TYPE_BATTERY = 6,
	DATA_TYPE_BODY_BATTERY = 7,
	DATA_TYPE_STRESS_LEVEL = 8,
	DATA_TYPE_RESPIRATION = 9,
	DATA_TYPE_DATE = 16,
}


const BURN_PROTECTION_UNDEFINED = 0;
const BURN_PROTECTION_SHOW_ICON = 1;
const BURN_PROTECTION_SHOW_TEXT = 2;

class RaVelFaceView extends WatchUi.WatchFace {
	private var mTime;
	private var mDrawables = {};

	private var mLeftMeterType;
	private var mRightMeterType;

	private var mLeftGaugeType;
	private var mRightGaugeType;

	private var mTopDataType;

	private var mBottomLeftDataType;
	private var mBottomRightDataType;

	private var mIconsFont;

	private var mSecondsDisplayMode;

	private var mShowAlarmIcon;
	private var mShowDontDisturbIcon;
	private var mShowSleepModeIcon;
	private var mShowNotificationIcon;

	private var mBurnProtection = false;
	private var mLastBurnOffsets = [0,0];
	private var mLastBurnOffsetsChangedMinute = 0;

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
        mDrawables[:LeftGauge] = View.findDrawableById("LeftGauge");
		if (mDrawables[:LeftGauge]) {
			mDrawables[:LeftGauge].setIconFont( self.mIconsFont );
		}	
		mDrawables[:RightGauge] = View.findDrawableById("RightGauge");
		if (mDrawables[:RightGauge]) {
			mDrawables[:RightGauge].setIconFont( self.mIconsFont );
		}

        mTime = View.findDrawableById("Time");

        self.onSettingsChanged();

    }

    function onUpdate(dc as Dc) as Void {
    	//System.println("onUpdate");

		// Clear any partial update clipping.
		dc.clearClip();

		updateSecondsVisibility();
		updateMeters();
		updateGauges();
		if (self.mBurnProtection && self.mLastBurnOffsetsChangedMinute !=  System.getClockTime().min) {
			self.mLastBurnOffsets = [Math.rand() % 12 - 6, Math.rand() % 12 - 6];
			self.mLastBurnOffsetsChangedMinute = System.getClockTime().min;
		}

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
					dc.setColor( ( (values[:iconColor]!=null) ? values[:iconColor] : $.gTheme.IconColor ), Graphics.COLOR_TRANSPARENT);

					var iconDims = dc.getTextDimensions(values[:icon], self.mIconsFont);
					textDims[0] += iconDims[0]; // center on icon+text

					dc.drawText(
						x - textDims[0]/2,
						y, /* icon higher so that it has more space*/
						self.mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
				}

				dc.setColor( $.gTheme.ForeColor, Graphics.COLOR_TRANSPARENT);
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
					dc.setColor( values[:iconColor]!=null ? values[:iconColor] : $.gTheme.IconColor, Graphics.COLOR_TRANSPARENT);

					var iconDims = dc.getTextDimensions(values[:icon], mIconsFont);
					dc.drawText(
						x - textDims[0]/2 + 2,
						y - (textDims[1]*3)/10 + iconDims[1]/2, /* icon higher so that it has more space*/
						self.mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
				}

				dc.setColor( values[:color]!=null ? values[:color] : $.gTheme.ForeColor, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x,
					y,
					font, values[:text], Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

			}
		}


		/* very bottom */
		{
			values = self.getValuesForDataType(self.mBottomRightDataType);

			if ( values[:isValid] && (!self.mBurnProtection || values[:burnProtection]!=null)) {
				var font = Graphics.FONT_NUMBER_MILD;

				var textDims = dc.getTextDimensions(values[:text], font);

				var x = dc.getWidth()/2;
				var y = dc.getHeight() - textDims[1]/2 + 1;

				if (self.mBurnProtection) {
					x += self.mLastBurnOffsets[0];
					y -= self.mLastBurnOffsets[1].abs();
				}

				if ( values[:icon] != null ) {

					var iconDims = dc.getTextDimensions(values[:icon], self.mIconsFont);
					textDims[0] += iconDims[0]; // center on icon+text

					if (!self.mBurnProtection || values[:burnProtection] & BURN_PROTECTION_SHOW_ICON) {
						dc.setColor( values[:iconColor]!=null ? values[:iconColor] : $.gTheme.IconColor, Graphics.COLOR_TRANSPARENT);
						dc.drawText(
							x - (textDims[0])/2,
							y,
							self.mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
					}
				}

				if (!self.mBurnProtection || values[:burnProtection] & BURN_PROTECTION_SHOW_TEXT) {
					dc.setColor( values[:color]!=null ? values[:color] : $.gTheme.ForeColor, Graphics.COLOR_TRANSPARENT);
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
			if (self.mShowSleepModeIcon) {
				if ( ActivityMonitor.getInfo() has :isSleepMode && ActivityMonitor.getInfo().isSleepMode ) {
					icons = (icons + ICON_SLEEP);
				}
			}
			if (self.mShowNotificationIcon) {
				if ( System.getDeviceSettings().notificationCount ) {
					var tmp = icons + ICON_NOTIFICATIONS_FULL;
					icons = tmp;
				}
			}

			if ( icons.length() ) {
					dc.setColor( $.gTheme.LowKeyColor, Graphics.COLOR_TRANSPARENT );
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
			self.mLastBurnOffsetsChangedMinute = System.getClockTime().min;
			self.mLastBurnOffsets = [0,0];
			self.mTime.setBurnProtection(self.mBurnProtection);
		}
	}


	function onSettingsChanged() {
		$.gTheme.onSettingsChanged();

		var theme = getApp().getProperty("Theme");

		self.mLeftMeterType = Application.getApp().getProperty("LeftGoalType");
		self.mRightMeterType = Application.getApp().getProperty("RightGoalType");
		self.mLeftGaugeType = Application.getApp().getProperty("LeftGaugeType");
		self.mRightGaugeType = Application.getApp().getProperty("RightGaugeType");

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
		mShowSleepModeIcon = Application.getApp().getProperty("ShowSleepModeIcon");
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
						values[:color] = $.gTheme.LowKeyColor;
						values[:icon] = ICON_NOTIFICATIONS_EMPTY;
					}
					else {
						values[:icon] = ICON_NOTIFICATIONS_FULL;
						if (burnProtection) {
							values[:iconColor] = $.gTheme.ForeColor;
							values[:burnProtection] = BURN_PROTECTION_SHOW_ICON;
						}
					}
				}
				else {
					values[:text] = "-";
					values[:burnProtection] = BURN_PROTECTION_SHOW_ICON;
					values[:color] = $.gTheme.WarnColor;
					values[:iconColor] = $.gTheme.WarnColor;
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
				var batteryLevel = Math.floor(System.getSystemStats().battery);
				values[:value] = batteryLevel;
				values[:text] = values[:value].format("%.0f");
				if (batteryLevel > 85) {
					values[:icon] = ICON_BATTERY_FULL;
				}
				else if (batteryLevel > 65) {
					values[:icon] = ICON_BATTERY_3QUARTERS;
				}
				else if (batteryLevel > 35) {
					values[:icon] = ICON_BATTERY_HALF;
				}
				else { 
					values[:icon] = batteryLevel > 10 ? ICON_BATTERY_QUARTER : ICON_BATTERY_EMPTY;
					if (batteryLevel < 5 || System.getSystemStats().batteryInDays <= 1) {
						values[:color] = $.gTheme.WarnColor;
						values[:iconColor] = $.gTheme.WarnColor;
					}
				}
				break;

			case DATA_TYPE_BODY_BATTERY:
				if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
					var it = Toybox.SensorHistory.getBodyBatteryHistory({"period"=>1,"order"=>SensorHistory.ORDER_NEWEST_FIRST});
					var sample = it.next();
					if (sample != null) {
						values[:value] = sample.data;
						values[:text] = values[:value].format("%.0f");
						values[:icon] = ICON_BODY_BATTERY;
					}
				}
				break;
			case DATA_TYPE_STRESS_LEVEL:
				if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getStressHistory)) {
					var it = Toybox.SensorHistory.getStressHistory({"period"=>1,"order"=>SensorHistory.ORDER_NEWEST_FIRST});
					var sample = it.next();
					if (sample != null) {
						values[:value] = sample.data;
						values[:text] = values[:value].format("%.0f");
						values[:icon] = ICON_STRESS_LEVEL;
					}
				}
				break;
			case DATA_TYPE_RESPIRATION:
				if (info has :respirationRate and info.respirationRate  != null) {
					values[:value] = info.respirationRate ;
				}
				values[:icon] = ICON_RESPIRATION;
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

		var values = null;

		var info = ActivityMonitor.getInfo();

		switch(type) {
			case GOAL_TYPE_STEPS:
				values = self.getValuesForDataType(DATA_TYPE_STEPS);
				values[:max] = info.stepGoal;
				break;

			case GOAL_TYPE_FLOORS_CLIMBED:
				if (info has :floorsClimbed) {
					values = self.getValuesForDataType(DATA_TYPE_FLOORS_CLIMBED);
					values[:max] = info.floorsClimbedGoal;
				}
				break;

			case GOAL_TYPE_ACTIVE_MINUTES:
				if (info has :activeMinutesWeek) {
					values = self.getValuesForDataType(DATA_TYPE_ACTIVE_MINUTES);
					values[:max] = 100;
				}
				break;

			case GOAL_TYPE_BATTERY:
				values = self.getValuesForDataType(DATA_TYPE_BATTERY);
				values[:max] = 100;
				break;

			case GOAL_TYPE_BODY_BATTERY:
				values = self.getValuesForDataType(DATA_TYPE_BODY_BATTERY);
				values[:max] = 100;
				break;

			case GOAL_TYPE_STRESS_LEVEL:
				values = self.getValuesForDataType(DATA_TYPE_STRESS_LEVEL);
				values[:max] = 100;
				break;

		}

		if ( values == null) {
			values = { :isValid => false}; 
		}

		return values;
	}


	private function updateMeters() {
		var leftValues = getValuesForGoalType(self.mLeftMeterType);
		self.mDrawables[:LeftGoalMeter].setValues(leftValues[:value], leftValues[:max], /* isOff */ self.mLeftMeterType == GOAL_TYPE_OFF || self.mBurnProtection);

		var rightValues = getValuesForGoalType(self.mRightMeterType);
		self.mDrawables[:RightGoalMeter].setValues(rightValues[:value], rightValues[:max], /* isOff */ self.mRightMeterType == GOAL_TYPE_OFF || self.mBurnProtection);
	}

	private function updateGauges() {
		if (self.mDrawables[:LeftGauge]) {
			var leftValues = getValuesForGoalType(self.mLeftGaugeType);
			var gauge = self.mDrawables[:LeftGauge];
			gauge.setY( mTime.getTopFieldY() );
			gauge.setValues(leftValues, /* isOff */ self.mLeftGaugeType == GOAL_TYPE_OFF || self.mBurnProtection);
		}

		if (self.mDrawables[:RightGauge]) {
			var rightValues = getValuesForGoalType(self.mRightGaugeType);
			var gauge = self.mDrawables[:RightGauge];
			gauge.setY( mTime.getTopFieldY() );
			gauge.setValues(rightValues, /* isOff */ self.mRightGaugeType == GOAL_TYPE_OFF || self.mBurnProtection);
		}
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
