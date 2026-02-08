import 'dart:math';
import 'package:flutter/material.dart';
import '../services/icc_color_service.dart';

// OKLCH Color Operations
// 
// This file contains pure color space conversion functions and gamut mapping
// based on the Culori library's implementation.
// 
// Reference: https://github.com/Evercoder/culori

// ============================================================================
// CONSTANTS
// ============================================================================

// OKLCH ranges
const double oklchLMin = 0.0;
const double oklchLMax = 1.0;
const double oklchCMin = 0.0;
const double oklchCMax = 0.4;
const double oklchHMin = 0.0;
const double oklchHMax = 360.0;

// Epsilon for binary search
// Calculated as (chroma_max - chroma_min) / 4000, matching Culori exactly
// For OKLCH: (0.4 - 0.0) / 4000 = 0.0001
const double gamutEpsilon = 0.4 / 4000;

// Just-noticeable difference threshold for gamut mapping
// Colors within this delta from the clipped version are considered acceptable
// even if slightly out of gamut (CSS Color Level 4 spec)
const double jnd = 0.02;

// ============================================================================
// COLOR CLASSES
// ============================================================================

// Represents a color in OKLCH space
class OklchColor {
  final double l; // Lightness: 0-1
  final double c; // Chroma: 0-0.4
  final double h; // Hue: 0-360
  final double alpha; // Alpha: 0-1

  const OklchColor(this.l, this.c, this.h, [this.alpha = 1.0]);

  @override
  String toString() => 'oklch($l, $c, $h, $alpha)';
}

// Represents a color in OKLab space
class OklabColor {
  final double l;
  final double a;
  final double b;
  final double alpha;

  const OklabColor(this.l, this.a, this.b, [this.alpha = 1.0]);

  @override
  String toString() => 'oklab($l, $a, $b, $alpha)';
}

// Represents a color in Linear RGB space (before gamma correction)
class LinearRgbColor {
  final double r;
  final double g;
  final double b;
  final double alpha;

  const LinearRgbColor(this.r, this.g, this.b, [this.alpha = 1.0]);

  @override
  String toString() => 'lrgb($r, $g, $b, $alpha)';
}

// Represents a color in CIE Lab space (CIELAB / L*a*b*)
//
// This is different from OKLab - CIE Lab is the standard device-independent
// color space used by ICC profiles for color management.
//
// Ranges (typical):
// - L: 0 to 100 (lightness)
// - a: -128 to +127 (green to red)
// - b: -128 to +127 (blue to yellow)
class CieLabColor {
  final double l; // Lightness: 0-100
  final double a; // Green (-) to Red (+)
  final double b; // Blue (-) to Yellow (+)
  final double alpha; // Alpha: 0-1

  const CieLabColor(this.l, this.a, this.b, [this.alpha = 1.0]);

  @override
  String toString() => 'Lab($l, $a, $b, $alpha)';
}

// Represents a color in CIE XYZ space with D65 illuminant
class XyzD65Color {
  final double x;
  final double y;
  final double z;
  final double alpha;

  const XyzD65Color(this.x, this.y, this.z, [this.alpha = 1.0]);

  @override
  String toString() => 'XYZ($x, $y, $z, $alpha)';
}

// ============================================================================
// CONVERSION: OKLCH ↔ OKLab
// ============================================================================

// Converts OKLCH to OKLab
// 
// Formula:
// - a = c * cos(h * π / 180)
// - b = c * sin(h * π / 180)
OklabColor oklchToOklab(OklchColor color) {
  final double l = color.l;
  final double c = color.c;
  final double h = color.h;
  
  // Convert hue from degrees to radians
  final double hRad = h * pi / 180.0;
  
  // Calculate a and b using polar to cartesian conversion
  final double a = c * cos(hRad);
  final double b = c * sin(hRad);
  
  return OklabColor(l, a, b, color.alpha);
}

// Converts OKLab to OKLCH
// 
// Formula:
// - c = sqrt(a² + b²)
// - h = atan2(b, a) * 180 / π
OklchColor oklabToOklch(OklabColor color) {
  final double l = color.l;
  final double a = color.a;
  final double b = color.b;
  
  // Calculate chroma using Euclidean distance
  final double c = sqrt(a * a + b * b);
  
  // Calculate hue using atan2 and convert to degrees
  double h = atan2(b, a) * 180.0 / pi;
  
  // Normalize hue to [0, 360)
  if (h < 0) {
    h += 360.0;
  }
  
  return OklchColor(l, c, h, color.alpha);
}

