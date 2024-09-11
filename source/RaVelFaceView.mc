import Toybox.Application;
import Toybox.Activity;
using Toybox.Complications;
using  Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
using Toybox.WatchUi;
using Toybox.Time.Gregorian;
using Toybox.SensorHistory;
using Toybox.Sensor;


var gTheme as Theme?;


enum {
	DISPLAY_TEXT 	= 1,
	DISPLAY_ICON 	= 2,
}

class RaVelFaceView extends WatchUi.WatchFace {
	private var mTime as ThickThinTime?;
	private var mGauges as Array<Gauge?> = [null, null];
	private var mMeters as Array<GoalMeter?> = [null, null];

	private var _topField = new DataField();
	private var _bottomLeftField = new DataField();
	private var _bottomLeftMaxX as Number = 0;
	private var _veryBottomField = new DataField();

	private var _iconsFont as WatchUi.Resource?;

	private var _secondsDisplayMode as Number = 0;

	private var _showAlarmIcon as Boolean = false;
	private var _notificationIconDataValues as DataValues?;

	private var _burnProtection as Boolean = false;
	private var _lastBurnOffsets as Array<Number> = [0,0];
	private var _lastBurnOffsetsChangedMinute = 0;

	private var _sleepTimeTracker as NullSleepTimeTracker or SleepTimeTracker;
	private var _sleepMode as Boolean = false;

	private var _hiPowerDataValuesToUpdate as Array<DataValues> = new [0];
	private var _loPowerDataValuesToUpdate as Array<DataValues> = new [0];
	private var _currentDataValuesToUpdate as Array<DataValues>;

	private var _skipOnUpdateOptimUntil as Number = 0;
	private var _lastEffectiveUpdateInThisState as Number = 0;

	function initialize() {
		WatchFace.initialize();
		$.gTheme = new Theme();

		var deviceSettings = System.getDeviceSettings();
		if ( deviceSettings has :requiresBurnInProtection && deviceSettings.requiresBurnInProtection) {
			self._sleepTimeTracker = new SleepTimeTracker();
			self._sleepMode = deviceSettings.doNotDisturb;
		}
		else {
			self._sleepTimeTracker = new NullSleepTimeTracker();
		}
		self._currentDataValuesToUpdate = self._hiPowerDataValuesToUpdate;
	}

	function onLayout(dc as Graphics.Dc) as Void {
		setLayout(Rez.Layouts.WatchFace(dc));

		var ravelOptions = {};
		if (Rez.JsonData has :ravelOptions) {
			ravelOptions = Application.loadResource(Rez.JsonData.ravelOptions) as Dictionary;
		}

		self._iconsFont = WatchUi.loadResource(Rez.Fonts.IconsFont);
		self.mTime = new ThickThinTime( ravelOptions["time"] as Dictionary, dc );

		if (self._burnProtection) {
			self.mTime.enterBurnProtection();
		}

		var opts = {};
		opts = ravelOptions["meters"] as Dictionary;

		mMeters[0] = new GoalMeter(:left, opts);
		mMeters[1] = new GoalMeter(:right, opts);

		if (opts["displayIcons"]) {
			mMeters[0].setIconFont( self._iconsFont );
			mMeters[1].setIconFont( self._iconsFont );
		}

		if ( ravelOptions.hasKey("gauges") )
		{
			opts = ravelOptions["gauges"] as Dictionary;
			var locX = opts["locX"];

			self.mGauges[0] = new Gauge(locX, opts);
			self.mGauges[1] = new Gauge(Utils.screenWidth - locX, opts);

			for (var i=0 ;i<2 ; i++) {
				self.mGauges[i].setIconFont( self._iconsFont );
				self.mGauges[i].setY( mTime.getTopFieldY() - 1 );
			}
		}

		var secondsBottom = ( self.mTime.getSecondsY() + self.mTime.getSecondsClipRectHeight() / 2 ) - Utils.halfScreenWidth;
		self._bottomLeftMaxX = Math.ceil( Utils.halfScreenWidth - Math.sqrt( Utils.halfScreenWidth * Utils.halfScreenWidth - secondsBottom * secondsBottom) ).toNumber();

		self.onSettingsChanged();
	}

