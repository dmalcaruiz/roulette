import 'dart:math';
import 'package:flutter/material.dart';

// OKLCH shadow color derivation
//
// Derives a perceptually correct "shadow" color from any face color
// by converting to OKLCH, reducing lightness, and converting back.
// Based on the Culori library's OKLCH implementation.

// ── OKLCH → OKLab → Linear RGB → sRGB pipeline (minimal) ───────────────

Color oklchShadow(Color faceColor, {double lightnessReduction = 0.1}) {
  // sRGB → Linear RGB
  final lr = _gammaExpansion(faceColor.r);
  final lg = _gammaExpansion(faceColor.g);
  final lb = _gammaExpansion(faceColor.b);

  // Linear RGB → OKLab
  final lCone = _cubeRoot(0.412221469470763 * lr + 0.5363325372617348 * lg + 0.0514459932675022 * lb);
  final mCone = _cubeRoot(0.2119034958178252 * lr + 0.6806995506452344 * lg + 0.1073969535369406 * lb);
  final sCone = _cubeRoot(0.0883024591900564 * lr + 0.2817188391361215 * lg + 0.6299787016738222 * lb);

  final okL = 0.210454268309314 * lCone + 0.7936177747023054 * mCone - 0.0040720430116193 * sCone;
  final okA = 1.9779985324311684 * lCone - 2.4285922420485799 * mCone + 0.450593709617411 * sCone;
  final okB = 0.0259040424655478 * lCone + 0.7827717124575296 * mCone - 0.8086757549230774 * sCone;

  // OKLab → OKLCH (polar)
  final c = sqrt(okA * okA + okB * okB);
  final h = atan2(okB, okA); // keep in radians

  // Reduce lightness
  final newL = (okL - lightnessReduction).clamp(0.0, 1.0);

  // OKLCH → OKLab (back to cartesian)
  final newA = c * cos(h);
  final newB = c * sin(h);

  // OKLab → Linear RGB
  final l2 = newL + 0.3963377773761749 * newA + 0.2158037573099136 * newB;
  final m2 = newL - 0.1055613458156586 * newA - 0.0638541728258133 * newB;
  final s2 = newL - 0.0894841775298119 * newA - 1.2914855480194092 * newB;

  final l3 = l2 * l2 * l2;
  final m3 = m2 * m2 * m2;
  final s3 = s2 * s2 * s2;

  final rOut = 4.0767416360759574 * l3 - 3.3077115392580616 * m3 + 0.2309699031821044 * s3;
  final gOut = -1.2684379732850317 * l3 + 2.6097573492876887 * m3 - 0.3413193760026573 * s3;
  final bOut = -0.0041960761386756 * l3 - 0.7034186179359362 * m3 + 1.7076146940746117 * s3;

  // Linear RGB → sRGB (gamma correction + clamp)
  return Color.fromARGB(
    (faceColor.a * 255).round(),
    (_gammaCorrection(rOut).clamp(0.0, 1.0) * 255).round(),
    (_gammaCorrection(gOut).clamp(0.0, 1.0) * 255).round(),
    (_gammaCorrection(bOut).clamp(0.0, 1.0) * 255).round(),
  );
}

// ── Gamma helpers ───────────────────────────────────────────────────────

double _gammaExpansion(double channel) {
  // channel is already 0.0–1.0 from Flutter's Color.r/.g/.b
  final double abs = channel.abs();
  if (abs <= 0.04045) return channel / 12.92;
  final double sign = channel.sign != 0 ? channel.sign : 1.0;
  return sign * pow((abs + 0.055) / 1.055, 2.4).toDouble();
}

double _gammaCorrection(double channel) {
  final double abs = channel.abs();
  if (abs > 0.0031308) {
    final double sign = channel.sign != 0 ? channel.sign : 1.0;
    return sign * (1.055 * pow(abs, 1.0 / 2.4) - 0.055);
  }
  return channel * 12.92;
}

double _cubeRoot(double x) {
  return x >= 0 ? pow(x, 1.0 / 3.0).toDouble() : -pow(-x, 1.0 / 3.0).toDouble();
}