// ============================================================================
// CONVERSION: OKLab ↔ Linear RGB
// ============================================================================

// Converts OKLab to Linear RGB
// 
// Uses the OKLab → LMS → Linear RGB transformation matrices.
// Reference: https://bottosson.github.io/posts/oklab/
LinearRgbColor oklabToLinearRgb(OklabColor color) {
  final double l = color.l;
  final double a = color.a;
  final double b = color.b;
  
  // Step 1: OKLab → LMS (cone response)
  // Using full precision coefficients from Culori
  final double lCone = l + 0.3963377773761749 * a + 0.2158037573099136 * b;
  final double mCone = l - 0.1055613458156586 * a - 0.0638541728258133 * b;
  final double sCone = l - 0.0894841775298119 * a - 1.2914855480194092 * b;
  
  // Step 2: Cube the values (LMS³)
  final double lCube = lCone * lCone * lCone;
  final double mCube = mCone * mCone * mCone;
  final double sCube = sCone * sCone * sCone;
  
  // Step 3: LMS → Linear RGB transformation
  // Using full precision coefficients from Culori
  final double r = 4.0767416360759574 * lCube - 3.3077115392580616 * mCube + 0.2309699031821044 * sCube;
  final double g = -1.2684379732850317 * lCube + 2.6097573492876887 * mCube - 0.3413193760026573 * sCube;
  final double bValue = -0.0041960761386756 * lCube - 0.7034186179359362 * mCube + 1.7076146940746117 * sCube;
  
  return LinearRgbColor(r, g, bValue, color.alpha);
}

// Converts Linear RGB to OKLab
// 
// Reverse of oklabToLinearRgb.
OklabColor linearRgbToOklab(LinearRgbColor color) {
  final double r = color.r;
  final double g = color.g;
  final double b = color.b;
  
  // Step 1: Linear RGB → LMS (cone response)
  // Using full precision coefficients from Culori
  final double l = 0.412221469470763 * r + 0.5363325372617348 * g + 0.0514459932675022 * b;
  final double m = 0.2119034958178252 * r + 0.6806995506452344 * g + 0.1073969535369406 * b;
  final double s = 0.0883024591900564 * r + 0.2817188391361215 * g + 0.6299787016738222 * b;
  
  // Step 2: Cube root (∛LMS)
  final double lRoot = _cubeRoot(l);
  final double mRoot = _cubeRoot(m);
  final double sRoot = _cubeRoot(s);
  
  // Step 3: LMS → OKLab transformation
  // Using full precision coefficients from Culori
  final double lOklab = 0.210454268309314 * lRoot + 0.7936177747023054 * mRoot - 0.0040720430116193 * sRoot;
  final double aOklab = 1.9779985324311684 * lRoot - 2.4285922420485799 * mRoot + 0.450593709617411 * sRoot;
  final double bOklab = 0.0259040424655478 * lRoot + 0.7827717124575296 * mRoot - 0.8086757549230774 * sRoot;
  
  return OklabColor(lOklab, aOklab, bOklab, color.alpha);
}

// Cube root function (handles negative values correctly)
double _cubeRoot(double x) {
  if (x >= 0) {
    return pow(x, 1.0 / 3.0).toDouble();
  } else {
    return -pow(-x, 1.0 / 3.0).toDouble();
  }
}

// ============================================================================
// CONVERSION: Linear RGB ↔ sRGB (Gamma Correction)
// ============================================================================

// Applies gamma correction to a single channel (Linear RGB → sRGB)
// 
// Uses the sRGB gamma curve.
double _gammaCorrection(double channel) {
  final double abs = channel.abs();
  
  if (abs > 0.0031308) {
    // Use sign, defaulting to 1 if channel is 0 (matching JavaScript behavior)
    final double sign = channel.sign != 0 ? channel.sign : 1.0;
    return sign * (1.055 * pow(abs, 1.0 / 2.4) - 0.055);
  } else {
    return channel * 12.92;
  }
}

// Removes gamma correction from a single channel (sRGB → Linear RGB)
double _gammaExpansion(double channel) {
  final double abs = channel.abs();
  
  if (abs <= 0.04045) {
    return channel / 12.92;
  } else {
    // Use sign, defaulting to 1 if channel is 0 (matching JavaScript behavior)
    final double sign = channel.sign != 0 ? channel.sign : 1.0;
    return sign * pow((abs + 0.055) / 1.055, 2.4);
  }
}