	public function onSettingsChanged() as Void {
		self._sleepTimeTracker.onSettingsChanged();
		$.gTheme.onSettingsChanged();

		self.mMeters[0].dataValues = DataManager.getOrCreateDataValues( Application.Properties.getValue("LeftGoalType") );
		self.mMeters[1].dataValues = DataManager.getOrCreateDataValues( Application.Properties.getValue("RightGoalType") );

		if (self.mGauges[0] != null) {
			self.mGauges[0].onSettingsChanged( DataManager.getOrCreateDataValues( Application.Properties.getValue("LeftGaugeType") ) );
		}
		if (self.mGauges[1] != null) {
			self.mGauges[1].onSettingsChanged( DataManager.getOrCreateDataValues( Application.Properties.getValue("RightGaugeType") ) );
		}

		self._secondsDisplayMode = Application.Properties.getValue("SecondsDisplayMode");

		if (mTime != null) {
			mMeters[0].onSettingsChanged();
			mMeters[1].onSettingsChanged();

			mTime.onSettingsChanged();

			if ( self._secondsDisplayMode < 2 ) {
				self.mTime.setHideSeconds(self._secondsDisplayMode ? false : true);
			}
		}

		self._topField.onSettingsChanged( "TopDataType" );
		self._bottomLeftField.onSettingsChanged( "BottomLeftDataType" );
		self._veryBottomField.onSettingsChanged( "BottomDataType" );

		_showAlarmIcon = Application.Properties.getValue("ShowAlarmIcon");
		self._notificationIconDataValues = Application.Properties.getValue("ShowNotificationIcon") ? DataManager.getOrCreateDataValues( DATA_TYPE_NOTIFICATIONS ) : null;

		// build lists of dataValues to update in onUpdate
		var hiValues = {}, loValues = {};
		updateHiLoValuesToUpdate( self._notificationIconDataValues, hiValues, loValues );
		updateHiLoValuesToUpdate( self._topField.dataValues, hiValues, loValues );
		updateHiLoValuesToUpdate( self._bottomLeftField.dataValues, hiValues, loValues );
		updateHiLoValuesToUpdate( self._veryBottomField.dataValues, hiValues, loValues );
		if ( self.mGauges[0] != null ) {
			updateHiLoValuesToUpdate( self.mGauges[0].dataValues, hiValues, loValues );
			updateHiLoValuesToUpdate( self.mGauges[1].dataValues, hiValues, loValues );
		}
		updateHiLoValuesToUpdate( self.mMeters[0].dataValues, hiValues, null );
		updateHiLoValuesToUpdate( self.mMeters[1].dataValues, hiValues, null );
		self._hiPowerDataValuesToUpdate = hiValues.values() as Array<DataValues>;
		self._loPowerDataValuesToUpdate = loValues.values() as Array<DataValues>;
		self._currentDataValuesToUpdate = self._hiPowerDataValuesToUpdate;

		self._lastEffectiveUpdateInThisState = 0;
	}

	private function updateHiLoValuesToUpdate(dataValues as DataValues?, hiValues as Dictionary, loValues as Dictionary?) {
		if ( dataValues != null && dataValues.dataType != DATA_TYPE_OFF ) {
			hiValues[dataValues.dataType] = dataValues;
			if ( loValues != null && dataValues.canForceBurnProtection ) {
				loValues[dataValues.dataType] = dataValues;
			}
		}
	}


