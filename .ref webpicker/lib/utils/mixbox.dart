// ==========================================================
//  MIXBOX 2.0 (c) 2022 Secret Weapons. All rights reserved.
//  License: Creative Commons Attribution-NonCommercial 4.0
//  Port to Dart by: [Your project]
// ==========================================================
//
//   BASIC USAGE
//
//      lerpMixbox(color1, color2, t);  // Pigment-based color mixing
//
//   HOW IT WORKS
//
//      Mixbox treats colors as real-life pigments using the Kubelka & Munk
//      theory to predict realistic color behavior. This produces saturated
//      gradients with natural hue shifts and secondary colors.
//
//      Example: Yellow + Blue = Green (like real paint!)
//
// ==========================================================

import 'package:flutter/material.dart';
import 'mixbox_data.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

// Size of the latent vector (7 dimensions)
const int _latentSize = 7;

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Clamps a value between 0.0 and 1.0
double _clamp01(double x) {
  return x.clamp(0.0, 1.0);
}

// ============================================================================
// RGB TO LATENT CONVERSION
// ============================================================================

// Converts RGB color to 7D latent space using trilinear interpolation
//
// Parameters:
// - r: Red channel (0.0 to 1.0)
// - g: Green channel (0.0 to 1.0)
// - b: Blue channel (0.0 to 1.0)
//
// Returns a 7D latent vector [c0, c1, c2, c3, r_offset, g_offset, b_offset]
List<double> _rgbToLatent(double r, double g, double b) {
  // Clamp input to valid range
  r = _clamp01(r);
  g = _clamp01(g);
  b = _clamp01(b);

  // Map to 64x64x64 grid
  final x = r * 63.0;
  final y = g * 63.0;
  final z = b * 63.0;

  // Integer grid positions
  final ix = x.floor();
  final iy = y.floor();
  final iz = z.floor();

  // Fractional parts for interpolation
  final tx = x - ix;
  final ty = y - iy;
  final tz = z - iz;

  // Calculate base index in 64x64x64 grid
  final xyz = ix + iy * 64 + iz * 64 * 64;

  // Trilinear interpolation
  // Sample 8 corners of the cube and interpolate
  //
  // LUT uses PLANAR format (like JavaScript reference):
  // [header (192 bytes)][all c0 values (262144)][all c1 values (262144)][all c2 values (262144)]
  const int c0Offset = 192;
  const int c1Offset = 262336; // 192 + 64*64*64
  const int c2Offset = 524480; // 192 + 2*64*64*64

  double c0 = 0.0;
  double c1 = 0.0;
  double c2 = 0.0;

  // Helper function to get LUT value at specific voxel offset and channel
  // Uses planar layout: separate regions for c0, c1, c2
  double getLut(int voxelOffset, int channel) {
    int index;
    if (channel == 0) {
      index = xyz + voxelOffset + c0Offset;
    } else if (channel == 1) {
      index = xyz + voxelOffset + c1Offset;
    } else {
      index = xyz + voxelOffset + c2Offset;
    }

    if (index >= 0 && index < mixboxLutData.length) {
      return mixboxLutData[index] / 255.0;
    }
    return 0.0;
  }

  // 8-point trilinear interpolation
  double w;

  // Corner (0, 0, 0)
  w = (1.0 - tx) * (1.0 - ty) * (1.0 - tz);
  c0 += w * getLut(0, 0);
  c1 += w * getLut(0, 1);
  c2 += w * getLut(0, 2);

  // Corner (1, 0, 0)
  w = tx * (1.0 - ty) * (1.0 - tz);
  c0 += w * getLut(1, 0);
  c1 += w * getLut(1, 1);
  c2 += w * getLut(1, 2);

  // Corner (0, 1, 0)
  w = (1.0 - tx) * ty * (1.0 - tz);
  c0 += w * getLut(64, 0);
  c1 += w * getLut(64, 1);
  c2 += w * getLut(64, 2);

  // Corner (1, 1, 0)
  w = tx * ty * (1.0 - tz);
  c0 += w * getLut(65, 0);
  c1 += w * getLut(65, 1);
  c2 += w * getLut(65, 2);

  // Corner (0, 0, 1)
  w = (1.0 - tx) * (1.0 - ty) * tz;
  c0 += w * getLut(4096, 0);
  c1 += w * getLut(4096, 1);
  c2 += w * getLut(4096, 2);

  // Corner (1, 0, 1)
  w = tx * (1.0 - ty) * tz;
  c0 += w * getLut(4097, 0);
  c1 += w * getLut(4097, 1);
  c2 += w * getLut(4097, 2);

  // Corner (0, 1, 1)
  w = (1.0 - tx) * ty * tz;
  c0 += w * getLut(4160, 0);
  c1 += w * getLut(4160, 1);
  c2 += w * getLut(4160, 2);

  // Corner (1, 1, 1)
  w = tx * ty * tz;
  c0 += w * getLut(4161, 0);
  c1 += w * getLut(4161, 1);
  c2 += w * getLut(4161, 2);

  // Calculate c3 (the fourth pigment component)
  final c3 = 1.0 - (c0 + c1 + c2);

  // Evaluate polynomial to get RGB mix
  final c00 = c0 * c0;
  final c11 = c1 * c1;
  final c22 = c2 * c2;
  final c33 = c3 * c3;
  final c01 = c0 * c1;
  final c02 = c0 * c2;
  final c12 = c1 * c2;

  double rmix = 0.0;
  double gmix = 0.0;
  double bmix = 0.0;

  // Polynomial coefficients (from Mixbox)
  w = c0 * c00;
  rmix += 0.07717053 * w;
  gmix += 0.02826978 * w;
  bmix += 0.24832992 * w;

  w = c1 * c11;
  rmix += 0.95912302 * w;
  gmix += 0.80256528 * w;
  bmix += 0.03561839 * w;

  w = c2 * c22;
  rmix += 0.74683774 * w;
  gmix += 0.04868586 * w;
  bmix += 0.00000000 * w;

  w = c3 * c33;
  rmix += 0.99518138 * w;
  gmix += 0.99978149 * w;
  bmix += 0.99704802 * w;

  w = c00 * c1;
  rmix += 0.04819146 * w;
  gmix += 0.83363781 * w;
  bmix += 0.32515377 * w;

  w = c01 * c1;
  rmix += -0.68146950 * w;
  gmix += 1.46107803 * w;
  bmix += 1.06980936 * w;

  w = c00 * c2;
  rmix += 0.27058419 * w;
  gmix += -0.15324870 * w;
  bmix += 1.98735057 * w;

  w = c02 * c2;
  rmix += 0.80478189 * w;
  gmix += 0.67093710 * w;
  bmix += 0.18424500 * w;

  w = c00 * c3;
  rmix += -0.35031003 * w;
  gmix += 1.37855826 * w;
  bmix += 3.68865000 * w;

  w = c0 * c33;
  rmix += 1.05128046 * w;
  gmix += 1.97815239 * w;
  bmix += 2.82989073 * w;

  w = c11 * c2;
  rmix += 3.21607125 * w;
  gmix += 0.81270228 * w;
  bmix += 1.03384539 * w;

  w = c1 * c22;
  rmix += 2.78893374 * w;
  gmix += 0.41565549 * w;
  bmix += -0.04487295 * w;

  w = c11 * c3;
  rmix += 3.02162577 * w;
  gmix += 2.55374103 * w;
  bmix += 0.32766114 * w;

  w = c1 * c33;
  rmix += 2.95124691 * w;
  gmix += 2.81201112 * w;
  bmix += 1.17578442 * w;

  w = c22 * c3;
  rmix += 2.82677043 * w;
  gmix += 0.79933038 * w;
  bmix += 1.81715262 * w;

  w = c2 * c33;
  rmix += 2.99691099 * w;
  gmix += 1.22593053 * w;
  bmix += 1.80653661 * w;

  w = c01 * c2;
  rmix += 1.87394106 * w;
  gmix += 2.05027182 * w;
  bmix += -0.29835996 * w;

  w = c01 * c3;
  rmix += 2.56609566 * w;
  gmix += 7.03428198 * w;
  bmix += 0.62575374 * w;

  w = c02 * c3;
  rmix += 4.08329484 * w;
  gmix += -1.40408358 * w;
  bmix += 2.14995522 * w;

  w = c12 * c3;
  rmix += 6.00078678 * w;
  gmix += 2.55552042 * w;
  bmix += 1.90739502 * w;

  // Return 7D latent vector
  return [c0, c1, c2, c3, r - rmix, g - gmix, b - bmix];
}