// Converts Linear RGB to sRGB (gamma correction)
Color linearRgbToSrgb(LinearRgbColor color) {
  final double r = _gammaCorrection(color.r);
  final double g = _gammaCorrection(color.g);
  final double b = _gammaCorrection(color.b);
  
  // Clamp to [0, 1] and convert to [0, 255]
  final int rInt = (r.clamp(0.0, 1.0) * 255).round();
  final int gInt = (g.clamp(0.0, 1.0) * 255).round();
  final int bInt = (b.clamp(0.0, 1.0) * 255).round();
  final int aInt = (color.alpha.clamp(0.0, 1.0) * 255).round();
  
  return Color.fromARGB(aInt, rInt, gInt, bInt);
}

// Converts sRGB to Linear RGB (gamma expansion)
LinearRgbColor srgbToLinearRgb(Color color) {
  // Convert [0, 255] to [0, 1]
  final double r = color.r;
  final double g = color.g;
  final double b = color.b;
  final double a = color.a;

  // Apply gamma expansion
  return LinearRgbColor(
    _gammaExpansion(r),
    _gammaExpansion(g),
    _gammaExpansion(b),
    a,
  );
}

// ============================================================================
// CONVERSION: Linear RGB ↔ XYZ D65
// ============================================================================

// Converts Linear RGB to CIE XYZ (D65 illuminant)
//
// Uses the sRGB to XYZ D65 transformation matrix.
// Reference: https://www.color.org/srgb.pdf
XyzD65Color linearRgbToXyzD65(LinearRgbColor color) {
  final double r = color.r;
  final double g = color.g;
  final double b = color.b;

  // sRGB to XYZ D65 transformation matrix
  final double x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
  final double y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
  final double z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;

  return XyzD65Color(x, y, z, color.alpha);
}

// Converts CIE XYZ (D65 illuminant) to Linear RGB
//
// Reverse of linearRgbToXyzD65.
LinearRgbColor xyzD65ToLinearRgb(XyzD65Color color) {
  final double x = color.x;
  final double y = color.y;
  final double z = color.z;

  // XYZ D65 to sRGB transformation matrix (inverse)
  final double r =  3.2404542 * x + -1.5371385 * y + -0.4985314 * z;
  final double g = -0.9692660 * x +  1.8760108 * y +  0.0415560 * z;
  final double b =  0.0556434 * x + -0.2040259 * y +  1.0572252 * z;

  return LinearRgbColor(r, g, b, color.alpha);
}

// ============================================================================
// CONVERSION: XYZ D65 ↔ CIE Lab
// ============================================================================

// D65 white point reference values for CIE Lab
const double _d65Xn = 0.95047;
const double _d65Yn = 1.00000;
const double _d65Zn = 1.08883;

// CIE Lab f(t) function helper
//
// This is the nonlinear transformation used in CIE Lab color space.
// - If t > δ³: f(t) = t^(1/3)
// - Otherwise: f(t) = t/(3δ²) + 4/29
// where δ = 6/29
double _labF(double t) {
  const double delta = 6.0 / 29.0;
  const double delta3 = delta * delta * delta; // (6/29)³ ≈ 0.008856
  const double factor = 1.0 / (3.0 * delta * delta); // 1/(3*(6/29)²)
  const double offset = 4.0 / 29.0;

  if (t > delta3) {
    return pow(t, 1.0 / 3.0).toDouble();
  } else {
    return factor * t + offset;
  }
}

// Inverse of CIE Lab f(t) function
double _labFInv(double t) {
  const double delta = 6.0 / 29.0;
  const double threshold = delta; // 6/29
  const double factor = 3.0 * delta * delta; // 3*(6/29)²
  const double offset = 4.0 / 29.0;

  if (t > threshold) {
    return pow(t, 3.0).toDouble();
  } else {
    return factor * (t - offset);
  }
}

// Converts CIE XYZ (D65) to CIE Lab
//
// Uses D65 illuminant as the white point.
// Formula from CIE 1976 L*a*b* standard.
CieLabColor xyzD65ToCieLab(XyzD65Color color) {
  // Normalize by D65 white point
  final double xr = color.x / _d65Xn;
  final double yr = color.y / _d65Yn;
  final double zr = color.z / _d65Zn;

  // Apply f(t) transformation
  final double fx = _labF(xr);
  final double fy = _labF(yr);
  final double fz = _labF(zr);

  // Calculate L*a*b* values
  final double l = 116.0 * fy - 16.0;
  final double a = 500.0 * (fx - fy);
  final double b = 200.0 * (fy - fz);

  return CieLabColor(l, a, b, color.alpha);
}

