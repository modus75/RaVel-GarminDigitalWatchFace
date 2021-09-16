import Toybox.Application;
import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
using Toybox.Time.Gregorian;

var gThemeColour;
var gBackgroundColour;
var gLowVisibilityColor;
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


class RaVelFaceView extends WatchUi.WatchFace {

	private var mIsSleeping = false;
	private var mTime;
	private var mDrawables = {};
	
	private var mTopDataType;
	
	private var mBottomLeftDataType;
	private var mBottomRightDataType;
	
	private var mIconsFont;
	
	private var mSecondsDisplayMode;
	
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

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    	System.println("onShow");
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
    	//System.println("onUpdate");
    	
		// Clear any partial update clipping.
		if (dc has :clearClip) {
			dc.clearClip();
		}
	
		updateSecondsVisibility();
		updateMeters();
		
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        
        var values;
        
        /* top */
        {
        	values = self.getValuesForDataType( mTopDataType );
			
			var font = Graphics.FONT_MEDIUM;
			var x = dc.getWidth()/2;
			var y = mTime.getTopFieldY();
			var textDims = dc.getTextDimensions(values[:text], font);
			
        	if ( values[:icon] != null ) {
	        	dc.setColor( ( (values[:iconColor]!=null) ? values[:iconColor] : gIconColor ), Graphics.COLOR_TRANSPARENT);

	        	var iconDims = dc.getTextDimensions(values[:icon], mIconsFont);
	        	textDims[0] += iconDims[0]; // center on icon+text

				dc.drawText(
					x - textDims[0]/2,
					y, /* icon higher so that it has more space*/
					mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
        	}

	    	dc.setColor( gThemeColour , Graphics.COLOR_TRANSPARENT);
	    	dc.drawText(
	    		x + textDims[0] /2,
	    		y,
	    		font, values[:text], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
		}
        
        /* bottom left*/
        values = self.getValuesForDataType(mBottomLeftDataType);

        if ( values[:isValid] ) {
        	var font = Graphics.FONT_NUMBER_MEDIUM;
        	
        	var x = mTime.getLeftFieldAdjustX() + mTime.getSecondsX() / 2;
        	var y = mTime.getSecondsY();
        	var textDims = dc.getTextDimensions(values[:text], font);
        	
        	if ( values[:icon] != null && x-textDims[0]/2 > 10 ) {
	        	dc.setColor( ( (values[:iconColor]!=null) ? values[:iconColor] : gIconColor ), Graphics.COLOR_TRANSPARENT);
	        	
	        	var iconDims = dc.getTextDimensions(values[:icon], mIconsFont);
				var asc = Graphics.getFontAscent(font);
				var desc = Graphics.getFontDescent(font);
				dc.drawText(
					x - textDims[0]/2,
					y - (textDims[1]*3)/10 + iconDims[1]/2, /* icon higher so that it has more space*/
					mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
        	}

        	dc.setColor( ( (values[:color]!=null) ? values[:color] : gThemeColour ), Graphics.COLOR_TRANSPARENT);
        	dc.drawText(
        		x, 
        		y,
        		font, values[:text], Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

        }


		/* bottom*/
        values = self.getValuesForDataType(mBottomRightDataType);

        if ( values[:isValid] ) {
        	var font = Graphics.FONT_NUMBER_MILD;

        	var textDims = dc.getTextDimensions(values[:text], font);

        	var x = dc.getWidth()/2;
        	var y = dc.getHeight() - textDims[1]/2 + 1;
        	
        	if ( values[:icon] != null ) {
        	
	        	var iconDims = dc.getTextDimensions(values[:icon], mIconsFont);
	        	textDims[0] += iconDims[0]; // center on icon+text
        		
	        	dc.setColor( ( (values[:iconColor]!=null) ? values[:iconColor] : gIconColor ), Graphics.COLOR_TRANSPARENT);	
				dc.drawText(
					x + (textDims[0])/2,
					y,
					mIconsFont, values[:icon], Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
        	} 
    
           	dc.setColor( ( (values[:color]!=null) ? values[:color] : gThemeColour ), Graphics.COLOR_TRANSPARENT);
        	dc.drawText(
        		x - textDims[0]/2, 
        		y, 
        		font, values[:text], Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
        }

    }


	function onPartialUpdate(dc as Dc) as Void{
		//System.println("onPartialUpdate");
		mTime.drawSeconds(dc, /* isPartialUpdate */ true);
	}
	
    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    	System.println("onHide");
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    	System.println("onExitSleep");
    	mIsSleeping = false;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    	System.println("onEnterSleep");
    	mIsSleeping = true;
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
        gBackgroundColour = colors[0];
        gThemeColour = colors[1];
        
        gLowVisibilityColor = colors[2];
        gWarnColor = colors[3];
        gIconColor = colors[4];
        
        gEmptyMeterColour = colors[5];
        gFullMeterColour = colors[6];
        
        if (colors.size() > 7) {
        	gHoursColour = colors[7];
        	gMinutesColour = colors[8];
        }
        else {
        	gHoursColour = gThemeColour;
        	gMinutesColour = gThemeColour;
        }

       
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
				values[:icon] = "0";
				break;
			case DATA_TYPE_ACTIVE_MINUTES:
				if (info has :activeMinutesWeek) {
					values[:value] = info.activeMinutesWeek.total;
				}
				values[:icon] = "2";
				break;
			case DATA_TYPE_FLOORS_CLIMBED:
				if (info has :floorsClimbed) {
					values[:value] = info.floorsClimbed;
				}
				values[:icon] = "1";
				break;
			case DATA_TYPE_NOTIFICATIONS:
				values[:value] = settings.notificationCount;
				if (settings.phoneConnected) {
					if (settings.notificationCount == 0) {
						values[:color] = gLowVisibilityColor;
					}
					values[:icon] = "5";
				}
				else {
					values[:text] = "-";
					values[:color] = gWarnColor;
					values[:iconColor] = gWarnColor;
					values[:icon] = "8";
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
				values[:icon] = "3";
				break;
			case DATA_TYPE_BATTERY:
				values[:value] = Math.floor(System.getSystemStats().battery);
				values[:text] = values[:value].format("%.0f");
				values[:icon] = "9";
				if (values[:value] < 25) {
					values[:color] = gWarnColor;
					values[:icon] = "4";
					values[:iconColor] = gWarnColor;
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
	
	
	function getValuesForGoalType(type) {
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
		var leftType = Application.getApp().getProperty("LeftGoalType");
		var leftValues = getValuesForGoalType(leftType);
		mDrawables[:LeftGoalMeter].setValues(leftValues[:current], leftValues[:max], /* isOff */ leftType == GOAL_TYPE_OFF);

		var rightType = Application.getApp().getProperty("RightGoalType");
		var rightValues = getValuesForGoalType(rightType);
		mDrawables[:RightGoalMeter].setValues(rightValues[:current], rightValues[:max], /* isOff */ rightType == GOAL_TYPE_OFF);

	}
	
	private function updateSecondsVisibility() {
		var show = true;
		if (mSecondsDisplayMode == 2 && System.getDeviceSettings().doNotDisturb) {
			show = false;
		}
		else if (mSecondsDisplayMode == 0) {
			show = false;
		}
		
		if ( mTime != null) {
			if (mTime.setHideSeconds(!show)) {
				WatchUi.requestUpdate();
			}
		}
	}
	
}