// ============================================================================
// LATENT TO RGB CONVERSION
// ============================================================================

// Evaluates polynomial to convert 4 pigment components to RGB
List<double> _evalPolynomial(double c0, double c1, double c2, double c3) {
  double r = 0.0;
  double g = 0.0;
  double b = 0.0;

  final c00 = c0 * c0;
  final c11 = c1 * c1;
  final c22 = c2 * c2;
  final c33 = c3 * c3;
  final c01 = c0 * c1;
  final c02 = c0 * c2;
  final c12 = c1 * c2;

  double w;

  w = c0 * c00;
  r += 0.07717053 * w;
  g += 0.02826978 * w;
  b += 0.24832992 * w;

  w = c1 * c11;
  r += 0.95912302 * w;
  g += 0.80256528 * w;
  b += 0.03561839 * w;

  w = c2 * c22;
  r += 0.74683774 * w;
  g += 0.04868586 * w;
  b += 0.00000000 * w;

  w = c3 * c33;
  r += 0.99518138 * w;
  g += 0.99978149 * w;
  b += 0.99704802 * w;

  w = c00 * c1;
  r += 0.04819146 * w;
  g += 0.83363781 * w;
  b += 0.32515377 * w;

  w = c01 * c1;
  r += -0.68146950 * w;
  g += 1.46107803 * w;
  b += 1.06980936 * w;

  w = c00 * c2;
  r += 0.27058419 * w;
  g += -0.15324870 * w;
  b += 1.98735057 * w;

  w = c02 * c2;
  r += 0.80478189 * w;
  g += 0.67093710 * w;
  b += 0.18424500 * w;

  w = c00 * c3;
  r += -0.35031003 * w;
  g += 1.37855826 * w;
  b += 3.68865000 * w;

  w = c0 * c33;
  r += 1.05128046 * w;
  g += 1.97815239 * w;
  b += 2.82989073 * w;

  w = c11 * c2;
  r += 3.21607125 * w;
  g += 0.81270228 * w;
  b += 1.03384539 * w;

  w = c1 * c22;
  r += 2.78893374 * w;
  g += 0.41565549 * w;
  b += -0.04487295 * w;

  w = c11 * c3;
  r += 3.02162577 * w;
  g += 2.55374103 * w;
  b += 0.32766114 * w;

  w = c1 * c33;
  r += 2.95124691 * w;
  g += 2.81201112 * w;
  b += 1.17578442 * w;

  w = c22 * c3;
  r += 2.82677043 * w;
  g += 0.79933038 * w;
  b += 1.81715262 * w;

  w = c2 * c33;
  r += 2.99691099 * w;
  g += 1.22593053 * w;
  b += 1.80653661 * w;

  w = c01 * c2;
  r += 1.87394106 * w;
  g += 2.05027182 * w;
  b += -0.29835996 * w;

  w = c01 * c3;
  r += 2.56609566 * w;
  g += 7.03428198 * w;
  b += 0.62575374 * w;

  w = c02 * c3;
  r += 4.08329484 * w;
  g += -1.40408358 * w;
  b += 2.14995522 * w;

  w = c12 * c3;
  r += 6.00078678 * w;
  g += 2.55552042 * w;
  b += 1.90739502 * w;

  return [r, g, b];
}