// Converts CIE Lab to CIE XYZ (D65)
//
// Reverse of xyzD65ToCieLab.
XyzD65Color cieLabToXyzD65(CieLabColor color) {
  // Calculate intermediate values
  final double fy = (color.l + 16.0) / 116.0;
  final double fx = color.a / 500.0 + fy;
  final double fz = fy - color.b / 200.0;

  // Apply inverse f(t) transformation
  final double xr = _labFInv(fx);
  final double yr = _labFInv(fy);
  final double zr = _labFInv(fz);

  // Denormalize by D65 white point
  final double x = xr * _d65Xn;
  final double y = yr * _d65Yn;
  final double z = zr * _d65Zn;

  return XyzD65Color(x, y, z, color.alpha);
}

// ============================================================================
// CONVERSION: OKLCH ↔ CIE Lab (High-Level Helpers)
// ============================================================================

// Converts OKLCH to CIE Lab
//
// Full conversion chain: OKLCH → OKLab → Linear RGB → XYZ D65 → CIE Lab
// This is used for ICC profile transformations.
CieLabColor oklchToCieLab(double l, double c, double h) {
  // OKLCH → OKLab
  final oklch = OklchColor(l, c, h);
  final oklab = oklchToOklab(oklch);

  // OKLab → Linear RGB
  final linearRgb = oklabToLinearRgb(oklab);

  // Linear RGB → XYZ D65
  final xyz = linearRgbToXyzD65(linearRgb);

  // XYZ D65 → CIE Lab
  return xyzD65ToCieLab(xyz);
}

// Converts CIE Lab to OKLCH
//
// Full conversion chain: CIE Lab → XYZ D65 → Linear RGB → OKLab → OKLCH
// This is used to convert back from ICC profile transformations.
OklchColor cieLabToOklch(double l, double a, double b) {
  // CIE Lab → XYZ D65
  final cieLab = CieLabColor(l, a, b);
  final xyz = cieLabToXyzD65(cieLab);

  // XYZ D65 → Linear RGB
  final linearRgb = xyzD65ToLinearRgb(xyz);

  // Linear RGB → OKLab
  final oklab = linearRgbToOklab(linearRgb);

  // OKLab → OKLCH
  return oklabToOklch(oklab);
}

// ============================================================================
// GAMUT CHECKING & CLAMPING
// ============================================================================

// Checks if a Linear RGB color is within the sRGB gamut
// 
// Returns true if all channels are in [0, 1] range (with small epsilon for floating-point errors)
bool isInGamut(LinearRgbColor color) {
  const double epsilon = 0.0001;
  return color.r >= -epsilon && color.r <= 1.0 + epsilon &&
         color.g >= -epsilon && color.g <= 1.0 + epsilon &&
         color.b >= -epsilon && color.b <= 1.0 + epsilon;
}

// Clamps Linear RGB channels to [0, 1] range
LinearRgbColor clampRgb(LinearRgbColor color) {
  return LinearRgbColor(
    color.r.clamp(0.0, 1.0),
    color.g.clamp(0.0, 1.0),
    color.b.clamp(0.0, 1.0),
    color.alpha,
  );
}

// Calculate Euclidean distance between two OKLCH colors
// Used for the JND (just-noticeable difference) optimization
// 
// Uses the proper cylindrical coordinate distance formula:
// - Lightness: simple difference
// - Chroma: simple difference  
// - Hue: weighted by chroma using differenceHueChroma formula
double _deltaOklch(OklchColor a, OklchColor b) {
  // Lightness difference
  final double dL = a.l - b.l;
  
  // Chroma difference
  final double dC = a.c - b.c;
  
  // Hue difference using the cylindrical formula
  // This weights hue by chroma (hue matters less when colors are gray)
  double dH = 0.0;
  if (a.c > 0 && b.c > 0) {
    // Normalize hues to [0, 360)
    double h1 = a.h % 360;
    double h2 = b.h % 360;
    if (h1 < 0) h1 += 360;
    if (h2 < 0) h2 += 360;
    
    // Calculate hue difference using sine formula
    // This properly handles the circular nature of hue
    final double hueDiff = h2 - h1 + 360;
    final double dHSin = sin((hueDiff / 2) * pi / 180);
    dH = 2 * sqrt(a.c * b.c) * dHSin;
  }
  
  // Euclidean distance in OKLCH space
  // Default weights are [1, 1, 1, 0] for [L, C, H, alpha]
  return sqrt(dL * dL + dC * dC + dH * dH);
}

