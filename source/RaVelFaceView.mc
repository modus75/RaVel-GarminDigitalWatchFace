import Toybox.Application;
import Toybox.Activity;
using  Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
using Toybox.WatchUi;
using Toybox.Time.Gregorian;
using Toybox.SensorHistory;
using Toybox.Sensor;


var gTheme;


enum /* DATA_TYPES */ {
	DATA_TYPE_OFF = 0,

	DATA_TYPE_STEPS = 1,
	DATA_TYPE_FLOORS_CLIMBED = 2,
	DATA_TYPE_ACTIVE_MINUTES = 3,
	DATA_TYPE_NOTIFICATIONS = 4,
	DATA_TYPE_HEART_RATE = 5,
	DATA_TYPE_BATTERY = 6,
	DATA_TYPE_BODY_BATTERY = 7,
	DATA_TYPE_STRESS_LEVEL = 8,
	DATA_TYPE_RESPIRATION = 9,
	DATA_TYPE_WEATHER = 10,
	DATA_TYPE_DATE = 16,
	DATA_TYPE_DEBUG = 99,
}


const BURN_PROTECTION_UNDEFINED = 0;
const BURN_PROTECTION_SHOW_ICON = 1;
const BURN_PROTECTION_SHOW_TEXT = 2;

class RaVelFaceView extends WatchUi.WatchFace {
	private var mTime;
	private var mGauges = [null, null];
	private var mMeters = [null, null];

	private var mMeterTypes = [0 , 0];
	private var mGaugeTypes = [0 , 0];

	private var mTopDataType;

	private var mBottomLeftDataType;
	private var mBottomRightDataType;

	private var mIconsFont;

	private var mSecondsDisplayMode;

	private var mShowAlarmIcon;
	private var mShowDontDisturbIcon;
	private var mShowNotificationIcon;

	private var _burnProtection = false;
	private var mLastBurnOffsets = [0,0];
	private var mLastBurnOffsetsChangedMinute = 0;

	private var _lightDimmer;
	private var _sleepTimeTracker;

	function initialize() {
		WatchFace.initialize();
		$.gTheme = new Theme();
	}

	function onLayout(dc as Dc) as Void {
		setLayout(Rez.Layouts.WatchFace(dc));

		var ravelOptions;
		if (Rez.JsonData has :ravelOptions) {
			ravelOptions = Application.loadResource(Rez.JsonData.ravelOptions);
		}
		else {
			ravelOptions = {};
		}

		mIconsFont = WatchUi.loadResource(Rez.Fonts.IconsFont);
		mTime = View.findDrawableById("Time");

		mMeters[0] = View.findDrawableById("LeftGoalMeter");
		mMeters[1] = View.findDrawableById("RightGoalMeter");

		mGauges[0] = View.findDrawableById("LeftGauge");
		mGauges[1] = View.findDrawableById("RightGauge");


		if (ravelOptions["displayMeterIcons"]) {
			mMeters[0].setIconFont(mIconsFont);
			mMeters[1].setIconFont(mIconsFont);
		}

		if ( System.getDeviceSettings() has :requiresBurnInProtection && System.getDeviceSettings().requiresBurnInProtection) {
			self._lightDimmer = new TimeBasedLightDimmer(); // should test for amoled
			self._sleepTimeTracker = new SleepTimeTracker();
		}
		else {
			self._lightDimmer = new NullLightDimmer();
			self._sleepTimeTracker = new NullSleepTimeTracker();
		}

		for (var i=0 ;i<2 ; i++) {
			if (mGauges[i]) {
				mGauges[i].setIconFont( self.mIconsFont );
				mGauges[i].setY( mTime.getTopFieldY() - 1 );
			}
		}

		self.onSettingsChanged();

	}

