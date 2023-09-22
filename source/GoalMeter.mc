import Toybox.Lang;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
import Toybox.Application;
using Toybox.Graphics;

// const MIN_WHOLE_SEGMENT_HEIGHT = 5;


// Buffered drawing behaviour:
// - On initialisation: calculate clip width (non-trivial for arc shape); create buffers for empty and filled segments.
// - On setting current/max values: if max changes, re-calculate segment layout and set dirty buffer flag; if current changes, re-
//   calculate fill height.
// - On draw: if buffers are dirty, redraw them and clear flag; clip appropriate portion of each buffer to screen. Each buffer
//   contains all segments in appropriate colour, with separators. Maximum of 2 draws to screen on each draw() cycle.
class GoalMeter {

	private var _goalMeterStyle;
	private var mSide; // :left, :right.
	private var mStroke as Number; // Stroke width.
	private var mWidth; // Clip width of meter.
	private var mHeight as Number; // Clip height of meter.
	private var mSeparator; // Current stroke width of separator bars.
	private var mLayoutSeparator; // Stroke with of separator bars specified in layout.

	private var mSegments as Array<Number>?; // Array of segment heights, in pixels, excluding separators.
	private var mFillHeight as Number = 0; // Total height of filled segments, in pixels, including separators.

	private var mFilledBuffer; // Bitmap buffer containing all full segments;
	private var mEmptyBuffer; // Bitmap buffer containing all empty segments;

	private var mBuffersNeedRecreate as Number = 2; // 2=all, 1=only fill - Buffers need to be recreated on next draw() cycle.
	private var mBuffersNeedRedraw as Number = 2; // 2=all, 1=only fill - Buffers need to be redrawn on next draw() cycle.

	private var _currentValue as Numeric?;
	private var _currentMax as Numeric?;
	public var dataValues as DataValues?;
	private var _iconFont;
	private var _iconColor = 0;
	private var _defaultFullMeterColor = 0;
	private var _fullMeterColor = 0;

	// private enum /* GOAL_METER_STYLES */ {
	// 	ALL_SEGMENTS,
	// 	ALL_SEGMENTS_MERGED,
	// 	HIDDEN,
	// 	FILLED_SEGMENTS,
	// 	FILLED_SEGMENTS_MERGED
	// }

	function initialize(side, params as Dictionary) {

		self.mSide = side;
		mStroke = params["stroke"];
		mHeight = params["height"];
		mLayoutSeparator = params["separator"];

		mWidth = computeWidth();
	}

	private function computeWidth() {
		var width;

		var innerRadius;

		innerRadius = Utils.halfScreenWidth - mStroke;
		width = Utils.halfScreenWidth - Math.sqrt(Math.pow(innerRadius, 2) - Math.pow(mHeight / 2, 2));
		width = Math.ceil(width).toNumber(); // Round up to cover partial pixels.

		return width;
	}

	function getHeight() as Number {
		return self.mHeight;
	}

	function getStroke() as Number {
		return self.mStroke;
	}

	function setIconFont(iconFont) {
		self._iconFont = iconFont;
	}

	function onSettingsChanged() {
		self.mBuffersNeedRecreate = 2;

		self._defaultFullMeterColor = $.gTheme.FullMeterColor;
		self._iconColor = $.gTheme.IconColor;
		if ( Application.Properties.getValue("UseConnectColors") && self.dataValues != null && DataManager.getDataTypeColor( self.dataValues.dataType ) != null ) {
			self._defaultFullMeterColor = DataManager.getDataTypeColor( self.dataValues.dataType );
			self._iconColor = Utils.dimColor( self._defaultFullMeterColor, 0.75);
		}

		// #18 Only read separator width from layout if multi segment style is selected.
		// #62 Or if filled segment style is selected.
		self._goalMeterStyle = Application.Properties.getValue("GoalMeterStyle");
		if ((self._goalMeterStyle == 0 /* ALL_SEGMENTS */) || (self._goalMeterStyle == 3 /* FILLED_SEGMENTS */)) {

			// Force recalculation of mSegments in setValues() if mSeparator is about to change.
			if (mSeparator != mLayoutSeparator) {
				self._currentMax = null;
			}

			mSeparator = mLayoutSeparator;

		} else {

			// Force recalculation of mSegments in setValues() if mSeparator is about to change.
			if (mSeparator != 0) {
				self._currentMax = null;
			}

			mSeparator = 0;
		}
	}