// ============================================================================
// MAIN GAMUT MAPPING ALGORITHM
// ============================================================================

// Converts OKLCH to sRGB with gamut mapping
// 
// This is the main function that ensures colors fit within the sRGB gamut.
// Uses binary search to find the maximum chroma that produces a valid sRGB color.
// 
// Implements the CSS Color Level 4 gamut mapping algorithm with JND optimization:
// https://drafts.csswg.org/css-color/#css-gamut-mapping
// 
// Colors are accepted if they are either:
// 1. Strictly within the sRGB gamut, OR
// 2. "Roughly in gamut" - the perceptual difference (delta) from the clipped
//    version is below the JND (just-noticeable difference) threshold of 0.02
// 
// This produces more vivid colors while staying perceptually correct.
Color oklchToSrgbWithGamut(OklchColor color) {
  // Handle edge cases: pure white
  if (color.l >= oklchLMax) {
    return Color.fromARGB(
      (color.alpha * 255).round(),
      255, 255, 255,
    );
  }
  
  // Handle edge cases: pure black
  if (color.l <= oklchLMin) {
    return Color.fromARGB(
      (color.alpha * 255).round(),
      0, 0, 0,
    );
  }
  
  // Try direct conversion first
  OklabColor oklab = oklchToOklab(color);
  LinearRgbColor linearRgb = oklabToLinearRgb(oklab);
  
  // If already in gamut, return it
  if (isInGamut(linearRgb)) {
    return linearRgbToSrgb(linearRgb);
  }
  
  // Binary search for maximum valid chroma
  double start = 0.0;
  double end = color.c;
  
  // Create a mutable candidate color
  OklchColor candidate = OklchColor(color.l, color.c, color.h, color.alpha);
  
  LinearRgbColor clipped = linearRgb;
  
  while (end - start > gamutEpsilon) {
    // Try the midpoint
    final double midChroma = (start + end) * 0.5;
    candidate = OklchColor(color.l, midChroma, color.h, color.alpha);
    
    // Convert to Linear RGB
    final OklabColor candidateOklab = oklchToOklab(candidate);
    final LinearRgbColor candidateLinearRgb = oklabToLinearRgb(candidateOklab);
    
    // Get clipped version for JND comparison
    clipped = clampRgb(candidateLinearRgb);
    
    // Check if in gamut OR "roughly in gamut" (within JND threshold)
    // This is the CSS Color Level 4 gamut mapping algorithm
    final bool isAcceptable = isInGamut(candidateLinearRgb) ||
        _deltaOklch(
            candidate,
            oklabToOklch(linearRgbToOklab(clipped))
        ) <= jnd;
    
    if (isAcceptable) {
      // This chroma works, try higher
      start = midChroma;
    } else {
      // This chroma is too high, try lower
      end = midChroma;
    }
  }
  
  // Use the final candidate if in gamut, otherwise use clipped version
  final OklabColor finalOklab = oklchToOklab(candidate);
  final LinearRgbColor finalLinearRgb = oklabToLinearRgb(finalOklab);
  
  return linearRgbToSrgb(
      isInGamut(finalLinearRgb) ? finalLinearRgb : clipped
  );
}

// Converts Flutter Color (sRGB) to OKLCH
// 
// This is the reverse operation - useful for color pickers.
OklchColor srgbToOklch(Color color) {
  final LinearRgbColor linearRgb = srgbToLinearRgb(color);
  final OklabColor oklab = linearRgbToOklab(linearRgb);
  return oklabToOklch(oklab);
}

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

// Creates a Flutter Color from OKLCH values with gamut mapping
Color colorFromOklch(double l, double c, double h, [double alpha = 1.0]) {
  return oklchToSrgbWithGamut(OklchColor(l, c, h, alpha));
}

// Extracts OKLCH values from a Flutter Color
Map<String, double> colorToOklch(Color color) {
  final oklch = srgbToOklch(color);
  return {
    'l': oklch.l,
    'c': oklch.c,
    'h': oklch.h,
    'alpha': oklch.alpha,
  };
}

// Tests if an OKLCH color is displayable in sRGB
bool isOklchDisplayable(double l, double c, double h) {
  final oklch = OklchColor(l, c, h);
  final oklab = oklchToOklab(oklch);
  final linearRgb = oklabToLinearRgb(oklab);
  return isInGamut(linearRgb);
}