	function onUpdate(dc as Dc) as Void {
		//System.println("onUpdate");

		if (!self._sleepTimeTracker.onUpdate()) {
			dc.setColor(Graphics.COLOR_TRANSPARENT, $.gTheme.BackgroundColor);
			dc.clear();
			return;
		}

		// Clear any partial update clipping.
		dc.clearClip();

		var now = System.getClockTime();
		self._lightDimmer.check( now );

		if (self._burnProtection && self.mLastBurnOffsetsChangedMinute != now.min) {
			self.mLastBurnOffsets = [Math.rand() % 16 - 8, Math.rand() % 16 - 8];
			self.mLastBurnOffsetsChangedMinute = now.min;
			for (var i=0; i < 2; i++) {
				if (self.mGauges[i]) {
					self.mGauges[i].setXYOffset(self.mLastBurnOffsets[0], self.mLastBurnOffsets[1]);
				}
			}
		}

		updateDrawables();

		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);

		var values;

		/* top data above clock*/
		if (!self._burnProtection) {
			values = self.getValuesForDataType( self.mTopDataType );

			if ( values[:isValid] ) {
				var font = Graphics.FONT_LARGE;
				var x = dc.getWidth()/2;
				var y = mTime.getTopFieldY();
				var textDims = dc.getTextDimensions(values[:text], font);

				if ( values[:icon] != null ) {
					dc.setColor( ( (values[:valueColor]!=null) ? values[:valueColor] : $.gTheme.IconColor ), Graphics.COLOR_TRANSPARENT);

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
		if (!self._burnProtection) {
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
					dc.setColor( values[:valueColor]!=null ? values[:valueColor] : $.gTheme.IconColor, Graphics.COLOR_TRANSPARENT);

					var iconDims = dc.getTextDimensions(values[:icon], mIconsFont);
					dc.drawText(
						x - textDims[0]/2 + 2,
						y - (textDims[1]*3)/10 + iconDims[1]/2, /* icon higher so that it has more space*/
						self.mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
				}

				dc.setColor( values[:valueColor]!=null ? values[:valueColor] : $.gTheme.ForeColor, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x,
					y,
					font, values[:text], Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

			}
		}


		/* very bottom */
		{
			values = self.getValuesForDataType(self.mBottomRightDataType);

			if ( values[:isValid] && (!self._burnProtection || values[:burnProtection]!=null)) {
				var font = Graphics.FONT_NUMBER_MILD;

				var textDims = dc.getTextDimensions(values[:text], font);

				var x = dc.getWidth()/2;
				var y = dc.getHeight() - textDims[1]/2 + 1;

				if (self._burnProtection) {
					x += self.mLastBurnOffsets[0];
					y -= self.mLastBurnOffsets[1].abs();
				}

				if ( values[:icon] != null ) {

					var iconDims = dc.getTextDimensions(values[:icon], self.mIconsFont);
					textDims[0] += iconDims[0]; // center on icon+text

					if (!self._burnProtection || values[:burnProtection] & BURN_PROTECTION_SHOW_ICON) {
						dc.setColor( values[:valueColor]!=null ? values[:valueColor] : $.gTheme.IconColor, Graphics.COLOR_TRANSPARENT);
						dc.drawText(
							x - (textDims[0])/2,
							y,
							self.mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
					}
				}

				if (!self._burnProtection || values[:burnProtection] & BURN_PROTECTION_SHOW_TEXT) {
					dc.setColor( values[:valueColor]!=null ? values[:valueColor] : $.gTheme.ForeColor, Graphics.COLOR_TRANSPARENT);
					dc.drawText(
						x + textDims[0]/2,
						y,
						font, values[:text], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
				}
			}
		}


		/* icons */
		if (!self._burnProtection) {
			var icons = "";
			if (self.mShowAlarmIcon) {
				if ( System.getDeviceSettings().alarmCount ) {
					var tmp = icons + ICON_ALARMS;
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
		//TRACE("onShow");
		self._sleepTimeTracker.onShow();
	}

	function onHide() as Void {
		//TRACE("onHide");
		self._sleepTimeTracker.onHide();
	}

	function onExitSleep() as Void {
		//TRACE("onExitSleep");
		self._sleepTimeTracker.onExitSleep();
		self._burnProtection = false;
		for (var i=0; i < 2; i++) {
			if (self.mGauges[i]) {
				self.mGauges[i].setXYOffset(0,0);
			}
		}
		self.mTime.exitBurnProtection();
	}

	function onEnterSleep() as Void {
		//TRACE("onEnterSleep");
		self._sleepTimeTracker.onEnterSleep();
		if (System.getDeviceSettings().requiresBurnInProtection) {
			self._burnProtection = true;
			self.mLastBurnOffsetsChangedMinute = System.getClockTime().min;
			self.mLastBurnOffsets = [0,0];
			self.mTime.enterBurnProtection();
		}
	}

	function onBackgroundSleepTime() as Void {
		self._sleepTimeTracker.onBackgroundSleepTime();
	}

	function onBackgroundWakeTime() as Void {
		self._sleepTimeTracker.onBackgroundWakeTime();
	}

	function onSettingsChanged() {
		self._lightDimmer.onSettingsChanged();
		self._sleepTimeTracker.onSettingsChanged();
		$.gTheme.onSettingsChanged();

		var theme = getApp().getProperty("Theme");

		self.mMeterTypes[0] = Application.getApp().getProperty("LeftGoalType");
		self.mMeterTypes[1] = Application.getApp().getProperty("RightGoalType");
		self.mGaugeTypes[0] = Application.getApp().getProperty("LeftGaugeType");
		self.mGaugeTypes[1] = Application.getApp().getProperty("RightGaugeType");

		self.mSecondsDisplayMode = Application.getApp().getProperty("SecondsDisplayMode");

		if (mTime != null) {
			mMeters[0].onSettingsChanged();
			mMeters[1].onSettingsChanged();

			mTime.onSettingsChanged();

			if ( self.mSecondsDisplayMode < 2 ) {
				self.mTime.setHideSeconds(self.mSecondsDisplayMode ? false : true);
			}
		}


		mTopDataType = Application.getApp().getProperty("TopDataType");
		mBottomLeftDataType = Application.getApp().getProperty("BottomLeftDataType");
		mBottomRightDataType = Application.getApp().getProperty("BottomDataType");

		mShowAlarmIcon = Application.getApp().getProperty("ShowAlarmIcon");
		mShowDontDisturbIcon = Application.getApp().getProperty("ShowDontDisturbIcon");
		mShowNotificationIcon = Application.getApp().getProperty("ShowNotificationIcon");
	}


	function getValuesForDataType(type) {
		var values = {
			:isValid => true
		};

		var info = ActivityMonitor.getInfo();
		var settings = System.getDeviceSettings();

		switch (type) {
			case DATA_TYPE_STEPS:
				values[:value] = info.steps;
				values[:max] = info.stepGoal;
				values[:icon] = ICON_STEPS;
				break;
			case DATA_TYPE_ACTIVE_MINUTES:
				if (info has :activeMinutesWeek) {
					values[:value] = info.activeMinutesWeek.total;
					values[:max] = 100;
				}
				values[:icon] = ICON_ACTIVE_MINUTES;
				break;
			case DATA_TYPE_FLOORS_CLIMBED:
				if (info has :floorsClimbed) {
					values[:value] = info.floorsClimbed;
					values[:max] = info.floorsClimbedGoal;
				}
				values[:icon] = ICON_FLOORS_UP;
				break;
			case DATA_TYPE_NOTIFICATIONS:
				values[:value] = settings.notificationCount;
				if (settings.phoneConnected) {
					if (settings.notificationCount == 0) {
						values[:valueColor] = $.gTheme.LowKeyColor;
						values[:icon] = ICON_NOTIFICATIONS_EMPTY;
					}
					else {
						values[:icon] = ICON_NOTIFICATIONS_FULL;
						values[:max] = 1;
						if (self._burnProtection || self._sleepTimeTracker.getSleepMode()) {
							values[:valueColor] = $.gTheme.ForeColor;
							values[:burnProtection] = BURN_PROTECTION_SHOW_ICON;
						}
					}
				}
				else {
					values[:text] = "-";
					values[:burnProtection] = BURN_PROTECTION_SHOW_ICON;
					values[:valueColor] = $.gTheme.WarnColor;
					values[:icon] = ICON_PHONE_DISCONNECTED;
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
				values[:icon] = ICON_HEART_EMPTY;
				break;
			case DATA_TYPE_BATTERY:
				var batteryLevel = System.getSystemStats().battery;
				values[:value] = Math.floor(batteryLevel);
				values[:max] = 100;
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
					values[:icon] = batteryLevel > 15 ? ICON_BATTERY_QUARTER : ICON_BATTERY_EMPTY;

					if (batteryLevel < 10 || System.getSystemStats().batteryInDays < 1) {
						values[:valueColor] = $.gTheme.ErrorColor;
						values[:burnProtection] = BURN_PROTECTION_SHOW_ICON;
					}
					else if (batteryLevel < 15 || System.getSystemStats().batteryInDays < 2) {
						values[:valueColor] = $.gTheme.WarnColor;
						values[:burnProtection] = BURN_PROTECTION_SHOW_ICON;
					}
				}
				break;

			case DATA_TYPE_BODY_BATTERY:
				if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
					var it = Toybox.SensorHistory.getBodyBatteryHistory({"period"=>1,"order"=>SensorHistory.ORDER_NEWEST_FIRST});
					var sample = it.next();
					if (sample != null) {
						values[:value] = sample.data;
						values[:max] = 100;
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
						values[:max] = 100;
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
			case DATA_TYPE_WEATHER:
				{
					var wCond= Weather.getCurrentConditions();
					values[:value] = wCond.precipitationChance;
					values[:max] = 100;
					values[:text] = Lang.format("$1$°", [wCond.temperature] );
				}
				break;
			case DATA_TYPE_DATE:
				var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

				var dow = [
						"Su",
						"Mo",
						"Tu",
						"We",
						"Th",
						"Fr",
						"Sa"
						][now.day_of_week - 1];
				//dow = dow.substring(0,2);

				values[:value] = dow + " " + now.day.format("%d");
				break;

			case DATA_TYPE_DEBUG:
				{
					/*var wCond= Weather.getCurrentConditions();
					values[:value] = wCond.precipitationChance;
					values[:text] = Lang.format("$1$ $2$%", [wCond.temperature, wCond.precipitationChance] );*/
				}
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

	private function updateDrawables() {
		var sleepMode = self._sleepTimeTracker.getSleepMode();
		/* meters */
		if (!self._burnProtection && !sleepMode ) {
			for (var i=0; i < 2; i++) {
				var values = self.getValuesForDataType(self.mMeterTypes[i]);
				self.mMeters[i].setValues(values[:isValid] ? values : null);
			}
		}
		else {
			self.mMeters[0].setValues( null );
			self.mMeters[1].setValues( null );
		}

		/* gauges */
		for (var i=0; i < 2; i++) {
			if (self.mGauges[i]) {
				var values = self.getValuesForDataType(self.mGaugeTypes[i]);

				var displayType = GAUGE_DISPLAY_OFF;
				if (values[:isValid]) {
					if (self._burnProtection || sleepMode) {
						displayType = values[:burnProtection] == BURN_PROTECTION_SHOW_ICON ? GAUGE_DISPLAY_ICON : GAUGE_DISPLAY_OFF;
					}
					else {
						displayType = GAUGE_DISPLAY_ALL;
					}
				}

				if (displayType == GAUGE_DISPLAY_ALL && self.mGaugeTypes[i] == DATA_TYPE_NOTIFICATIONS) {
					displayType = GAUGE_DISPLAY_ICON;
					if (values[:value] > 0 && values[:valueColor] == null) {
						values[:valueColor] = $.gTheme.ForeColor;
					}
				}

				self.mGauges[i].setValues(values, displayType);
			}
		}

		/* time */
		var show = true;
		if (self.mSecondsDisplayMode == 2) {
			if (System.getDeviceSettings().doNotDisturb ||sleepMode ) {
				show = false;
			}
			self.mTime.setHideSeconds(!show);
		}


	}

}
