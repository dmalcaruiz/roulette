import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'wheel_item.dart';
import 'wheel_painter.dart';

class SpinningWheel extends StatefulWidget {
  final List<WheelItem> items;
  final Function(int) onFinished;
  final double size;
  final double textSizeMultiplier; // For segment text
  final double headerTextSizeMultiplier; // For header text
  final double imageSize; // For segment images
  final double cornerRadius;
  final double strokeWidth;
  final bool showBackgroundCircle;
  final double centerMarkerSize;
  final double spinIntensity; // 0.0 to 1.0
  final bool isRandomIntensity;
  final Color headerTextColor;

  const SpinningWheel({
    super.key,
    required this.items,
    required this.onFinished,
    this.size = 300,
    this.textSizeMultiplier = 1.0,
    this.headerTextSizeMultiplier = 1.0,
    this.imageSize = 60.0,
    this.cornerRadius = 8.0,
    this.strokeWidth = 3.0,
    this.showBackgroundCircle = true,
    this.centerMarkerSize = 200.0,
    this.spinIntensity = 0.5,
    this.isRandomIntensity = true,
    this.headerTextColor = Colors.black,
  });

  @override
  State<SpinningWheel> createState() => SpinningWheelState();
}

class SpinningWheelState extends State<SpinningWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final List<AudioPlayer> _audioPool = [];
  int _currentAudioIndex = 0;
  static const int _poolSize = 100;
  bool _isSpinning = false;
  bool _isResetting = false;
  double _currentRotation = 0;
  String _currentSegment = '-';
  final List<Timer> _scheduledSounds = [];
  final Map<String, ui.Image> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _initializeAudioPool();
    _loadImages();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _controller.addListener(() {
      setState(() {
        _currentRotation = _animation.value;
        _updateCurrentSegment();
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isResetting) {
        setState(() {
          _isSpinning = false;
        });
        final winningIndex = _getWinningIndex();
        widget.onFinished(winningIndex);
      } else if (status == AnimationStatus.completed && _isResetting) {
        setState(() {
          _isResetting = false;
        });
      }
    });
  }

  Future<void> _initializeAudioPool() async {
    try {
      // Create a pool of audio players with low latency mode
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        _audioPool.add(player);
      }
    } catch (e) {
      // Ignore audio initialization errors
    }
  }

  Future<void> _loadImages() async {
    // Force an immediate repaint to show we're processing
    setState(() {});

    for (final item in widget.items) {
      if (item.imagePath != null && !_imageCache.containsKey(item.imagePath)) {
        try {
          final file = File(item.imagePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            if (mounted) {
              setState(() {
                _imageCache[item.imagePath!] = frame.image;
              });
            }
          }
        } catch (e) {
          // Ignore image loading errors
          debugPrint('Error loading image ${item.imagePath}: $e');
        }
      }
    }
  }

  @override
  void didUpdateWidget(SpinningWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload images if items changed or image paths changed
    bool itemsChanged = oldWidget.items != widget.items;
    bool imagePathsChanged = false;

    if (oldWidget.items.length == widget.items.length) {
      for (int i = 0; i < widget.items.length; i++) {
        if (oldWidget.items[i].imagePath != widget.items[i].imagePath) {
          imagePathsChanged = true;
          break;
        }
      }
    }

    if (itemsChanged || imagePathsChanged) {
      _loadImages();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var timer in _scheduledSounds) {
      timer.cancel();
    }
    for (var player in _audioPool) {
      player.dispose();
    }
    super.dispose();
  }

  void _playClickSoundFromPool() {
    if (_audioPool.isEmpty) return;

    try {
      final player = _audioPool[_currentAudioIndex];
      // Play from source - low latency mode makes this fast
      player.play(AssetSource('audio/click.mp3'), volume: 1.0);
      _currentAudioIndex = (_currentAudioIndex + 1) % _audioPool.length;
    } catch (e) {
      // Ignore audio errors
    }
  }

  void _updateCurrentSegment() {
    final totalWeight = widget.items.fold<double>(0.0, (sum, item) => sum + item.weight);
    // Adjust for pointer at top (subtract π/2 to convert from right-side reference to top reference)
    final currentAngle = (2 * pi - (_currentRotation % (2 * pi)) - pi / 2) % (2 * pi);
    double accumulatedWeight = 0;

    for (final item in widget.items) {
      accumulatedWeight += item.weight;
      final segmentEnd = (accumulatedWeight / totalWeight) * 2 * pi;

      if (currentAngle <= segmentEnd) {
        _currentSegment = item.text;
        break;
      }
    }
  }

  int _getRandomWeightedIndex() {
    final totalWeight = widget.items.fold<double>(0.0, (sum, item) => sum + item.weight);
    double random = Random().nextDouble() * totalWeight;
    double accumulatedWeight = 0;

    for (int i = 0; i < widget.items.length; i++) {
      accumulatedWeight += widget.items[i].weight;
      if (random < accumulatedWeight) {
        return i;
      }
    }
    return widget.items.length - 1;
  }

  int _getWinningIndex() {
    final totalWeight = widget.items.fold<double>(0.0, (sum, item) => sum + item.weight);
    // Adjust for pointer at top (subtract π/2 to convert from right-side reference to top reference)
    final finalAngle = (2 * pi - (_currentRotation % (2 * pi)) - pi / 2) % (2 * pi);
    double accumulatedWeight = 0;

    for (int i = 0; i < widget.items.length; i++) {
      accumulatedWeight += widget.items[i].weight;
      final segmentEnd = (accumulatedWeight / totalWeight) * 2 * pi;

      if (finalAngle <= segmentEnd) {
        return i;
      }
    }
    return widget.items.length - 1;
  }

  void _preScheduleSounds(double startRotation, double finalRotation, Duration duration) {
    // Cancel any previously scheduled sounds
    for (var timer in _scheduledSounds) {
      timer.cancel();
    }
    _scheduledSounds.clear();

    final totalWeight = widget.items.fold<double>(0.0, (sum, item) => sum + item.weight);
    final curve = Curves.easeOutCubic;

    // Sample the animation at regular intervals to detect segment changes
    const int samples = 200;
    String? lastSegment;

    for (int i = 0; i <= samples; i++) {
      final progress = i / samples;
      final easedProgress = curve.transform(progress);
      final currentRotation = startRotation + (easedProgress * finalRotation);

      // Calculate which segment we're on
      // Adjust for pointer at top (subtract π/2 to convert from right-side reference to top reference)
      final currentAngle = (2 * pi - (currentRotation % (2 * pi)) - pi / 2) % (2 * pi);
      double accumulatedWeight = 0;
      String? currentSegment;

      for (final item in widget.items) {
        accumulatedWeight += item.weight;
        final segmentEnd = (accumulatedWeight / totalWeight) * 2 * pi;

        if (currentAngle <= segmentEnd) {
          currentSegment = item.text;
          break;
        }
      }

      // If segment changed, schedule a sound at this time
      if (currentSegment != null && currentSegment != lastSegment && lastSegment != null) {
        final delay = Duration(milliseconds: (progress * duration.inMilliseconds).round());
        final timer = Timer(delay, _playClickSoundFromPool);
        _scheduledSounds.add(timer);
      }

      lastSegment = currentSegment;
    }
  }

  void reset() {
    // Cancel any scheduled sounds
    for (var timer in _scheduledSounds) {
      timer.cancel();
    }
    _scheduledSounds.clear();

    // Stop current animation
    _controller.stop();

    // Get current rotation for smooth animation
    final currentRotation = _currentRotation;

    setState(() {
      _isSpinning = false;
      _isResetting = true;
    });

    // Find the closest full rotation (multiple of 2π)
    final fullRotation = 2 * pi;
    final numRotations = (currentRotation / fullRotation).round();
    final closestRotation = numRotations * fullRotation;

    // If we're already at the closest point, just update the display
    if ((currentRotation - closestRotation).abs() < 0.01) {
      setState(() {
        _currentSegment = '-';
        _isResetting = false;
      });
      return;
    }

    // Animate to closest full rotation
    _controller.duration = const Duration(milliseconds: 500);
    _animation = Tween<double>(
      begin: currentRotation,
      end: closestRotation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward(from: 0);
  }

  void spin() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    final winningIndex = _getRandomWeightedIndex();
    final totalWeight = widget.items.fold<double>(0.0, (sum, item) => sum + item.weight);
    final arcSize = (2 * pi) / totalWeight;

    // Calculate winning angle
    double winningAngle = 0;
    final winningSegmentSize = arcSize * widget.items[winningIndex].weight;

    for (int i = 0; i < widget.items.length; i++) {
      winningAngle += arcSize * widget.items[i].weight;
      if (i == winningIndex) {
        break;
      }
    }

    // Calculate intensity-based values
    final double effectiveIntensity;
    if (widget.isRandomIntensity) {
      // Fully random
      effectiveIntensity = Random().nextDouble();
    } else {
      // Use slider value with ±20% randomness
      final randomOffset = (Random().nextDouble() - 0.5) * 0.4; // -0.2 to +0.2
      effectiveIntensity = (widget.spinIntensity + randomOffset).clamp(0.0, 1.0);
    }

    // Calculate pullback amount based on intensity (in radians)
    // Low intensity: ~10-15 degrees, High intensity: ~30-45 degrees
    final basePullback = (10 + effectiveIntensity * 35) * (pi / 180); // Convert degrees to radians
    final pullbackVariation = (Random().nextDouble() - 0.5) * 10 * (pi / 180); // ±5 degrees variation
    final pullbackAmount = basePullback + pullbackVariation;

    // Intensity affects rotations (1-5 based on intensity)
    final baseRotations = 1 + (effectiveIntensity * 4).floor();
    final totalRotations = baseRotations + Random().nextDouble();

    // Random offset within the winning segment
    final offset = Random().nextDouble() * winningSegmentSize;

    // Calculate final rotation
    final finalRotation = totalRotations * 2 * pi + (2 * pi - winningAngle + offset);

    // Intensity affects duration (2-6 seconds based on intensity)
    final baseDuration = 2000 + (effectiveIntensity * 4000).toInt();
    final randomDurationOffset = Random().nextInt(500) - 250;
    final mainDuration = Duration(milliseconds: baseDuration + randomDurationOffset);

    // Start with pullback animation
    final pullbackDuration = Duration(milliseconds: 200 + (effectiveIntensity * 100).toInt()); // 200-300ms based on intensity
    _controller.duration = pullbackDuration;

    _animation = Tween<double>(
      begin: _currentRotation,
      end: _currentRotation - pullbackAmount, // Pull back (negative rotation)
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Listen for pullback completion to start main spin
    void pullbackListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _controller.removeStatusListener(pullbackListener);

        // Start main spin from pullback position
        final pullbackPosition = _currentRotation;
        _controller.duration = mainDuration;

        _animation = Tween<double>(
          begin: pullbackPosition,
          end: pullbackPosition + pullbackAmount + finalRotation, // Add back the pullback, then spin forward
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ));

        // Pre-schedule all audio clicks based on segment changes
        _preScheduleSounds(pullbackPosition, pullbackAmount + finalRotation, mainDuration);

        _controller.forward(from: 0);
      }
    }

    _controller.addStatusListener(pullbackListener);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.size / 16;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _currentSegment,
          style: TextStyle(
            fontSize: 56 * widget.headerTextSizeMultiplier,
            fontWeight: FontWeight.w600,
            color: widget.headerTextColor,
          ),
        ),
        const SizedBox(height: 16),
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: GestureDetector(
                onTap: spin,
                child: CustomPaint(
                  painter: WheelPainter(
                    items: widget.items,
                    rotation: _currentRotation,
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontSize: (widget.items.length >= 16 ? 24 : fontSize) * widget.textSizeMultiplier,
                      fontWeight: FontWeight.w600,
                    ),
                    cornerRadius: widget.cornerRadius,
                    strokeWidth: widget.strokeWidth,
                    showBackgroundCircle: widget.showBackgroundCircle,
                    imageSize: widget.imageSize,
                    imageCache: _imageCache,
                  ),
                ),
              ),
            ),
            // Center SVG Marker with shadow
            SizedBox(
              width: widget.centerMarkerSize,
              height: widget.centerMarkerSize,
              child: Stack(
                children: [
                  // Shadow layer - blurred and offset (scales with marker size)
                  Positioned(
                    top: widget.centerMarkerSize * 0.02,
                    left: widget.centerMarkerSize * 0.01,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: widget.centerMarkerSize * 0.04,
                        sigmaY: widget.centerMarkerSize * 0.04,
                      ),
                      child: Opacity(
                        opacity: 0.4,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.black,
                            BlendMode.srcIn,
                          ),
                          child: SvgPicture.asset(
                            'assets/images/Marker.svg',
                            width: widget.centerMarkerSize,
                            height: widget.centerMarkerSize,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Actual SVG on top
                  SvgPicture.asset(
                    'assets/images/Marker.svg',
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

