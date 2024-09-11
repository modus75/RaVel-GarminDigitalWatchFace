import Toybox.Lang;

enum {
	BRIGHT_PURPLE = 0xff55ff,
	BRIGHT_RED    = 0xff3333,
	BRIGHT_YELLOW = 0xffff00 /* Sys 0xFFAA00 */,
	BRIGHT_ORANGE = 0xff8822 /* Sys 0xFF5500; gold=FFD700 orange=FFA500 darkorange=FF8C00 */
}

class Theme
{
	public var ForeColor;
	public var BackgroundColor;
	public var LowKeyColor;
	public var WarnColor;
	public var ErrorColor;
	public var IconColor;
	public var EmptyMeterColor;
	public var FullMeterColor;
	public var HoursColor;
	public var MinutesColor;

	private var _lightFactor = 1.0;
	private var _lightFactor2 = 1.0;


	function setLightFactor( factor ) {
		self._lightFactor = factor;
		self.onSettingsChanged();
	}

	function setLightFactor2( factor ) {
		self._lightFactor2 = factor;
		self.onSettingsChanged();
	}

	function onSettingsChanged()
	{
		var theme = Application.Properties.getValue("Theme");
		var colors = [];

		switch (theme) {
			case 1: //light
				colors = [
					Graphics.COLOR_WHITE, Graphics.COLOR_BLACK,
					Graphics.COLOR_LT_GRAY, Graphics.COLOR_ORANGE, Graphics.COLOR_RED, Graphics.COLOR_LT_GRAY,
					Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLUE,
					Graphics.COLOR_BLACK, Graphics.COLOR_BLACK
				];
				break;
			default: // dark
				colors = [
					Graphics.COLOR_BLACK, Graphics.COLOR_WHITE,
					Graphics.COLOR_DK_GRAY, Graphics.COLOR_ORANGE, Graphics.COLOR_RED, Graphics.COLOR_DK_GRAY,
					Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLUE,
					Graphics.COLOR_WHITE, Graphics.COLOR_WHITE,
				];
				if (System.getDeviceSettings().requiresBurnInProtection){
					colors[5] = 0x808080;
				}
				break;
		}
		if (theme == 2) {
			dimColors(colors, 0.8);
		}
		else if (theme == 3) {
			dimColors(colors, 0.7);
		}
		else if (theme == 4) {
			dimColors(colors, 0.6);
		}
		else if (theme == 5) {
			dimColors(colors, 0.5);
		}
		else if (theme == 6) {
			dimColors(colors, 0.4);
		}

		if (self._lightFactor * self._lightFactor2 < 1.0 ) {
			dimColors(colors, self._lightFactor * self._lightFactor2 );
		}

		self.BackgroundColor = colors[0];
		self.ForeColor = colors[1];

		self.LowKeyColor = colors[2];
		self.WarnColor = colors[3];
		self.ErrorColor = colors[4];
		self.IconColor = colors[5];

		self.EmptyMeterColor = colors[6];
		self.FullMeterColor = colors[7];

		self.HoursColor = colors[8];
		self.MinutesColor = colors[9];
	}

	private function dimColors( colors as Array<Number>, factor)	{
		for (var i = 0; i < colors.size(); ++i) {
			var color = colors[i];
			var r = Math.round( factor * ( (color >> 16) & 0xff) ).toNumber();
			var g = Math.round( factor * ( (color >> 8) & 0xff) ).toNumber();
			var b = Math.round( factor * ( color & 0xff) ).toNumber();
			colors[i] = (r << 16)  + (g << 8) + b;
		}

	}
}