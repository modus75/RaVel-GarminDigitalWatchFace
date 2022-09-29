

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
		var theme = getApp().getProperty("Theme");
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
					Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLUE
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

		if (colors.size() > 8) {
			self.HoursColor = colors[8];
			self.MinutesColor = colors[9];
		}
		else {
			self.HoursColor = self.ForeColor;
			self.MinutesColor = self.ForeColor;
		}
    }

	private function dimColors( colors, factor)	{
		for (var i = 0; i < colors.size(); ++i) {
			var color = colors[i];
			var r = Math.round( factor * ( (color >> 16) & 0xff) ).toNumber();
			var g = Math.round( factor * ( (color >> 8) & 0xff) ).toNumber();
			var b = Math.round( factor * ( color & 0xff) ).toNumber();
			colors[i] = (r << 16)  + (g << 8) + b;
		}

	}
}