	// Different draw algorithms have been tried:
	// 1. Draw each segment as a circle, clipped to a rectangle of the desired height, direct to screen DC.
	//    Intuitive, but expensive.
	// 2. Buffered drawing: a buffer each for filled and unfilled segments (full height). Each buffer drawn as a single circle
	//    (only the part that overlaps the buffer DC is visible). Segments created by drawing horizontal lines of background
	//    colour. Screen DC is drawn from combination of two buffers, clipped to the desired fill height.
	// 3. Unbuffered drawing: no buffer, and no clip support. Want common drawBuffer() function, so draw each segment as
	//    rectangle, then draw circular background colour mask between both meters. This requires an extra drawable in the layout,
	//    expensive, so only use this strategy for unbuffered drawing. For buffered, the mask can be drawn into each buffer.
	function onUpdate(dc) {

		if (self.dataValues.max == null) {
			return;
		}

		if (self._currentMax != self.dataValues.max ) {
			self._currentMax = self.dataValues.max;
			self._currentValue = null;

			mSegments = getSegments();
			self.mBuffersNeedRedraw = 2;
		}

		if (self.dataValues.value != self._currentValue) {
			self._currentValue = self.dataValues.value;
			mFillHeight = computeFillHeight();
		}

		var meterColor = self.dataValues.color != null ? self.dataValues.color : self._defaultFullMeterColor;
		if (meterColor != self._fullMeterColor) {
			self._fullMeterColor = meterColor;
			self.mBuffersNeedRecreate |= 1;
		}

		var left = (mSide == :left) ? 0 : (Utils.screenWidth - mWidth);
		var top = (Utils.screenHeight - mHeight) / 2;

		drawBuffered(dc, left, top);

		if (self._iconFont != null && self.dataValues.icon != null) {
			dc.setColor( ( (self.dataValues.color!=null) ? self.dataValues.color : self._iconColor ), Graphics.COLOR_TRANSPARENT);

			dc.drawText(
				(mSide == :left) ? mWidth : (Utils.screenWidth - mWidth),
				(Utils.screenHeight + mHeight) / 2 + 4,
				self._iconFont, self.dataValues.icon, ((mSide == :left) ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT)|Graphics.TEXT_JUSTIFY_VCENTER);
		}
	}