// Gets the maximum displayable chroma for a given L and H
double getMaxChroma(double l, double h, {double maxSearch = 0.5}) {
  double low = 0.0;
  double high = maxSearch;
  
  while (high - low > gamutEpsilon) {
    double mid = (low + high) / 2.0;
    
    if (isOklchDisplayable(l, mid, h)) {
      low = mid;
    } else {
      high = mid;
    }
  }
  
  return low;
}

// ============================================================
// GRADIENT GENERATION FOR SLIDERS
// ============================================================

// Represents a gradient stop with both requested and fallback colors
// for split-view rendering when colors are out of sRGB gamut
class GradientStop {
  // The requested color (may be out of gamut)
  final Color requestedColor;
  
  // The gamut-mapped fallback color (always in sRGB)
  final Color fallbackColor;
  
  // Whether this color is within sRGB gamut
  final bool isInGamut;
  
  const GradientStop({
    required this.requestedColor,
    required this.fallbackColor,
    required this.isInGamut,
  });
}

// 1. Generate gradient stops for lightness slider (L axis)
// Varies lightness from 0 to 1 while keeping chroma and hue constant
List<GradientStop> generateLightnessGradient(
  double chroma,
  double hue,
  int samples, {
  bool useRealPigmentsOnly = false,
}) {
  final List<GradientStop> stops = [];

  // Step 1: Sample colors across lightness range
  for (int i = 0; i < samples; i++) {
    // Step 2: Calculate lightness value for this sample
    double l = i / (samples - 1); // 0.0 to 1.0
    double c = chroma;
    double h = hue;

    // Step 3: Apply ICC display filter if enabled
    if (useRealPigmentsOnly && IccColorManager.instance.isReady) {
      final cieLab = oklchToCieLab(l, c, h);
      final mappedLab = IccColorManager.instance.transformLab(
        cieLab.l,
        cieLab.a,
        cieLab.b,
      );
      final mappedOklch = cieLabToOklch(mappedLab[0], mappedLab[1], mappedLab[2]);
      l = mappedOklch.l;
      c = mappedOklch.c;
      h = mappedOklch.h;
    }

    // Step 4: Create OKLCH color (potentially filtered)
    final oklch = OklchColor(l, c, h);

    // Step 5: Check if color is in sRGB gamut
    final inGamut = isInGamut(oklabToLinearRgb(oklchToOklab(oklch)));

    // Step 6: Convert to sRGB (with gamut mapping if needed)
    final color = oklchToSrgbWithGamut(oklch);

    // Step 7: Create gradient stop
    stops.add(GradientStop(
      requestedColor: color,
      fallbackColor: color,
      isInGamut: inGamut,
    ));
  }

  return stops;
}

// 2. Generate gradient stops for chroma slider (C axis)
// Varies chroma from 0 to max while keeping lightness and hue constant
List<GradientStop> generateChromaGradient(
  double lightness,
  double hue,
  int samples, {
  double maxChroma = 0.4,
  bool useRealPigmentsOnly = false,
}) {
  final List<GradientStop> stops = [];

  // Step 1: Sample colors across chroma range
  for (int i = 0; i < samples; i++) {
    // Step 2: Calculate chroma value for this sample
    double l = lightness;
    double c = (i / (samples - 1)) * maxChroma; // 0.0 to maxChroma
    double h = hue;

    // Step 3: Apply ICC display filter if enabled
    if (useRealPigmentsOnly && IccColorManager.instance.isReady) {
      final cieLab = oklchToCieLab(l, c, h);
      final mappedLab = IccColorManager.instance.transformLab(
        cieLab.l,
        cieLab.a,
        cieLab.b,
      );
      final mappedOklch = cieLabToOklch(mappedLab[0], mappedLab[1], mappedLab[2]);
      l = mappedOklch.l;
      c = mappedOklch.c;
      h = mappedOklch.h;
    }

    // Step 4: Create OKLCH color (potentially filtered)
    final oklch = OklchColor(l, c, h);

    // Step 5: Check if color is in sRGB gamut
    final inGamut = isInGamut(oklabToLinearRgb(oklchToOklab(oklch)));

    // Step 6: Convert to sRGB (with gamut mapping if needed)
    final color = oklchToSrgbWithGamut(oklch);

    // Step 7: Create gradient stop
    stops.add(GradientStop(
      requestedColor: color,
      fallbackColor: color,
      isInGamut: inGamut,
    ));
  }

  return stops;
}

