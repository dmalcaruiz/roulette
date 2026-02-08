import 'dart:typed_data';
import 'package:icc_parser/icc_parser.dart';

// Singleton manager for ICC profile color transformations
//
// Provides real-time display filtering to show how colors appear
// when printed on Canon ImagePROGRAPH PRO-1000.
//
// Architecture: Surface-level filter
// - State stores IDEAL colors (full sRGB space)
// - Transform happens only at display time
// - Graceful fallback if profile fails to load
class IccColorManager {
  // ==================== Singleton Pattern ====================

  static IccColorManager? _instance;

  static IccColorManager get instance {
    _instance ??= IccColorManager._();
    return _instance!;
  }

  IccColorManager._();

  // ==================== State ====================

  ColorProfile? _profile;
  ColorProfileCmm? _forwardCmm;
  ColorProfileCmm? _reverseCmm;
  List<ColorProfileTransform>? _forwardTransforms;
  List<ColorProfileTransform>? _reverseTransforms;
  bool _isInitialized = false;

  // ==================== Initialization ====================

  // Initialize ICC profile from bytes
  //
  // Returns true if successful, false otherwise.
  // App continues normally even if this fails.
  Future<bool> initialize(Uint8List profileBytes) async {
    try {
      // Parse ICC profile using icc_parser package
      final stream = DataStream(
        data: ByteData.view(profileBytes.buffer),
        offset: 0,
        length: profileBytes.lengthInBytes,
      );

      _profile = ColorProfile.fromBytes(stream);

      // Create round-trip transform for gamut mapping:
      // Forward: Lab → CMYK (printer input, shows what's printable)
      // Reverse: CMYK → Lab (convert back for display)

      // Forward transform: Lab to CMYK (isInput: false = output to device)
      final forwardTransform = ColorProfileTransform.create(
        profile: _profile!,
        isInput: false, // This is an OUTPUT profile (printer)
        intent: ColorProfileRenderingIntent.perceptual,
        interpolation: ColorProfileInterpolation.tetrahedral,
        lutType: ColorProfileTransformLutType.color,
        useD2BTags: true,
      );

      // Reverse transform: CMYK to Lab (isInput: true = input from device)
      final reverseTransform = ColorProfileTransform.create(
        profile: _profile!,
        isInput: true, // Reading from the printer's color space
        intent: ColorProfileRenderingIntent.perceptual,
        interpolation: ColorProfileInterpolation.tetrahedral,
        lutType: ColorProfileTransformLutType.color,
        useD2BTags: true,
      );

      _forwardTransforms = [forwardTransform];
      _reverseTransforms = [reverseTransform];
      _forwardCmm = ColorProfileCmm();
      _reverseCmm = ColorProfileCmm();

      _isInitialized = true;
      return true;

    } catch (e) {
      // ICC Profile initialization failed - app continues with sRGB-only mode
      _isInitialized = false;
      return false;
    }
  }

  // ==================== Core Transformation API ====================

  // Transform single Lab color to ICC gamut-mapped Lab
  //
  // This is the DISPLAY FILTER - it doesn't modify state!
  //
  // Performs a round-trip transform:
  // Lab → CMYK (via printer profile) → Lab (back to display)
  //
  // Returns:
  // - Gamut-mapped Lab values if initialized
  // - Original values if not initialized (graceful fallback)
  List<double> transformLab(double L, double a, double b) {
    if (!_isInitialized ||
        _forwardCmm == null ||
        _reverseCmm == null ||
        _forwardTransforms == null ||
        _reverseTransforms == null) {
      return [L, a, b]; // Fallback: no transformation
    }

    try {
      // Step 1: Build the transformations
      final forward = _forwardCmm!.buildTransformations(_forwardTransforms!);
      final reverse = _reverseCmm!.buildTransformations(_reverseTransforms!);

      // Step 2: Normalize Lab values to 0-1 range for ICC parser
      // L: 0-100 → 0-1
      // a: -128 to +127 → 0-1
      // b: -128 to +127 → 0-1
      final normalizedL = L / 100.0;
      final normalizedA = (a + 128.0) / 255.0;
      final normalizedB = (b + 128.0) / 255.0;

      // Step 3: Convert Lab to CMYK (what the printer can produce)
      final labInput = Float64List.fromList([normalizedL, normalizedA, normalizedB]);
      final cmykOutput = _forwardCmm!.apply(forward, labInput);

      // Step 4: Convert CMYK back to Lab (what it looks like)
      final labOutputNormalized = _reverseCmm!.apply(reverse, cmykOutput);

      // Step 5: Denormalize Lab values from 0-1 back to standard ranges
      final outputL = labOutputNormalized[0] * 100.0;
      final outputA = labOutputNormalized[1] * 255.0 - 128.0;
      final outputB = labOutputNormalized[2] * 255.0 - 128.0;

      return [outputL, outputA, outputB];

    } catch (e) {
      // ICC transform error - fallback to original values
      return [L, a, b];
    }
  }

  // Batch transform multiple Lab colors (optimized for gradients)
  //
  // Used for rendering slider gradients efficiently.
  // Transforms 300 colors for each gradient in real-time.
  List<List<double>> transformLabBatch(List<List<double>> colors) {
    if (!_isInitialized ||
        _forwardCmm == null ||
        _reverseCmm == null ||
        _forwardTransforms == null ||
        _reverseTransforms == null) {
      return colors; // Fallback: no transformation
    }

    try {
      final forward = _forwardCmm!.buildTransformations(_forwardTransforms!);
      final reverse = _reverseCmm!.buildTransformations(_reverseTransforms!);

      return colors.map((color) {
        // Normalize Lab values to 0-1 range
        final normalizedL = color[0] / 100.0;
        final normalizedA = (color[1] + 128.0) / 255.0;
        final normalizedB = (color[2] + 128.0) / 255.0;

        // Round-trip: Lab → CMYK → Lab
        final labInput = Float64List.fromList([normalizedL, normalizedA, normalizedB]);
        final cmykOutput = _forwardCmm!.apply(forward, labInput);
        final labOutputNormalized = _reverseCmm!.apply(reverse, cmykOutput);

        // Denormalize back to Lab ranges
        final outputL = labOutputNormalized[0] * 100.0;
        final outputA = labOutputNormalized[1] * 255.0 - 128.0;
        final outputB = labOutputNormalized[2] * 255.0 - 128.0;

        return [outputL, outputA, outputB];
      }).toList();

    } catch (e) {
      // ICC batch transform error - fallback to original colors
      return colors;
    }
  }

  // ==================== Status & Info ====================

  // Check if manager is ready for transformations
  bool get isReady => _isInitialized;

  // Get profile info for debugging
  Map<String, dynamic> getProfileInfo() {
    if (!_isInitialized || _profile == null) {
      return {
        'status': 'not_initialized',
        'message': 'Toggle will have no effect',
      };
    }

    return {
      'status': 'initialized',
      'profile': 'Canon ImagePROGRAPH PRO-1000',
      'ready': _isInitialized,
    };
  }

  // Clean up resources
  void dispose() {
    _profile = null;
    _forwardCmm = null;
    _reverseCmm = null;
    _forwardTransforms = null;
    _reverseTransforms = null;
    _isInitialized = false;
  }
}
