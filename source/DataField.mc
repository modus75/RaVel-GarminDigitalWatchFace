import Toybox.Lang;

class DataField
{
	var dataValues as DataValues?;
	var color as Number?, iconColor as Number?;

	public function onSettingsChanged(name as String) as Void
	{
		self.dataValues = DataManager.getOrCreateDataValues( Application.Properties.getValue( name ) );

		self.color = $.gTheme.ForeColor;
		self.iconColor = $.gTheme.IconColor;

		var useConnectColors = Application.Properties.getValue("UseConnectColors");

		if ( useConnectColors > 0 && DataManager.getDataTypeColor( self.dataValues.dataType ) != null ) {
			if ( useConnectColors > 1 ) {
				self.color = DataManager.getDataTypeColor( self.dataValues.dataType );
			}
			self.iconColor = Utils.dimColor( DataManager.getDataTypeColor( self.dataValues.dataType ), 0.8);
		}
	}

}