// Converts 7D latent vector back to RGB
List<double> _latentToRgb(List<double> latent) {
  final rgb = _evalPolynomial(latent[0], latent[1], latent[2], latent[3]);
  return [
    _clamp01(rgb[0] + latent[4]),
    _clamp01(rgb[1] + latent[5]),
    _clamp01(rgb[2] + latent[6]),
  ];
}

// ============================================================================
// PUBLIC API
// ============================================================================

// Interpolates between two colors using Mixbox pigment mixing
//
// This function simulates real-world pigment mixing, producing natural
// and saturated color transitions with proper hue shifts.
//
// Parameters:
// - colorA: First color
// - colorB: Second color
// - t: Interpolation factor (0.0 = colorA, 1.0 = colorB)
//
// Returns: Mixed color
//
// Example:
// ```dart
// final yellow = Color(0xFFFCE300);
// final blue = Color(0xFF0021AB);
// final green = lerpMixbox(yellow, blue, 0.5); // Natural green!
// ```
Color lerpMixbox(Color colorA, Color colorB, double t) {
  // Convert colors to 0.0-1.0 range
  final r1 = colorA.red / 255.0;
  final g1 = colorA.green / 255.0;
  final b1 = colorA.blue / 255.0;

  final r2 = colorB.red / 255.0;
  final g2 = colorB.green / 255.0;
  final b2 = colorB.blue / 255.0;

  // Convert to latent space
  final latent1 = _rgbToLatent(r1, g1, b1);
  final latent2 = _rgbToLatent(r2, g2, b2);

  // Linear interpolation in latent space
  final latentMix = List<double>.filled(_latentSize, 0.0);
  for (int i = 0; i < _latentSize; i++) {
    latentMix[i] = (1.0 - t) * latent1[i] + t * latent2[i];
  }

  // Convert back to RGB
  final rgb = _latentToRgb(latentMix);

  // Interpolate alpha separately
  final alpha = ((1.0 - t) * colorA.alpha + t * colorB.alpha).round();

  // Convert to Color
  return Color.fromARGB(
    alpha,
    (rgb[0] * 255.0).round(),
    (rgb[1] * 255.0).round(),
    (rgb[2] * 255.0).round(),
  );
}
