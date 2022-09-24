
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
using Toybox.WatchUi;
using Toybox.System;

class Gauge extends WatchUi.Drawable 
{
	private var _radius;
	private var _stroke;

	private var _iconFont;

	private var _degrees = 0;
	private var _off = true;
	private var _values;

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

	function setIconFont(iconFont) {
		self._iconFont = iconFont;
	}

	function setValues(values, isOff) {
		self._off = isOff;
		if (!isOff) {
			var val = values[:value] * 1.0 / values[:max];
			if (val<0) { val = 0;}
			else if (val >= 0.99999) { val = 1;}
			self._degrees = 270 * val;
			self._values = values;
		}
	}

	function draw(dc) {
		if (self._off) {
			return;
		}

		if ( self._values[:icon] != null ) {
			dc.setColor( self._values[:iconColor]!=null ? self._values[:iconColor] : $.gTheme.IconColor, Graphics.COLOR_TRANSPARENT);

			dc.drawText(
				self.locX,
				self.locY, 
				self._iconFont, self._values[:icon], Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}


		dc.setColor($.gTheme.LowKeyColor, Graphics.COLOR_TRANSPARENT);

		dc.setPenWidth( self._stroke );
		dc.drawArc( 
			self.locX,
			self.locY, 
			self._radius, 
			Graphics.ARC_CLOCKWISE , 225, -45
			);


		if ( self._degrees > 0) {
			dc.setColor( self._values[:color]!=null ? self._values[:color] : $.gTheme.FullMeterColor, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth( self._stroke );
			dc.drawArc( 
				self.locX,
				self.locY, 
				self._radius, 
				Graphics.ARC_CLOCKWISE , 225, 225 - self._degrees
				);
		}
	}
}