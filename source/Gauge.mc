
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi;
using Toybox.System;

enum {
	GAUGE_DISPLAY_OFF,
	GAUGE_DISPLAY_ICON,
	GAUGE_DISPLAY_ALL,
}


class Gauge extends WatchUi.Drawable 
{
	const GAUGE_FULL_DEG = 360;
	const GAUGE_START_DEG = 90;

	private var _radius;
	private var _stroke;

	private var _iconFont;

	private var _degrees = 0;
	private var _displayType = GAUGE_DISPLAY_OFF;
	private var _values;

	private var _offsetX = 0;
	private var _offsetY = 0;

	function initialize(params) {
		Drawable.initialize(params);

		self._radius = params[:radius];
		self._stroke = params[:stroke];
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

	function setValues(values, displayType) {
		self._displayType = displayType;
		if (self._displayType != GAUGE_DISPLAY_OFF) {
			if (values[:max] != null) {
				var val = values[:value] * 1.0 / values[:max];
				if (val<0) { val = 0;}
				else if (val >= 0.99999) { val = 1;}
				self._degrees = GAUGE_FULL_DEG * val;
			}
			else {
				self._displayType = GAUGE_DISPLAY_ICON;
			}
			self._values = values;
		}
	}

	function draw(dc) {
		if (self._displayType == GAUGE_DISPLAY_OFF) {
			return;
		}

		var x = self.locX + self._offsetX;
		var y = self.locY + self._offsetY;

		if ( self._values[:icon] != null ) {
			dc.setColor( self._values[:valueColor]!=null ? self._values[:valueColor] : $.gTheme.IconColor, Graphics.COLOR_TRANSPARENT);

			dc.drawText(
				x, y, 
				self._iconFont, self._values[:icon], Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}


		if (self._displayType == GAUGE_DISPLAY_ALL) {
			dc.setColor($.gTheme.LowKeyColor, Graphics.COLOR_TRANSPARENT);

			dc.setPenWidth( self._stroke );
			dc.drawArc( 
				x, y, 
				self._radius, 
				Graphics.ARC_CLOCKWISE , GAUGE_START_DEG, GAUGE_START_DEG - GAUGE_FULL_DEG
				);


			if ( self._degrees > 0) {
				dc.setColor( self._values[:valueColor]!=null ? self._values[:valueColor] : $.gTheme.FullMeterColor, Graphics.COLOR_TRANSPARENT);
				dc.setPenWidth( self._stroke );
				dc.drawArc( 
					x, y, 
					self._radius, 
					Graphics.ARC_CLOCKWISE , GAUGE_START_DEG, GAUGE_START_DEG - self._degrees
					);
			}
		}
	}
}