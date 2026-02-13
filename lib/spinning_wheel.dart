import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final Color overlayColor;
  final bool showWinAnimation;
  final double headerOpacity;
  final double headerSizeProgress;

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
    this.overlayColor = Colors.black,
    this.showWinAnimation = true,
    this.headerOpacity = 1.0,
    this.headerSizeProgress = 1.0,
  });

  @override
  State<SpinningWheel> createState() => SpinningWheelState();
}

class SpinningWheelState extends State<SpinningWheel>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _overlayController;
  late Animation<double> _animation;
  late Animation<double> _overlayAnimation;
  final List<AudioPlayer> _audioPool = [];
  int _currentAudioIndex = 0;
  static const int _poolSize = 300;
  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;
  bool _isResetting = false;
  bool _isPullingBack = false;
  double _currentRotation = 0;
  final ValueNotifier<String> _currentSegmentNotifier = ValueNotifier('');
  final List<Timer> _scheduledSounds = [];
  final Map<String, ui.Image> _imageCache = {};
  Timer? _imageRetryTimer;
  late AnimationController _loadingController;
  late final Listenable _repaintNotifier;
  final ValueNotifier<int> _repaintVersion = ValueNotifier<int>(0);
  late WheelPainter _wheelPainter;

  @override
  void initState() {
    super.initState();
    // Defer audio init so it doesn't block early frames / first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAudioPool();
    });

    // 1. Create all animation controllers
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _overlayAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeInOut,
    ));

    // 2. Merge all animation sources into one repaint notifier
    _repaintNotifier = Listenable.merge([
      _controller, _overlayController, _loadingController, _repaintVersion,
    ]);

    // 3. Create persistent wheel painter (uses repaint notifier for animation)
    _wheelPainter = _createWheelPainter();

    // 4. Start image loading
    _startImageLoading();

    // 5. Set up listeners that update painter's mutable fields directly
    _loadingController.addListener(() {
      _wheelPainter.loadingAngle = _loadingController.value * 2 * pi;
    });

    _controller.addListener(() {
      _currentRotation = _animation.value;
      _wheelPainter.rotation = _currentRotation;
      _updateCurrentSegment();

    });

    _overlayController.addListener(() {
      _wheelPainter.overlayOpacity = _overlayAnimation.value;
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isResetting && !_isPullingBack) {
        final winningIndex = _getWinningIndex();
        _wheelPainter.winningIndex = winningIndex;
        setState(() {
          _isSpinning = false;
        });

        if (widget.showWinAnimation) {
          _overlayController.forward().then((_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _overlayController.reverse().then((_) {
                  if (mounted) {
                    _wheelPainter.winningIndex = -1;
                  }
                });
              }
            });
          });
        }

        widget.onFinished(winningIndex);
      } else if (status == AnimationStatus.completed && _isResetting) {
        setState(() {
          _isResetting = false;
        });
      }
    });
  }

  WheelPainter _createWheelPainter() {
    final fontSize = widget.size / 16;
    return WheelPainter(
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
      overlayColor: widget.overlayColor,
      textVerticalOffset: widget.size / 700 * 2,
      repaint: _repaintNotifier,
    );
  }

  Future<void> _initializeAudioPool() async {
    // Disable audio on web - too laggy
    if (kIsWeb) return;

    try {
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        _audioPool.add(player);
      }
    } catch (e) {
      // Ignore audio initialization errors
    }
  }

  void _startImageLoading() {
    _imageRetryTimer?.cancel();
    _loadImagesWithRetry();
  }

  void _loadImagesWithRetry() {
    if (!mounted) return;

    // Check if there are pending images before attempting load
    final hasPending = widget.items.any(
      (item) => item.imagePath != null && !_imageCache.containsKey(item.imagePath),
    );

    if (!hasPending) {
      _loadingController.stop();
      _imageRetryTimer = null;
      return;
    }

    // Start loading spinner if not already running
    if (!_loadingController.isAnimating) {
      _loadingController.repeat();
    }

    // Attempt to load images, then schedule next retry
    _tryLoadImages().then((_) {
      if (!mounted) return;

      final stillPending = widget.items.any(
        (item) => item.imagePath != null && !_imageCache.containsKey(item.imagePath),
      );

      if (stillPending) {
        _imageRetryTimer = Timer(const Duration(milliseconds: 300), _loadImagesWithRetry);
      } else {
        _loadingController.stop();
        _imageRetryTimer = null;
        // Trigger repaint to show newly loaded images
        _repaintVersion.value++;
      }
    });
  }

  Future<void> _tryLoadImages() async {
    if (!mounted) return;

    for (final item in widget.items) {
      if (item.imagePath != null && !_imageCache.containsKey(item.imagePath)) {
        try {
          // Load images on native platforms only (web doesn't support file paths)
          if (!kIsWeb) {
            final file = File(item.imagePath!);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              if (mounted) {
                _imageCache[item.imagePath!] = frame.image;
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading image ${item.imagePath}: $e');
        }
      }
    }
  }

  @override
  void didUpdateWidget(SpinningWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool itemsChanged = oldWidget.items != widget.items;
    bool imagePathsChanged = false;
    bool configChanged = oldWidget.textSizeMultiplier != widget.textSizeMultiplier ||
        oldWidget.size != widget.size ||
        oldWidget.cornerRadius != widget.cornerRadius ||
        oldWidget.strokeWidth != widget.strokeWidth ||
        oldWidget.showBackgroundCircle != widget.showBackgroundCircle ||
        oldWidget.imageSize != widget.imageSize ||
        oldWidget.overlayColor != widget.overlayColor;

    if (oldWidget.items.length == widget.items.length) {
      for (int i = 0; i < widget.items.length; i++) {
        if (oldWidget.items[i].imagePath != widget.items[i].imagePath) {
          imagePathsChanged = true;
          break;
        }
      }
    }

    if (itemsChanged || configChanged) {
      _wheelPainter = _createWheelPainter();
    }

    if (itemsChanged || imagePathsChanged) {
      _startImageLoading();
    }
  }

  @override
  void dispose() {
    _imageRetryTimer?.cancel();
    _currentSegmentNotifier.dispose();
    _repaintVersion.dispose();
    _loadingController.dispose();
    _controller.dispose();
    _overlayController.dispose();
    for (var player in _audioPool) {
      player.dispose();
    }
    super.dispose();
  }

  void _playClickSoundFromPool() {
    if (_audioPool.isEmpty) return;

    try {
      final player = _audioPool[_currentAudioIndex];
      _currentAudioIndex = (_currentAudioIndex + 1) % _audioPool.length;
      // play() handles all state management internally - no manual seek/resume needed
      player.play(AssetSource('audio/click.mp3')).catchError((_) {});
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
        _currentSegmentNotifier.value = item.text;
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
    // Disable audio on web - too laggy
    if (kIsWeb) return;

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
    _overlayController.stop();

    // Get current rotation for smooth animation
    final currentRotation = _currentRotation;

    _wheelPainter.winningIndex = -1;
    _wheelPainter.overlayOpacity = 0.0;
    setState(() {
      _isSpinning = false;
      _isResetting = true;
      _isPullingBack = false;
    });

    // Reset overlay controller
    _overlayController.reset();

    // Find the closest full rotation (multiple of 2π)
    final fullRotation = 2 * pi;
    final numRotations = (currentRotation / fullRotation).round();
    final closestRotation = numRotations * fullRotation;

    // If we're already at the closest point, just update the display
    if ((currentRotation - closestRotation).abs() < 0.01) {
      _currentSegmentNotifier.value = '';
      setState(() {
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
      _isPullingBack = true;
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
      // Use slider value with minimal randomness (±3%) for more predictable spins
      final randomOffset = (Random().nextDouble() - 0.5) * 0.06; // -0.03 to +0.03
      effectiveIntensity = (widget.spinIntensity + randomOffset).clamp(0.0, 1.0);
    }

    // Calculate pullback amount based on intensity (in radians)
    final double basePullback;
    final double pullbackVariation;
    if (widget.isRandomIntensity) {
      // Original range: 10-45 degrees
      basePullback = (10 + effectiveIntensity * 35) * (pi / 180);
      pullbackVariation = (Random().nextDouble() - 0.5) * 10 * (pi / 180); // ±5 degrees variation
    } else {
      // Dramatic range: 5-50 degrees for more obvious difference
      basePullback = (5 + effectiveIntensity * 45) * (pi / 180);
      pullbackVariation = (Random().nextDouble() - 0.5) * 2 * (pi / 180); // ±1 degree variation
    }
    final pullbackAmount = basePullback + pullbackVariation;

    // Intensity affects rotations
    final int baseRotations;
    final double totalRotations;
    if (widget.isRandomIntensity) {
      // Original range: 1-5 rotations
      baseRotations = 1 + (effectiveIntensity * 4).floor();
      totalRotations = baseRotations + Random().nextDouble();
    } else {
      // Dramatic range: 1-7 rotations for more obvious difference
      baseRotations = 1 + (effectiveIntensity * 6).floor();
      totalRotations = baseRotations + Random().nextDouble() * 0.2; // Less variation
    }

    // Random offset within the winning segment
    final offset = Random().nextDouble() * winningSegmentSize;

    // Calculate final rotation
    final finalRotation = totalRotations * 2 * pi + (2 * pi - winningAngle + offset);

    // Intensity affects duration
    final int baseDuration;
    final int randomDurationOffset;
    if (widget.isRandomIntensity) {
      // Original range: 2-6 seconds
      baseDuration = 2000 + (effectiveIntensity * 4000).toInt();
      randomDurationOffset = Random().nextInt(500) - 250; // ±250ms variation
    } else {
      // Dramatic range: 1.5-7 seconds for more obvious difference
      baseDuration = 1500 + (effectiveIntensity * 5500).toInt();
      randomDurationOffset = Random().nextInt(100) - 50; // ±50ms variation
    }
    final mainDuration = Duration(milliseconds: baseDuration + randomDurationOffset);

    // Start with pullback animation
    final int pullbackDurationMs;
    if (widget.isRandomIntensity) {
      // Original range: 200-300ms
      pullbackDurationMs = 200 + (effectiveIntensity * 100).toInt();
    } else {
      // Dramatic range: 150-350ms
      pullbackDurationMs = 150 + (effectiveIntensity * 200).toInt();
    }
    final pullbackDuration = Duration(milliseconds: pullbackDurationMs);
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

        setState(() {
          _isPullingBack = false;
        });

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: widget.headerOpacity,
          child: SizedBox(
            height: (56 * widget.headerTextSizeMultiplier + 16) * widget.headerSizeProgress,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ValueListenableBuilder<String>(
                valueListenable: _currentSegmentNotifier,
                builder: (context, segment, _) {
                  return Text(
                    segment,
                    style: TextStyle(
                      fontSize: 56 * widget.headerTextSizeMultiplier,
                      fontWeight: FontWeight.w700,
                      color: widget.headerTextColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: 16 * widget.headerSizeProgress),
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: spin,
                child: CustomPaint(
                  painter: _wheelPainter,
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

