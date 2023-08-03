import Toybox.Lang;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time.Gregorian;
using Toybox.Time;
using Toybox.Weather;


enum /* DATA_TYPES */ {
	DATA_TYPE_OFF = 0,

	DATA_TYPE_BATTERY = 1,
	DATA_TYPE_STEPS = 2,
	DATA_TYPE_CALORIES = 3,
	DATA_TYPE_FLOORS_CLIMBED = 4,
	DATA_TYPE_ACTIVE_MINUTES = 5,
	DATA_TYPE_DATE = 7,
	DATA_TYPE_WEATHER = 8,
	DATA_TYPE_ALTITUDE = 15,
	DATA_TYPE_NOTIFICATIONS = 17,
	DATA_TYPE_HEART_RATE = 18,
	DATA_TYPE_RECOVERY_TIME = 21,
	DATA_TYPE_STRESS_LEVEL = 22,
	DATA_TYPE_BODY_BATTERY = 23,
	DATA_TYPE_PULSE_OX = 35,
	DATA_TYPE_RESPIRATION = 36,
	/* above match complication ids */
	DATA_TYPE_DAY_OF_MONTH = 98,
	DATA_TYPE_SECONDS = 99,
	DATA_TYPE_DEBUG1 = 101,
	DATA_TYPE_DEBUG2 = 102,
	DATA_TYPE_DEBUG3 = 103,
}

class DataValues
{
	var dataType as Number;

	var value as Numeric?;
	var text  as String?;

	var max as Numeric?;
	var icon as String?;
	var color as Number?;
	var burnProtection as Number = 0;
	var canForceBurnProtection as Boolean = false;

	function initialize(dataType as Number)
	{
		self.dataType = dataType;
	}

	function refresh() as Boolean { return false; }
}


module DataManager {

var __allDataValues as Array<DataValues> = new [DATA_TYPE_DEBUG3+1];

public function getOrCreateDataValues(type as Number) as DataValues
{
		var data = DataManager.__allDataValues[type];
		var info = ActivityMonitor.getInfo();
		if (data ==null)
		{
			switch (type)
			{
				case DATA_TYPE_STEPS:
					data = new StepsDataValues();
					break;
				case DATA_TYPE_FLOORS_CLIMBED:
					data = info has :floorsClimbed ? new FloorsUpDataValues(type, ICON_FLOORS_UP) : new NullDataValues(type, ICON_FLOORS_UP);
					break;
				case DATA_TYPE_ACTIVE_MINUTES:
					if (info has :activeMinutesWeek) {
						data = new DynamicDataValues(type, ICON_ACTIVE_MINUTES);
						data.max = 100;
					} else {
						data = new NullDataValues(type, ICON_ACTIVE_MINUTES);
					}
					break;
				case DATA_TYPE_HEART_RATE:
					data = (ActivityMonitor has :getHeartRateHistory) ? new DynamicDataValues(type, ICON_HEART_EMPTY) : new NullDataValues(type, ICON_HEART_EMPTY);
					break;
				case DATA_TYPE_BATTERY:
					data = new BatteryDataValues();
					break;
				case DATA_TYPE_NOTIFICATIONS:
					data = new NotificationsDataValues();
					break;
				case DATA_TYPE_CALORIES:
					data = new DynamicDataValues(type, ICON_CALORIES);
					break;
				case DATA_TYPE_BODY_BATTERY:
					if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
						data = new DynamicDataValues(type, ICON_BODY_BATTERY);
						data.max = 100;
					} else {
						data = new NullDataValues(type, ICON_BODY_BATTERY);
					}
					break;
				case DATA_TYPE_STRESS_LEVEL:
					if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getStressHistory)) {
						data = new DynamicDataValues(type, ICON_STRESS_LEVEL);
						data.max = 100;
					} else {
						data = new NullDataValues(type, ICON_STRESS_LEVEL);
					}
					break;
				case DATA_TYPE_PULSE_OX:
					data =((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getOxygenSaturationHistory)) ? new PulseOxDataValues(type, ICON_PULSE_OX) : new NullDataValues(type, ICON_PULSE_OX);
					break;
				case DATA_TYPE_ALTITUDE:
					data = ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getElevationHistory)) ? new DynamicDataValues(type, ICON_ALTITUDE) : new NullDataValues(type, ICON_ALTITUDE);
					break;
				case DATA_TYPE_RESPIRATION:
					data = (info has :respirationRate and info.respirationRate != null) ? new DynamicDataValues(type, ICON_RESPIRATION) : new NullDataValues(type, ICON_RESPIRATION);
					break;
				case DATA_TYPE_WEATHER:
					data = new WeatherDataValues();
					break;
				case DATA_TYPE_SECONDS:
					data = new DynamicDataValues(type, null);
					data.max = 60;
					break;
				case DATA_TYPE_DEBUG1:
					data = new DynamicDataValues(type, null);
					data.max = 3600;
					break;
				default:
					data = new DynamicDataValues(type, null);
			}
			DataManager.__allDataValues[type] = data;
		}
		return data;
}

}


