
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
	private var _arcColor as Number = 0;

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

	function onSettingsChanged(dataValues as DataValues) {
		self.dataValues = dataValues;
		self._arcColor = $.gTheme.FullMeterColor;
		if ( Application.Properties.getValue("UseConnectColors") && DataManager.getDataTypeColor( self.dataValues.dataType ) != null ) {
			self._arcColor = DataManager.getDataTypeColor( self.dataValues.dataType );
		}
	}

	function onUpdate(dc as Graphics.Dc, burnProtection as Boolean) {
		//DISPLAY_TEXT means arc; DISPLAY_ICON means icon or text

		var text = self.dataValues.text;
		var drawArc, drawIcon, drawText;
		if ( burnProtection ) {
			drawArc = false;
			drawIcon = self.dataValues.burnProtection & DISPLAY_ICON != 0;
			drawText = !drawIcon && self.dataValues.burnProtection & DISPLAY_TEXT != 0;
		}
		else {
			drawArc = self.dataValues.max != null;
			if ( self.dataValues.icon != null ) {
				if ( text != null ) {
					drawIcon = text.length()>3 || (drawArc && text.length()>2);
				}
				else {
					drawIcon = true;
				}
				drawText = !drawIcon;
			}
			else {
				drawIcon = false;
				drawText = text != null;
			}
		}

		var x = self.locX + self._offsetX;
		var y = self.locY + self._offsetY;

		if ( drawIcon ) {
			dc.setColor( self.dataValues.color!=null ? self.dataValues.color : $.gTheme.IconColor, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x, y,
				self._iconFont, self.dataValues.icon, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}
		else if ( drawText ) {
			var font;
			if ( drawArc ) {
				font = text.length() <= 3 ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
			}
			else {
				font = text.length() <= 2 ? Graphics.FONT_LARGE : ( text.length() <= 5 ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL);
			}

			dc.setColor( self.dataValues.color!=null ? self.dataValues.color : $.gTheme.ForeColor, Graphics.COLOR_TRANSPARENT);
			dc.drawText(
				x, y,
				font, self.dataValues.text, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}

		if ( drawArc ) {

			var val = self.dataValues.value * 1.0 / self.dataValues.max;
			if (val<0) { val = 0;}
			else if (val >= 0.99999) { val = 1;}
			var degrees = GAUGE_FULL_DEG * val;

			dc.setColor($.gTheme.LowKeyColor, Graphics.COLOR_TRANSPARENT);

			dc.setPenWidth( self._stroke );
			dc.drawArc(
				x, y,
				self._radius,
				Graphics.ARC_CLOCKWISE , GAUGE_START_DEG, GAUGE_START_DEG - GAUGE_FULL_DEG
				);


			if ( degrees > 0) {
				dc.setColor( self.dataValues.color!=null ? self.dataValues.color : self._arcColor, Graphics.COLOR_TRANSPARENT);
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