// 3. Generate gradient stops for hue slider (H axis)
// Varies hue from 0 to 360 while keeping lightness and chroma constant
List<GradientStop> generateHueGradient(
  double lightness,
  double chroma,
  int samples, {
  bool useRealPigmentsOnly = false,
}) {
  final List<GradientStop> stops = [];

  // Step 1: Sample colors across hue range
  for (int i = 0; i < samples; i++) {
    // Step 2: Calculate hue value for this sample
    double l = lightness;
    double c = chroma;
    double h = (i / (samples - 1)) * 360.0; // 0 to 360 degrees

    // Step 3: Apply ICC display filter if enabled
    if (useRealPigmentsOnly && IccColorManager.instance.isReady) {
      final cieLab = oklchToCieLab(l, c, h);
      final mappedLab = IccColorManager.instance.transformLab(
        cieLab.l,
        cieLab.a,
        cieLab.b,
      );
      final mappedOklch = cieLabToOklch(mappedLab[0], mappedLab[1], mappedLab[2]);
      l = mappedOklch.l;
      c = mappedOklch.c;
      h = mappedOklch.h;
    }

    // Step 4: Create OKLCH color (potentially filtered)
    final oklch = OklchColor(l, c, h);

    // Step 5: Check if color is in sRGB gamut
    final inGamut = isInGamut(oklabToLinearRgb(oklchToOklab(oklch)));

    // Step 6: Convert to sRGB (with gamut mapping if needed)
    final color = oklchToSrgbWithGamut(oklch);

    // Step 7: Create gradient stop
    stops.add(GradientStop(
      requestedColor: color,
      fallbackColor: color,
      isInGamut: inGamut,
    ));
  }

  return stops;
}

// 4. Generate gradient stops for alpha slider
// Varies alpha from 0 to 1 while keeping color constant
List<Color> generateAlphaGradient(
  Color baseColor,
  int samples,
) {
  final List<Color> stops = [];

  // Step 1: Sample alpha values
  for (int i = 0; i < samples; i++) {
    // Step 2: Calculate alpha value for this sample
    final double alpha = i / (samples - 1); // 0.0 to 1.0

    // Step 3: Create color with varying alpha
    stops.add(baseColor.withValues(alpha: alpha));
  }

  return stops;
}

// ============================================================
// OKLCH COLOR INTERPOLATION
// ============================================================

// Interpolates between two colors in OKLCH color space
//
// This function performs perceptually uniform interpolation by:
// 1. Converting both colors to OKLCH
// 2. Interpolating L, C, H, and alpha channels separately
// 3. Using the shortest path for hue interpolation (handles wraparound)
// 4. Converting back to sRGB with gamut mapping
//
// Parameters:
// - colorA: Starting color
// - colorB: Ending color
// - t: Interpolation factor (0.0 = colorA, 1.0 = colorB)
//
// Returns the interpolated color in sRGB space
Color lerpOklch(Color colorA, Color colorB, double t) {
  // Convert both colors to OKLCH
  final oklchA = srgbToOklch(colorA);
  final oklchB = srgbToOklch(colorB);

  // Interpolate lightness and chroma linearly
  final l = oklchA.l + (oklchB.l - oklchA.l) * t;
  final c = oklchA.c + (oklchB.c - oklchA.c) * t;
  final alpha = oklchA.alpha + (oklchB.alpha - oklchA.alpha) * t;

  // Interpolate hue using the shortest path around the color wheel
  double h;
  if (oklchA.c < 0.0001 || oklchB.c < 0.0001) {
    // If either color is achromatic (very low chroma), use the hue from the chromatic color
    // or interpolate normally if both are achromatic
    if (oklchA.c < 0.0001 && oklchB.c >= 0.0001) {
      h = oklchB.h;
    } else if (oklchB.c < 0.0001 && oklchA.c >= 0.0001) {
      h = oklchA.h;
    } else {
      h = oklchA.h + (oklchB.h - oklchA.h) * t;
    }
  } else {
    // Both colors are chromatic - use shortest path interpolation
    double hueA = oklchA.h;
    double hueB = oklchB.h;

    // Normalize hues to [0, 360)
    hueA = hueA % 360;
    hueB = hueB % 360;
    if (hueA < 0) hueA += 360;
    if (hueB < 0) hueB += 360;

    // Calculate the difference
    double diff = hueB - hueA;

    // Take the shortest path
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    // Interpolate
    h = hueA + diff * t;

    // Normalize result to [0, 360)
    h = h % 360;
    if (h < 0) h += 360;
  }

  // Create interpolated OKLCH color and convert to sRGB
  final interpolated = OklchColor(l, c, h, alpha);
  return oklchToSrgbWithGamut(interpolated);
}