class NullDataValues extends DataValues
{
	public function initialize(dataType as Number, icon as String?) {
		DataValues.initialize(dataType);
		self.icon = icon;
	}
}


class StepsDataValues extends DataValues
{
	public function initialize() {
		DataValues.initialize(DATA_TYPE_STEPS);
		self.icon = ICON_STEPS;
		self.max = ActivityMonitor.getInfo().stepGoal;
	}

	public function refresh() as Boolean {
		var info = ActivityMonitor.getInfo();
		var val = info.steps;
		if (val != self.value) {
			self.value = val;
			self.text = val.toString();
			self.max = info.stepGoal;
			return true;
		}
		return false;
	}
}


class FloorsUpDataValues extends DataValues
{
	public function initialize(dataType as Number, icon as String) {
		DataValues.initialize(dataType);
		self.icon = icon;
		self.max = ActivityMonitor.getInfo().floorsClimbedGoal;
	}

	public function refresh() as Boolean {
		var info = ActivityMonitor.getInfo();
		var val = info.floorsClimbed;
		if (val != self.value) {
			self.value = val;
			self.text = val.toString();
			self.max = info.floorsClimbedGoal;
			return true;
		}
		return false;
	}
}


class NotificationsDataValues extends DataValues
{
	public function initialize() {
		DataValues.initialize(DATA_TYPE_NOTIFICATIONS);
		self.canForceBurnProtection = true;
	}

	public function refresh() as Boolean {
		var settings = System.getDeviceSettings();

		var vValue = settings.notificationCount, vText = null, vColor = null;

		if (settings.phoneConnected) {
			if (vValue == 0) {
				vColor = $.gTheme.LowKeyColor;
				self.icon = ICON_NOTIFICATIONS_EMPTY;
				self.burnProtection = 0;
			}
			else {
				vColor = $.gTheme.ForeColor;
				self.icon = ICON_NOTIFICATIONS_FULL;
				self.burnProtection = DISPLAY_ICON;
			}
		}
		else {
			vText = "-";
			vColor = $.gTheme.WarnColor;
			self.icon = ICON_PHONE_DISCONNECTED;
			self.burnProtection = DISPLAY_ICON;
		}

		var changed = vValue != self.value || vColor != self.color;

		if ( changed ) {
			self.value = vValue;
			self.color = vColor;
			self.text = vText!=null ? vText : vValue.toString();
		}

		return changed;
	}
}


class BatteryDataValues extends DataValues
{
	public function initialize() {
		DataValues.initialize(DATA_TYPE_BATTERY);
		self.max = 100;
		self.canForceBurnProtection = true;
	}