	// Redraw buffers if dirty, then draw from buffer to screen: from filled buffer up to fill height, then from empty buffer for
	// remaining height.
	private function drawBuffered(dc, left, top) {
		var clipBottom;
		var clipTop;
		var clipHeight;

		var halfScreenDcWidth = (dc.getWidth() / 2);
		var x;
		var radius;

		// Recreate buffers only if this is the very first draw(), or if optimised colour palette has changed e.g. theme colour
		// change.
		if (self.mBuffersNeedRecreate > 0) {
			if (self.mBuffersNeedRecreate >= 2) {
				mEmptyBuffer = createSegmentBuffer($.gTheme.EmptyMeterColor);
			}
			mFilledBuffer = createSegmentBuffer( self._fullMeterColor );
			self.mBuffersNeedRedraw = self.mBuffersNeedRecreate; // Ensure newly-created buffers are drawn next.
			self.mBuffersNeedRecreate = 0;
		}

		// Redraw buffers only if maximum value changes.
		if (self.mBuffersNeedRedraw > 0) {

			// For arc meters, draw circular mask for each buffer.
			// Beyond right edge of bufferDc : Beyond left edge of bufferDc.
			x = (mSide == :left) ? halfScreenDcWidth : (mWidth - halfScreenDcWidth - 1);
			radius = halfScreenDcWidth - mStroke;

			if (self.mBuffersNeedRedraw >= 2) {
				var emptyBufferDc = mEmptyBuffer.getDc();
				emptyBufferDc.setColor(Graphics.COLOR_TRANSPARENT, $.gTheme.BackgroundColor);
				emptyBufferDc.clear();

				drawSegments(emptyBufferDc, 0, 0, $.gTheme.EmptyMeterColor, mSegments, 0, mHeight);

				emptyBufferDc.setColor($.gTheme.BackgroundColor, Graphics.COLOR_TRANSPARENT);
				emptyBufferDc.fillCircle(x, (mHeight / 2), radius);
			}

			var filledBufferDc = mFilledBuffer.getDc();
			filledBufferDc.setColor(Graphics.COLOR_TRANSPARENT, $.gTheme.BackgroundColor);
			filledBufferDc.clear();

			drawSegments(filledBufferDc, 0, 0, self._fullMeterColor, mSegments, 0, mHeight);

			filledBufferDc.setColor($.gTheme.BackgroundColor, Graphics.COLOR_TRANSPARENT);
			filledBufferDc.fillCircle(x, (mHeight / 2), radius);

			self.mBuffersNeedRedraw = 0;
		}

		// Draw filled segments.
		clipBottom = dc.getHeight() - top;
		clipTop = clipBottom - mFillHeight;
		clipHeight = clipBottom - clipTop;

		if (clipHeight > 0) {
			dc.setClip(left, clipTop, mWidth, clipHeight);
			dc.drawBitmap(left, top, mFilledBuffer);
		}

		// Draw unfilled segments.
		// #62 ALL_SEGMENTS or ALL_SEGMENTS_MERGED.
		if (self._goalMeterStyle <= 1) {
			clipBottom = clipTop;
			clipTop = top;
			clipHeight = clipBottom - clipTop;

			if (clipHeight > 0) {
				dc.setClip(left, clipTop, mWidth, clipHeight);
				dc.drawBitmap(left, top, mEmptyBuffer);
			}
		}

		dc.clearClip();
	}

	// Use restricted palette, to conserve memory (four buffers per watchface).
	function createSegmentBuffer(fillColour) {
		var options = {
			:width => mWidth,
			:height => mHeight,

			// First palette colour appears to determine initial colour of buffer.
			:palette => [$.gTheme.BackgroundColor, fillColour]
		};

		if ((Graphics has :createBufferedBitmap)) {
			return Graphics.createBufferedBitmap(options).get();
		}

		return new Graphics.BufferedBitmap(options);
	}

	// dc can be screen or buffer DC, depending on drawing mode.
	// x and y are co-ordinates of top-left corner of meter.
	// start/endFillHeight are pixel fill heights including separators, starting from zero at bottom.
	function drawSegments(dc as Graphics.Dc, x, y, fillColour, segments as Array, startFillHeight, endFillHeight) {
		var segmentStart = 0;
		var segmentEnd;

		var fillStart;
		var fillEnd;
		var fillHeight;

		y += mHeight; // Start from bottom.

		dc.setColor(fillColour, Graphics.COLOR_TRANSPARENT /* Graphics.COLOR_RED */);

		// Draw rectangles, separator-width apart vertically, starting from bottom.
		for (var i = 0; i < segments.size(); ++i) {
			segmentEnd = segmentStart + segments[i];

			// Full segment is filled.
			if ((segmentStart >= startFillHeight) && (segmentEnd <= endFillHeight)) {
				fillStart = segmentStart;
				fillEnd = segmentEnd;

			// Bottom of this segment is filled.
			} else if (segmentStart >= startFillHeight) {
				fillStart = segmentStart;
				fillEnd = endFillHeight;

			// Top of this segment is filled.
			} else if (segmentEnd <= endFillHeight) {
				fillStart = startFillHeight;
				fillEnd = segmentEnd;

			// Segment is not filled.
			} else {
				fillStart = 0;
				fillEnd = 0;
			}

			//Sys.println("segment     : " + segmentStart + "-->" + segmentEnd);
			//Sys.println("segment fill: " + fillStart + "-->" + fillEnd);

			fillHeight = fillEnd - fillStart;
			if (fillHeight) {
				//Sys.println("draw segment: " + x + ", " + (y - fillStart - fillHeight) + ", " + mWidth + ", " + fillHeight);
				dc.fillRectangle(x, y - fillStart - fillHeight, mWidth, fillHeight);
			}

			segmentStart = segmentEnd + mSeparator;
		}
	}

