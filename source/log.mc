
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;


(:background :debug)
function TRACE(obj) {
	var currentTime = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

	var timestamp = Lang.format("$1$-$2$-$3$ $4$:$5$:$6$", [
		currentTime.year.format("%04u"),
		currentTime.month.format("%02u"),
		currentTime.day.format("%02u"),
		currentTime.hour.format("%02u"),
		currentTime.min.format("%02u"),
		currentTime.sec.format("%02u")
	]);

	System.println( Lang.format("$1$ $2$", [timestamp, obj]) );
}

(:background :release)
function TRACE(obj) {
}