	public function refresh() as Boolean {
		var batteryLevel = System.getSystemStats().battery;

		var vValue = Math.floor(batteryLevel).toNumber();
		if ( vValue == self.value) {
			return false;
		}
		self.value = vValue;
		self.text = vValue.toString();
		self.color = null;
		self.burnProtection = 0;

		if (batteryLevel > 85) {
			self.icon = ICON_BATTERY_FULL;
		}
		else if (batteryLevel > 65) {
			self.icon = ICON_BATTERY_3QUARTERS;
		}
		else if (batteryLevel > 35) {
			self.icon = ICON_BATTERY_HALF;
		}
		else {
			self.icon = batteryLevel > 15 ? ICON_BATTERY_QUARTER : ICON_BATTERY_EMPTY;

			var batteryInDays = System.getSystemStats().batteryInDays;
			if (batteryLevel < 10 || batteryInDays < 1) {
				self.color = $.gTheme.ErrorColor;
				self.burnProtection = DISPLAY_ICON | DISPLAY_TEXT;
			}
			else if (batteryLevel < 15 || (batteryLevel < 20 && batteryInDays < 2) ) {
				self.color = $.gTheme.WarnColor;
				self.burnProtection = DISPLAY_ICON | DISPLAY_TEXT;
			}
		}
		return true;
	}
}


class PulseOxDataValues extends DataValues
{
	public function initialize(type as Number, icon as String) {
		DataValues.initialize(type);
		self.icon = icon;
		self.max = 100;
	}

	public function refresh() as Boolean {
		var activityInfo = Activity.getActivityInfo();
		var vValue = null;
		if (activityInfo.currentOxygenSaturation != null) {
			vValue = activityInfo.currentOxygenSaturation;
		} else {
			var sample = Toybox.SensorHistory.getOxygenSaturationHistory({"period"=>1,"order"=>SensorHistory.ORDER_NEWEST_FIRST}).next();
			if (sample != null && sample.data != null) {
				vValue = sample.data.toNumber();
			}
		}

		if (vValue == self.value) {
			return false;
		}

		if (vValue != null) {
			if (vValue >= 90) {
				self.color = Graphics.COLOR_GREEN;
			}
			else if (vValue >= 80) {
				self.color = BRIGHT_YELLOW;
			}
			else if (vValue >= 70) {
				self.color = BRIGHT_ORANGE;
			}
			else {
				self.color = 0xcc6600;
			}
			self.text = vValue.toString();
		} else {
			self.text = null;
		}

		self.value = vValue;
		return true;
	}
}

class WeatherDataValues extends DataValues
{
	private var _useStatute as Boolean = false;

	public function initialize() {
		DataValues.initialize(DATA_TYPE_WEATHER);
		self.value = 0;
		self.max = 100;
		if ( System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ) {
			self._useStatute = true;
		}
	}

	public function refresh() as Boolean {
		var wCond= Weather.getCurrentConditions();
		if ( wCond == null ) {
			return false;
		}

		self.value = wCond.precipitationChance;
		var temperature = wCond.temperature;
		if (self._useStatute) {
			temperature = 32 + ( temperature * 9 + 2 )/ 5;
		}
		var vText = Lang.format("$1$°", [temperature] );
/*
		self.icon = null;
		switch (wCond.condition) {
			case Weather.CONDITION_CLEAR:
				self.icon = "\uf00d"; break; // night f02e
			case Weather.CONDITION_CLOUDY:
			case Weather.CONDITION_MOSTLY_CLOUDY:
				self.icon = "\uf013"; break;
			case Weather.CONDITION_PARTLY_CLOUDY:
			case Weather.CONDITION_MOSTLY_CLEAR:
				self.icon = "\uf002"; break; // night f086
			case Weather.CONDITION_RAIN:
			case Weather.CONDITION_LIGHT_RAIN:
			case Weather.CONDITION_HEAVY_RAIN:
				self.icon = "\uf019"; break;
			case Weather.CONDITION_SHOWERS:
			case Weather.CONDITION_SCATTERED_SHOWERS:
			case Weather.CONDITION_LIGHT_SHOWERS:
			case Weather.CONDITION_HEAVY_SHOWERS:
			case Weather.CONDITION_SCATTERED_SHOWERS:
			case Weather.CONDITION_CHANCE_OF_SHOWERS:
				self.icon = "\uf01a"; break;
			case Weather.CONDITION_THUNDERSTORMS:
			case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
			case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
				self.icon = "\uf03b"; break;
			case Weather.CONDITION_SNOW:
			case Weather.CONDITION_LIGHT_SNOW:
			case Weather.CONDITION_HEAVY_SNOW:
				self.icon = "\uf01b"; break;
			case Weather.CONDITION_FOG:
				self.icon = "\uf014"; break;
		}
*/
		var changed = !vText.equals(self.text);
		self.text = vText;
		return changed;
	}
}