// ============================================================
// HSB/HSV COLOR OPERATIONS
// ============================================================

// Represents a color in HSB (Hue, Saturation, Brightness) space
// Also known as HSV (Hue, Saturation, Value)
class HsbColor {
  final double h; // Hue: 0-360
  final double s; // Saturation: 0-100
  final double b; // Brightness: 0-100
  final double alpha; // Alpha: 0-1

  const HsbColor(this.h, this.s, this.b, [this.alpha = 1.0]);

  @override
  String toString() => 'hsb($h, $s, $b, $alpha)';
}

// Convert HSB to Flutter Color
//
// Parameters:
// - h: Hue (0-360)
// - s: Saturation (0-100)
// - b: Brightness (0-100)
// - alpha: Alpha (0-1)
//
// Returns Flutter Color in sRGB space
Color colorFromHsb(double h, double s, double b, [double alpha = 1.0]) {
  // Convert to Flutter's HSVColor (which uses 0-1 range for S and V)
  final hsvColor = HSVColor.fromAHSV(
    alpha,
    h % 360, // Hue: 0-360
    (s / 100).clamp(0.0, 1.0), // Saturation: 0-1
    (b / 100).clamp(0.0, 1.0), // Value (Brightness): 0-1
  );

  return hsvColor.toColor();
}

// Convert Flutter Color to HSB
//
// Parameters:
// - color: Flutter Color in sRGB space
//
// Returns HsbColor with values in standard ranges
HsbColor srgbToHsb(Color color) {
  final hsvColor = HSVColor.fromColor(color);

  return HsbColor(
    hsvColor.hue, // 0-360
    hsvColor.saturation * 100, // 0-100
    hsvColor.value * 100, // 0-100
    color.alpha / 255, // 0-1
  );
}

// Generate hue gradient for HSB slider
//
// Creates a rainbow gradient from red through all hues back to red
// keeping saturation and brightness constant.
//
// Parameters:
// - saturation: Current saturation value (0-100)
// - brightness: Current brightness value (0-100)
// - samples: Number of color samples (default 300)
//
// Returns list of gradient stops
List<GradientStop> generateHueGradientHsb(
  double saturation,
  double brightness,
  int samples,
) {
  final List<GradientStop> stops = [];

  for (int i = 0; i < samples; i++) {
    final double hue = (i / (samples - 1)) * 360; // 0 to 360
    final color = colorFromHsb(hue, saturation, brightness);

    // HSB is always in sRGB gamut, so no gamut mapping needed
    stops.add(GradientStop(
      requestedColor: color,
      fallbackColor: color,
      isInGamut: true,
    ));
  }

  return stops;
}

// Generate saturation gradient for HSB slider
//
// Creates a gradient from gray (0% saturation) to full color (100% saturation)
// keeping hue and brightness constant.
//
// Parameters:
// - hue: Current hue value (0-360)
// - brightness: Current brightness value (0-100)
// - samples: Number of color samples (default 300)
//
// Returns list of gradient stops
List<GradientStop> generateSaturationGradientHsb(
  double hue,
  double brightness,
  int samples,
) {
  final List<GradientStop> stops = [];

  for (int i = 0; i < samples; i++) {
    final double saturation = (i / (samples - 1)) * 100; // 0 to 100
    final color = colorFromHsb(hue, saturation, brightness);

    stops.add(GradientStop(
      requestedColor: color,
      fallbackColor: color,
      isInGamut: true,
    ));
  }

  return stops;
}

// Generate brightness gradient for HSB slider
//
// Creates a gradient from black (0% brightness) to full brightness (100%)
// keeping hue and saturation constant.
//
// Parameters:
// - hue: Current hue value (0-360)
// - saturation: Current saturation value (0-100)
// - samples: Number of color samples (default 300)
//
// Returns list of gradient stops
List<GradientStop> generateBrightnessGradientHsb(
  double hue,
  double saturation,
  int samples,
) {
  final List<GradientStop> stops = [];

  for (int i = 0; i < samples; i++) {
    final double brightness = (i / (samples - 1)) * 100; // 0 to 100
    final color = colorFromHsb(hue, saturation, brightness);

    stops.add(GradientStop(
      requestedColor: color,
      fallbackColor: color,
      isInGamut: true,
    ));
  }

  return stops;
}
