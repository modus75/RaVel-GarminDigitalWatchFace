

class Theme
{
    public var ForeColor;
    public var BackgroundColor;
    public var LowKeyColor;
    public var WarnColor;
    public var IconColor;
    public var EmptyMeterColor;
    public var FullMeterColor;
    public var HoursColor;
    public var MinutesColor;

    function onSettingsChanged()
    {
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
				if (System.getDeviceSettings().requiresBurnInProtection){
					colors[4] = 0x808080;
				}
				break;
		}
		self.BackgroundColor = colors[0];
		self.ForeColor = colors[1];

		self.LowKeyColor = colors[2];
		self.WarnColor = colors[3];
		self.IconColor = colors[4];

		self.EmptyMeterColor = colors[5];
		self.FullMeterColor = colors[6];

		if (colors.size() > 7) {
			self.HoursColor = colors[7];
			self.MinutesColor = colors[8];
		}
		else {
			self.HoursColor = self.ForeColor;
			self.MinutesColor = self.ForeColor;
		}
    }
}