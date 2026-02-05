import 'dart:async';
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
  final double textSizeMultiplier;
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
  double _currentRotation = 0;
  String _currentSegment = '-';
  final List<Timer> _scheduledSounds = [];

  @override
  void initState() {
    super.initState();
    _initializeAudioPool();

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
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSpinning = false;
        });
        final winningIndex = _getWinningIndex();
        widget.onFinished(winningIndex);
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
    if (_isSpinning) return;

    setState(() {
      _currentRotation = 0;
      _currentSegment = '-';
      _updateCurrentSegment();
    });
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
    final duration = Duration(milliseconds: baseDuration + randomDurationOffset);
    _controller.duration = duration;

    _animation = Tween<double>(
      begin: _currentRotation,
      end: _currentRotation + finalRotation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic, // Matches the easing in the Angular version
    ));

    // Pre-schedule all audio clicks based on segment changes
    _preScheduleSounds(_currentRotation, finalRotation, duration);

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
            fontSize: 56 * widget.textSizeMultiplier,
            fontWeight: FontWeight.bold,
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
                      fontWeight: FontWeight.bold,
                    ),
                    cornerRadius: widget.cornerRadius,
                    strokeWidth: widget.strokeWidth,
                    showBackgroundCircle: widget.showBackgroundCircle,
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

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path()
      ..moveTo(size.width / 2 - 40, 4)
      ..lineTo(size.width / 2 + 40, 4)
      ..lineTo(size.width / 2, 80)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(PointerPainter oldDelegate) => false;
}