class DynamicDataValues extends DataValues
{
	public function initialize(dataType as Number, icon as String?)
	{
		DataValues.initialize(dataType);
		self.icon = icon;
	}

	public function refresh() as Boolean
	{
		var vValue=null, vText=null;

		var info = ActivityMonitor.getInfo();
		var activityInfo, now;

		switch (self.dataType) {

			case DATA_TYPE_ACTIVE_MINUTES:
				vValue = info.activeMinutesWeek.total;
				self.max = info.activeMinutesWeekGoal;
				break;

			case DATA_TYPE_HEART_RATE:
				activityInfo = Activity.getActivityInfo();
				if (activityInfo.currentHeartRate != null) {
					vValue = activityInfo.currentHeartRate;
				} else {
					var sample = ActivityMonitor.getHeartRateHistory(1, /* newestFirst */ true).next();
					if ((sample != null) && (sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE)) {
						vValue = sample.heartRate;
					}
				}
				break;

			case DATA_TYPE_BODY_BATTERY:
				{
					var sample = Toybox.SensorHistory.getBodyBatteryHistory({"period"=>1,"order"=>SensorHistory.ORDER_NEWEST_FIRST}).next();
					if (sample != null) {
						vValue = sample.data.toNumber();
					}
				}
				break;

			case DATA_TYPE_STRESS_LEVEL:
				{
					var sample = Toybox.SensorHistory.getStressHistory({"period"=>1,"order"=>SensorHistory.ORDER_NEWEST_FIRST}).next();
					if (sample != null) {
						vValue = sample.data.toNumber();
						if ( vValue <= 25 ) {
							self.color = Graphics.COLOR_BLUE;
						}
						else if ( vValue <= 75 ) {
							self.color = 0xffb154 /*orange*/;
						}
						else {
							self.color = 0xff7716 /* dark orange*/;
						}
					}
				}
				break;

			case DATA_TYPE_ALTITUDE:
				{
					var sample = Toybox.SensorHistory.getElevationHistory({"period"=>1,"order"=>SensorHistory.ORDER_NEWEST_FIRST}).next();
					if (sample != null) {
						var altitude = sample.data;
						vValue = altitude;
						if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
							altitude = Math.round( 3.28084 * altitude );
						}
						vText = altitude.format("%.0f");
					}
				}
				break;

			case DATA_TYPE_CALORIES:
				vValue = info.calories;
				break;

			case DATA_TYPE_RESPIRATION:
				vValue = info.respirationRate;
				break;

			case DATA_TYPE_RECOVERY_TIME:
				if (info has :timeToRecovery) {
					vText = info.timeToRecovery.toString();
					vValue = info.timeToRecovery;
					self.max = 96;
					if ( info.timeToRecovery > 48 ) {
						self.color = BRIGHT_RED;
					}
					else if ( info.timeToRecovery > 36 ) {
						self.color = BRIGHT_ORANGE;
					}
					else if ( info.timeToRecovery > 24 ) {
						self.color = BRIGHT_YELLOW;
					}
					else {
						self.color = Graphics.COLOR_GREEN;
					}
				}
				break;

			case DATA_TYPE_DATE:
				now = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
				var dow = [
						"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
						][now.day_of_week - 1];
				//dow = dow.substring(0,2);

				vValue = dow + " " + now.day.toString();
				break;

			case DATA_TYPE_DAY_OF_MONTH:
				now = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
				vValue = now.day;
				break;

			case DATA_TYPE_SECONDS:
				vValue = Time.now().value() % 60;
				break;

			case DATA_TYPE_DEBUG1:
				{
					var wCond= Weather.getCurrentConditions();
					var seconds = Time.now().value() - wCond.observationTime.value();
					vValue = seconds;
					vText = Lang.format("$1$", [wCond.condition] );
				}
				break;
		}

		if (vText == null && vValue != null) {
			vText = vValue.toString();
		}

		var same = (vText!=null && vText.equals(self.text)) || (vText==null && self.text==null);

		self.value = vValue;
		self.text = vText;

		return !same;
	}

}
