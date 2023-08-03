
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi;
using Toybox.System;


class Gauge
{
	const GAUGE_FULL_DEG = 360;
	const GAUGE_START_DEG = 90;

	public var locX as Number = 0;
	public var locY as Number = 0;

	private var _radius;
	private var _stroke;

	private var _iconFont;

	public var dataValues as DataValues?;

	private var _offsetX = 0;
	private var _offsetY = 0;

	function initialize(locX as Number, params as Dictionary) {
		self.locX = locX;
		self._radius = params["radius"];
		self._stroke = params["stroke"];
	}

	function getRadius() {
		return self._radius;
	}

	function setY(y) {
		self.locY = y;
	}

	function setXYOffset(x, y) {
		self._offsetX = x;
		self._offsetY = y;
	}

	function setIconFont(iconFont) {
		self._iconFont = iconFont;
	}

	function onUpdate(dc as Graphics.Dc, displayType as Number) {
		//DISPLAY_TEXT means arc; DISPLAY_ICON means icon or text
		var degrees = null;

		if (self.dataValues.max != null && (displayType & DISPLAY_TEXT) == DISPLAY_TEXT ) {
			var val = self.dataValues.value * 1.0 / self.dataValues.max;
			if (val<0) { val = 0;}
			else if (val >= 0.99999) { val = 1;}
			degrees = GAUGE_FULL_DEG * val;
		}
		else {
			displayType = DISPLAY_ICON;
		}

		var x = self.locX + self._offsetX;
		var y = self.locY + self._offsetY;

		if ( (displayType & DISPLAY_ICON) ) {

			if ( self.dataValues.icon != null ) {
				dc.setColor( self.dataValues.color!=null ? self.dataValues.color : $.gTheme.IconColor, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x, y,
					self._iconFont, self.dataValues.icon, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			}
			else if ( self.dataValues.text != null ) {
				dc.setColor( self.dataValues.color!=null ? self.dataValues.color : $.gTheme.ForeColor, Graphics.COLOR_TRANSPARENT);
				dc.drawText(
					x, y,
					Graphics.FONT_TINY, self.dataValues.text, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			}

		}

		if ( degrees != null ) {
			dc.setColor($.gTheme.LowKeyColor, Graphics.COLOR_TRANSPARENT);

			dc.setPenWidth( self._stroke );
			dc.drawArc(
				x, y,
				self._radius,
				Graphics.ARC_CLOCKWISE , GAUGE_START_DEG, GAUGE_START_DEG - GAUGE_FULL_DEG
				);


			if ( degrees > 0) {
				dc.setColor( self.dataValues.color!=null ? self.dataValues.color : $.gTheme.FullMeterColor, Graphics.COLOR_TRANSPARENT);
				dc.setPenWidth( self._stroke );
				dc.drawArc(
					x, y,
					self._radius,
					Graphics.ARC_CLOCKWISE , GAUGE_START_DEG, GAUGE_START_DEG - degrees
					);
			}
		}
	}
}