	// Return array of segment heights.
	// Last segment may be partial segment; if so, ensure its height is at least 1 pixel.
	// Segment heights rounded to nearest pixel, so neighbouring whole segments may differ in height by a pixel.
	function getSegments() as Array<Number> {
		var segmentScale = getSegmentScale(); // Value each whole segment represents.

		var numSegments = self.dataValues.max * 1.0 / segmentScale; // Including any partial. Force floating-point division.
		var numSeparators = Math.ceil(numSegments) - 1;

		var totalSegmentHeight = mHeight - (numSeparators * mSeparator); // Subtract total separator height from full height.
		var segmentHeight = totalSegmentHeight * 1.0 / numSegments; // Force floating-point division.
		//Sys.println("segmentHeight " + segmentHeight);

		var segments = new [Math.ceil(numSegments)];
		var start, end, height;

		for (var i = 0; i < segments.size(); ++i) {
			start = Math.round(i * segmentHeight);
			end = Math.round((i + 1) * segmentHeight);

			// Last segment is partial.
			if (end > totalSegmentHeight) {
				end = totalSegmentHeight;
			}

			height = end - start;

			segments[i] = height.toNumber();
			//Sys.println("segment " + i + " height " + height);
		}

		return segments;
	}

	function computeFillHeight() as Number{
		var fillHeight;

		var i;

		var totalSegmentHeight = 0;
		for (i = 0; i < self.mSegments.size(); ++i) {
			totalSegmentHeight += self.mSegments[i];
		}

		var remainingFillHeight = Math.floor((self.dataValues.value * 1.0 / self.dataValues.max) * totalSegmentHeight).toNumber(); // Excluding separators.
		fillHeight = remainingFillHeight;

		for (i = 0; i < self.mSegments.size(); ++i) {
			remainingFillHeight -= self.mSegments[i];
			if (remainingFillHeight > 0) {
				fillHeight += mSeparator; // Fill extends beyond end of this segment, so add separator height.
			} else {
				break; // Fill does not extend beyond end of this segment, because this segment is not full.
			}
		}

		//Sys.println("fillHeight " + fillHeight);
		return fillHeight;
	}

	// Determine what value each whole segment represents.
	// Try each scale in SEGMENT_SCALES array, until MIN_SEGMENT_HEIGHT is breached.
	function getSegmentScale() {
		var segmentScale;

		var tryScaleIndex = 0;
		var segmentHeight;
		var numSegments;
		var numSeparators;
		var totalSegmentHeight;

		var SEGMENT_SCALES = [1, 10, 100, 1000, 10000];

		do {
			segmentScale = SEGMENT_SCALES[tryScaleIndex];

			numSegments = self.dataValues.max * 1.0 / segmentScale;
			numSeparators = Math.ceil(numSegments);
			totalSegmentHeight = mHeight - (numSeparators * mSeparator);
			segmentHeight = Math.floor(totalSegmentHeight / numSegments);

			tryScaleIndex++;
		} while (segmentHeight <= /* MIN_WHOLE_SEGMENT_HEIGHT */ 5);

		//Sys.println("scale " + segmentScale);
		return segmentScale;
	}
}
