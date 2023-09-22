import Toybox.Lang;
using Toybox.Math;
using Toybox.System;

module Utils {

	var screenWidth = System.getDeviceSettings().screenWidth;
	var screenHeight = System.getDeviceSettings().screenHeight;

	var halfScreenWidth as Number = System.getDeviceSettings().screenWidth / 2;
	var halfScreenHeight as Number = System.getDeviceSettings().screenHeight / 2;

	function dimColor( color, factor)	{
			var r = Math.round( factor * ( (color >> 16) & 0xff) ).toNumber();
			var g = Math.round( factor * ( (color >> 8) & 0xff) ).toNumber();
			var b = Math.round( factor * ( color & 0xff) ).toNumber();
			return (r << 16)  + (g << 8) + b;
		}

}