	function onUpdate(dc as Graphics.Dc) as Void {
		var now = Time.now().value();

		// same second update
		if (now == self._lastEffectiveUpdateInThisState ) {
			return;
		}

		if  ( !self._sleepTimeTracker.onUpdate(now) ) {
			if ( self._lastEffectiveUpdateInThisState != 1) {
				dc.clearClip();
				dc.setColor(Graphics.COLOR_TRANSPARENT, $.gTheme.BackgroundColor);
				dc.clear();
				self._lastEffectiveUpdateInThisState = 1;
			}
			return;
		}

		var burnProtection = self._burnProtection;

		if ( now > self._skipOnUpdateOptimUntil) {
			// update values and check for changes
			var fieldsChanged = false;
			for (var i=self._currentDataValuesToUpdate.size()-1; i>=0; i--) {
				fieldsChanged |= self._currentDataValuesToUpdate[i].refresh();
			}

			if ( !fieldsChanged ) {
				if ( now/60 == self._lastEffectiveUpdateInThisState/60 ) {
					// same minute update - only seconds changed
					if ( burnProtection ) {
						return;
					}
					self.onPartialUpdate(dc);
					return;
				}
			}

			self._lastEffectiveUpdateInThisState = now;

		} else {
			for (var i=self._currentDataValuesToUpdate.size()-1; i>=0; i--) {
				self._currentDataValuesToUpdate[i].refresh();
			}
		}

		// Clear any partial update clipping.
		dc.clearClip();

		var clockTime = System.getClockTime();

		if ( burnProtection && self._lastBurnOffsetsChangedMinute != clockTime.min) {
			self._lastBurnOffsets = [Math.rand() % 16 - 8, Math.rand() % 16 - 8];
			self._lastBurnOffsetsChangedMinute = clockTime.min;
			for (var i=0; i < 2; i++) {
				if (self.mGauges[i] != null) {
					self.mGauges[i].setXYOffset(self._lastBurnOffsets[0], self._lastBurnOffsets[1]);
				}
			}
		}

		var sleepMode = self._sleepMode;

		/* time update */
		if (self._secondsDisplayMode == 2) {
			self.mTime.setHideSeconds( sleepMode );
		}

		dc.setColor(Graphics.COLOR_TRANSPARENT, $.gTheme.BackgroundColor);
		dc.clear();

		/* meters */
		if ( !burnProtection && !sleepMode ) {
			for (var i=0; i < 2; i++) {
				self.mMeters[i].onUpdate( dc );
			}
		}

		mTime.draw(clockTime, dc);
		mTime.drawSeconds(clockTime.sec, dc, false);

		/* gauges */
		dc.setAntiAlias(true);
		for (var i=0;i<2 ; i++) {
			var gauge = self.mGauges[i];

			if ( gauge!=null && (!burnProtection || gauge.dataValues.canForceBurnProtection) ) {
				var displayType = burnProtection ? gauge.dataValues.burnProtection : DISPLAY_ICON | DISPLAY_TEXT;
				if ( displayType ) {
					gauge.onUpdate(dc, burnProtection);
				}
			}

		}

		/* top data above clock*/
		{
			var field = self._topField;
			var dataValues = field.dataValues;

			if ( dataValues.text != null && ( !burnProtection || dataValues.burnProtection > 0 )) {
				var font = Graphics.FONT_LARGE;
				var x = Utils.halfScreenWidth;
				var y = mTime.getTopFieldY();
				if ( burnProtection ) {
					x += self._lastBurnOffsets[0];
					y += self._lastBurnOffsets[1];
				}
				var textWidth = dc.getTextWidthInPixels(dataValues.text, font);

				if ( dataValues.icon != null ) {
					dc.setColor( ( (dataValues.color!=null) ? dataValues.color : field.iconColor ), Graphics.COLOR_TRANSPARENT);

					textWidth += dc.getTextWidthInPixels(dataValues.icon, self._iconsFont); // center on icon+text

					dc.drawText(
						x - textWidth/2,
						y, /* icon higher so that it has more space*/
						self._iconsFont, dataValues.icon, Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
				}

				dc.setColor( (dataValues.color!=null) ? dataValues.color : field.color, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x + textWidth/2,
					y,
					font, dataValues.text, Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
			}
		}

		/* bottom left below clock */
		{
			var field = self._bottomLeftField;
			var dataValues = field.dataValues;

			if ( dataValues.text != null && ( !burnProtection || dataValues.burnProtection > 0 )) {
				var font = Graphics.FONT_NUMBER_MEDIUM;

				var x;
				if (self.mTime.getHideSeconds()) {
					x = Utils.halfScreenWidth;
				}
				else {
					x = (self._bottomLeftMaxX + self.mTime.getSecondsX() ) / 2;
				}
				var y = self.mTime.getSecondsY();
				if ( burnProtection ) {
					x += self._lastBurnOffsets[0];
					y += self._lastBurnOffsets[1];
				}
				var textDims = dc.getTextDimensions(dataValues.text, font);

				if ( dataValues.icon != null && x-textDims[0]/2 > 10 ) {
					dc.setColor( dataValues.color!=null ? dataValues.color : field.iconColor, Graphics.COLOR_TRANSPARENT);

					var iconDims = dc.getTextDimensions(dataValues.icon, self._iconsFont);
					dc.drawText(
						x - textDims[0]/2 + 2,
						y - (textDims[1]*3)/10 + iconDims[1]/2, /* icon higher so that it has more space*/
						self._iconsFont, dataValues.icon, Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
				}

				dc.setColor( dataValues.color!=null ? dataValues.color : field.color, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x, y,
					font, dataValues.text, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			}
		}

		/* very bottom */`
		{
			var field = self._veryBottomField;
			var dataValues = field.dataValues;

			if ( dataValues.text != null && ( !burnProtection || dataValues.burnProtection > 0 )) {
				var font = Graphics.FONT_NUMBER_MILD;

				var textDims = dc.getTextDimensions(dataValues.text, font);

				var x = Utils.halfScreenWidth;
				var y = Utils.screenHeight - textDims[1]/2 + 1;

				if ( burnProtection ) {
					x += self._lastBurnOffsets[0];
					y -= self._lastBurnOffsets[1].abs();
				}

				if ( dataValues.icon != null ) {

					textDims[0] += dc.getTextWidthInPixels(dataValues.icon, self._iconsFont); // center on icon+text

					if ( !burnProtection || (dataValues.burnProtection & DISPLAY_ICON) != 0) {
						dc.setColor( dataValues.color!=null ? dataValues.color : field.iconColor, Graphics.COLOR_TRANSPARENT);
						dc.drawText(
							x - (textDims[0])/2, y,
							self._iconsFont, dataValues.icon, Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
					}
				}

				if ( !burnProtection || (dataValues.burnProtection & DISPLAY_TEXT) != 0) {
					dc.setColor( dataValues.color!=null ? dataValues.color : field.color, Graphics.COLOR_TRANSPARENT);
					dc.drawText(
						x + textDims[0]/2, y,
						font, dataValues.text, Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);
				}
			}
		}

		/* icons */
		if ( self._notificationIconDataValues!=null ) {
			var dataValues = self._notificationIconDataValues;

			if ( !burnProtection || (dataValues.burnProtection & DISPLAY_ICON != 0 ) ) {

				var x = Utils.halfScreenWidth + self._lastBurnOffsets[0];
				var y = 1 + self._lastBurnOffsets[1].abs();

				dc.setColor( dataValues.color!=null ? dataValues.color : $.gTheme.LowKeyColor, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x, y,
					self._iconsFont, dataValues.icon,
					self._showAlarmIcon ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_CENTER);
			}
		}

		if ( !burnProtection && self._showAlarmIcon ) {
			if ( System.getDeviceSettings().alarmCount ) {
				dc.setColor( $.gTheme.LowKeyColor, Graphics.COLOR_TRANSPARENT );
				dc.drawText(
					Utils.halfScreenWidth,
					1,
					self._iconsFont,
					ICON_ALARMS,
					self._notificationIconDataValues!=null ? Graphics.TEXT_JUSTIFY_RIGHT : Graphics.TEXT_JUSTIFY_CENTER);
			}
		}
	}

	function onPartialUpdate(dc as Graphics.Dc) as Void{
		//System.println("onPartialUpdate");
		mTime.drawSeconds(System.getClockTime().sec, dc, /* isPartialUpdate */ true);
	}

	function onShow() as Void {
		//TRACE("onShow");
		self._sleepTimeTracker.onShow();
		var deviceSettings = System.getDeviceSettings();
		if (deviceSettings has :requiresBurnInProtection && deviceSettings.requiresBurnInProtection) {
			self._sleepMode = deviceSettings.doNotDisturb;
		}
		self._lastEffectiveUpdateInThisState = 0;
		self._skipOnUpdateOptimUntil = Time.now().value() + 2;
	}

	function onHide() as Void {
		//TRACE("onHide");
		self._sleepTimeTracker.onHide();
	}

	function onExitSleep() as Void {
		//TRACE("onExitSleep");
		self._sleepTimeTracker.onExitSleep();
		self._lastEffectiveUpdateInThisState = 0;
		self._burnProtection = false;
		self._currentDataValuesToUpdate = self._hiPowerDataValuesToUpdate;
		for (var i=0; i < 2; i++) {
			if (self.mGauges[i] != null) {
				self.mGauges[i].setXYOffset(0,0);
			}
		}
		self.mTime.exitBurnProtection( self._sleepMode );
	}

	function onEnterSleep() as Void {
		//TRACE("onEnterSleep");
		self._sleepTimeTracker.onEnterSleep();
		self._lastEffectiveUpdateInThisState = 0;
		self._skipOnUpdateOptimUntil = 0;
		if (System.getDeviceSettings().requiresBurnInProtection) {
			self._burnProtection = true;
			self._lastBurnOffsetsChangedMinute = System.getClockTime().min;
			self._lastBurnOffsets = [0,0];
			self._currentDataValuesToUpdate = self._loPowerDataValuesToUpdate;
			if (self.mTime != null) {
				self.mTime.enterBurnProtection();
			}
		}
	}

	public function onBackgroundSleepTime() as Void {
		self._sleepTimeTracker.onBackgroundSleepTime();
	}

	public function onBackgroundWakeTime() as Void {
		self._sleepTimeTracker.onBackgroundWakeTime();
	}

	public function onPress(x as Number, y as Number) as Boolean
	{
		self._sleepTimeTracker.unfreezeMorningAOD();

		if ( y > (Utils.screenHeight - mMeters[0].getHeight() ) / 2 && y < (Utils.screenHeight + mMeters[0].getHeight() ) / 2 ) {
			var distanceToCenter = (x - Utils.halfScreenWidth) * (x - Utils.halfScreenWidth) + (y - Utils.halfScreenHeight) * (y - Utils.halfScreenHeight);
			var usedStroke =  mMeters[0].getStroke();
			if ( y > (Utils.screenHeight - mMeters[0].getHeight() ) / 2 + mMeters[0].getHeight()/4 && y < (Utils.screenHeight + mMeters[0].getHeight() ) / 2  - mMeters[0].getHeight()/4) {
				usedStroke *= 4;
			}

			if ( distanceToCenter >= (Utils.halfScreenWidth - usedStroke) * (Utils.halfScreenWidth - usedStroke) )  {
				var dataType = x < Utils.halfScreenWidth ? mMeters[0].dataValues.dataType : mMeters[1].dataValues.dataType;
				return self.navigateToDataType( dataType );
			}
		}

		var dc = Graphics.createBufferedBitmap( {:width => 20, :height => 20 }).get().getDc();

		/* top icons*/
		if (self._notificationIconDataValues != null && self._notificationIconDataValues.icon != null)	{
			var textDims = dc.getTextDimensions(self._notificationIconDataValues.icon, self._iconsFont);
			if (y <= 1+textDims[1] && x >= Utils.halfScreenWidth - textDims[0]/2 && x <= Utils.halfScreenWidth + textDims[0]) {
				return self.navigateToDataType( self._notificationIconDataValues.dataType );
			}
		}

		for (var i=0; i<2; i++) {
			if (self.mGauges[i] != null) {
				var distanceToCenter = (x - self.mGauges[i].locX) * (x - self.mGauges[i].locX) + (y - self.mGauges[i].locY) * (y - self.mGauges[i].locY);
				if (distanceToCenter <= self.mGauges[i].getRadius() * self.mGauges[i].getRadius() )	{
					return self.navigateToDataType( self.mGauges[i].dataValues.dataType );
				}
			}
		}

		/* top data above clock*/
		var dataValues = self._topField.dataValues;
		if ( dataValues.text != null ) {

				var textDims = dc.getTextDimensions(dataValues.text, Graphics.FONT_LARGE);

				if ( dataValues.icon != null ) {
					textDims[0] += dc.getTextWidthInPixels(dataValues.icon, self._iconsFont); // center on icon+text
				}

				if (x >= Utils.halfScreenWidth - textDims[0]/2 && x <= Utils.halfScreenWidth + textDims[0]/2 && y >= mTime.getTopFieldY() - textDims[1]/2 && y <= mTime.getTopFieldY() + textDims[1]/2 ) {
					return self.navigateToDataType( dataValues.dataType );
				}
		}

		/* very bottom */`
		dataValues = self._veryBottomField.dataValues;
		if ( dataValues.text != null) {
			var textDims = dc.getTextDimensions(dataValues.text, Graphics.FONT_NUMBER_MILD);
			var midX = Utils.halfScreenWidth;
			var midY = Utils.screenHeight- textDims[1]/2 + 1;

			if ( dataValues.icon != null ) {
				textDims[0] += dc.getTextWidthInPixels(dataValues.icon, self._iconsFont); // center on icon+text
			}

			if (x >= midX - textDims[0]/2 && x <= midX + textDims[0]/2 && y >= midY - textDims[1]/2 && y <= midY + textDims[1]/2) {
				return self.navigateToDataType( dataValues.dataType );
			}
		}

		/* bottom left below clock */
		dataValues = self._bottomLeftField.dataValues;
		if ( dataValues.text != null ) {
				var midX;
				if (self.mTime.getHideSeconds()) {
					midX = Utils.halfScreenWidth;
				}
				else {
					midX = (self._bottomLeftMaxX + self.mTime.getSecondsX() ) / 2;
				}
				var midY = self.mTime.getSecondsY();
				var textDims = dc.getTextDimensions(dataValues.text, Graphics.FONT_NUMBER_MEDIUM);

				if (x >= midX - textDims[0]/2 && x <= midX + textDims[0]/2 && y >= midY - textDims[1]/2 && y <= midY + textDims[1]/2 ) {
					return self.navigateToDataType( dataValues.dataType );
				}
		}

		self._sleepTimeTracker.unfreezeEveningAOD();

		return false;
	}

	private function navigateToDataType( dataType as Number) as Boolean
	{
		if (dataType < 50 ) {
			var complicationType = dataType as Complications.Type;
			var thisComplication = new Complications.Id(complicationType);
			if (thisComplication != null) {
				Complications.exitTo(thisComplication);
				return true;
			}
		}
		return false;
	}

}
