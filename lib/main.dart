import 'dart:async';
import 'dart:math' show min, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'spinning_wheel.dart';
import 'wheel_item.dart';
import 'wheel_config.dart';
import 'wheel_manager.dart';
import 'wheel_editor.dart';
import 'push_down_button.dart';
import 'swipeable_action_cell.dart';
import 'color_utils.dart';

String _colorToHex(Color c) {
  return '${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
}

Color? _hexToColor(String s) {
  final hex = s.trim().replaceFirst(RegExp(r'^#'), '');
  if (hex.length != 6 || !RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hex)) return null;
  final n = int.tryParse(hex, radix: 16);
  if (n == null) return null;
  return Color(0xFF000000 | n);
}

void main() {
  // Global error handler to prevent crashes from rendering assertions
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error but don't crash the app
    FlutterError.presentError(details);
    debugPrint('Flutter Error (handled): ${details.exception}');
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // -- Design tokens --
  static const _primary = Color(0xFF38BDF8); // bright light blue
  static const _primaryDark = Color(0xFF0EA5E9);
  static const _surface = Colors.white;
  static const _onSurface = Color(0xFF1E1E2C);
  static const _border = Color(0xFFD4D4D8);
  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme.copyWith(
        headlineLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _onSurface),
        headlineMedium: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _onSurface),
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _onSurface),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _onSurface),
        bodyLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface),
        bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _onSurface),
        labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _onSurface),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Spinning Wheel',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: textTheme,
        colorScheme: ColorScheme.light(
          primary: _primary,
          onPrimary: Colors.white,
          secondary: _primaryDark,
          surface: _surface,
          onSurface: _onSurface,
          outline: _border,
        ),
        scaffoldBackgroundColor: _surface,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: const BorderSide(color: _border, width: 1.5),
          ),
          color: _surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F8F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
          labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _onSurface.withValues(alpha: 0.6)),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: _onSurface,
          inactiveTrackColor: _onSurface.withValues(alpha: 0.15),
          thumbColor: _onSurface,
          overlayColor: _onSurface.withValues(alpha: 0.10),
          valueIndicatorColor: _onSurface,
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _onSurface,
            side: const BorderSide(color: _border, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return _primary;
            return Colors.transparent;
          }),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          side: const BorderSide(color: _border, width: 2),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _onSurface,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          elevation: 0,
        ),
        tabBarTheme: TabBarThemeData(
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          labelColor: _onSurface,
          unselectedLabelColor: _onSurface.withValues(alpha: 0.45),
          indicatorColor: _primary,
          indicatorSize: TabBarIndicatorSize.tab,
        ),
      ),
      home: const WheelDemo(),
    );
  }
}

class WheelDemo extends StatefulWidget {
  const WheelDemo({super.key});

  @override
  State<WheelDemo> createState() => _WheelDemoState();
}

class _WheelDemoState extends State<WheelDemo> {
  Color _backgroundColor = Colors.black;
  Color _textColor = Colors.black;
  Color _overlayColor = Colors.black;
  final WheelManager _wheelManager = WheelManager();
  List<WheelConfig> _savedWheels = [];
  WheelConfig? _currentWheel;
  bool _isLoading = true;

  // Left panel state
  String _leftPanelView = 'manager'; // 'manager', 'current_wheel', 'new_wheel'
  WheelConfig? _editingWheel;
  WheelConfig? _previewWheel; // For real-time preview while editing
  Timer? _autoSaveTimer;

  // Spin intensity controls
  double _spinIntensity = 0.5;
  bool _isRandomIntensity = true;
  bool _showWinAnimation = true;
  final GlobalKey<SpinningWheelState> _wheelKey = GlobalKey<SpinningWheelState>();

  // Snapping sheet controls (mobile)
  final SnappingSheetController _snappingSheetController = SnappingSheetController();
  final ScrollController _sheetScrollController = ScrollController();
  final ValueNotifier<double> _currentSheetHeight = ValueNotifier(0.0);
  static const double _grabbingHeight = 30.0;
  static const double _bottomControlsHeight = 60.0;

  // Preset templates (mutable for reordering)
  final List<WheelConfig> _presets = [
    WheelConfig(
      id: 'preset_equal',
      name: 'Equal Prizes',
      items: const [
        WheelItem(text: 'Prize 1', color: Colors.red, weight: 1),
        WheelItem(text: 'Prize 2', color: Colors.blue, weight: 1),
        WheelItem(text: 'Prize 3', color: Colors.green, weight: 1),
        WheelItem(text: 'Prize 4', color: Colors.orange, weight: 1),
        WheelItem(text: 'Prize 5', color: Colors.purple, weight: 1),
        WheelItem(text: 'Prize 6', color: Colors.teal, weight: 1),
        WheelItem(text: 'Prize 7', color: Colors.pink, weight: 1),
        WheelItem(text: 'Prize 8', color: Colors.amber, weight: 1),
      ],
      textSize: 1.0,
      headerTextSize: 1.0,
      imageSize: 60.0,
    ),
    WheelConfig(
      id: 'preset_weighted',
      name: 'Weighted Rarity',
      items: const [
        WheelItem(text: 'Common', color: Colors.grey, weight: 5),
        WheelItem(text: 'Uncommon', color: Colors.green, weight: 3),
        WheelItem(text: 'Rare', color: Colors.blue, weight: 2),
        WheelItem(text: 'Epic', color: Colors.purple, weight: 1),
        WheelItem(text: 'Legendary', color: Colors.orange, weight: 0.5),
      ],
      textSize: 1.0,
      headerTextSize: 1.0,
      imageSize: 60.0,
    ),
    WheelConfig(
      id: 'preset_yesno',
      name: 'Yes/No',
      items: const [
        WheelItem(text: 'Yes', color: Colors.green, weight: 1),
        WheelItem(text: 'No', color: Colors.red, weight: 1),
      ],
      textSize: 1.0,
      headerTextSize: 1.0,
      imageSize: 60.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeFirstLaunch();
    _loadWheels();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _currentSheetHeight.dispose();
    super.dispose();
  }

  Future<void> _initializeFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('first_launch') ?? true;

    if (isFirstLaunch) {
      // Copy all templates to saved wheels on first launch
      for (final template in _presets) {
        await _wheelManager.saveWheel(template);
      }
      await prefs.setBool('first_launch', false);
    }
  }

  Future<void> _loadWheels() async {
    final wheels = await _wheelManager.loadWheels();

    // Load saved wheel order
    final prefs = await SharedPreferences.getInstance();
    final wheelOrder = prefs.getStringList('wheel_order') ?? [];

    // Sort wheels based on saved order
    if (wheelOrder.isNotEmpty) {
      wheels.sort((a, b) {
        final indexA = wheelOrder.indexOf(a.id);
        final indexB = wheelOrder.indexOf(b.id);
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
    }

    setState(() {
      _savedWheels = wheels;
      // If no saved wheels, start with first preset
      _currentWheel = wheels.isNotEmpty ? wheels.first : _presets.first;
      _isLoading = false;
    });
  }

  Future<void> _reorderSavedWheels(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final wheel = _savedWheels.removeAt(oldIndex);
      _savedWheels.insert(newIndex, wheel);
    });

    // Save the new order
    final prefs = await SharedPreferences.getInstance();
    final wheelOrder = _savedWheels.map((w) => w.id).toList();
    await prefs.setStringList('wheel_order', wheelOrder);
  }

  void _onWheelFinished(int index) {
    // Callback when wheel finishes spinning
  }

  void _openColorPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      isScrollControlled: true,
      builder: (context) => _ColorPickerSheet(
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        overlayColor: _overlayColor,
        onBackgroundColorChanged: (color) {
          setState(() {
            _backgroundColor = color;
          });
        },
        onTextColorChanged: (color) {
          setState(() {
            _textColor = color;
          });
        },
        onOverlayColorChanged: (color) {
          setState(() {
            _overlayColor = color;
          });
        },
      ),
    );
  }

  void _openWheelsScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _WheelsScreen(
            savedWheels: _savedWheels,
            currentWheel: _currentWheel,
            onWheelSelected: (wheel) {
              setState(() {
                _currentWheel = wheel;
                _previewWheel = null;
                _editingWheel = null;
              });
            },
            onDuplicateWheel: _duplicateWheel,
            onDeleteWheel: _deleteWheel,
            onReorderWheels: _reorderSavedWheels,
            onCreateNewWheel: _createNewWheel,
            buildWheelCard: _buildWheelCard,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  void _openGearMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D4D8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Spin Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              // Random intensity toggle
              _gearToggleRow(
                'Random Intensity',
                LucideIcons.shuffle,
                _isRandomIntensity,
                (v) {
                  setSheetState(() => _isRandomIntensity = v);
                  setState(() => _isRandomIntensity = v);
                },
              ),
              const SizedBox(height: 12),
              // Intensity slider (only when not random)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: !_isRandomIntensity
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Intensity',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _spinIntensity,
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                label: '${(_spinIntensity * 100).round()}%',
                                onChanged: (value) {
                                  setSheetState(() => _spinIntensity = value);
                                  setState(() => _spinIntensity = value);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${(_spinIntensity * 100).round()}%',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // Win effects toggle
              _gearToggleRow(
                'Win Effects',
                LucideIcons.sparkles,
                _showWinAnimation,
                (v) {
                  setSheetState(() => _showWinAnimation = v);
                  setState(() => _showWinAnimation = v);
                },
              ),
              const SizedBox(height: 24),
              // Color picker button
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _openColorPickerBottomSheet();
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFD4D4D8), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.palette, size: 22, color: Color(0xFF1E1E2C)),
                      const SizedBox(width: 10),
                      const Text(
                        'Colors',
                        style: TextStyle(
                          color: Color(0xFF1E1E2C),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Preview swatches
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD4D4D8), width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _textColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD4D4D8), width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _overlayColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD4D4D8), width: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gearToggleRow(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF38BDF8).withValues(alpha: 0.12) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? const Color(0xFF38BDF8) : const Color(0xFFD4D4D8),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: value ? const Color(0xFF0EA5E9) : const Color(0xFF1E1E2C).withValues(alpha: 0.45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: value ? const Color(0xFF1E1E2C) : const Color(0xFF1E1E2C).withValues(alpha: 0.5),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                color: value ? const Color(0xFF38BDF8) : const Color(0xFFD4D4D8),
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCurrentWheelEditor() {
    if (_currentWheel != null) {
      setState(() {
        // Sync editing wheel with current wheel when opening editor
        _editingWheel = _currentWheel;
        _previewWheel = null;
        _leftPanelView = 'current_wheel';
      });
    }
  }

  Future<void> _createNewWheel() async {
    final newWheel = WheelConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'New Wheel',
      items: const [
        WheelItem(text: 'Option 1', color: Color(0xFF322d2a), weight: 1.0), // Color 10 - Dark Gray
        WheelItem(text: 'Option 2', color: Color(0xFFfb2d29), weight: 1.0), // Color 1 - Red
      ],
      textSize: 1.0,
      headerTextSize: 1.0,
      imageSize: 60.0,
      cornerRadius: 8.0,
    );

    await _wheelManager.saveWheel(newWheel);
    await _loadWheels();

    setState(() {
      _currentWheel = newWheel;
    });
  }

  Future<WheelConfig?> _duplicateWheel(WheelConfig wheel) async {
    final duplicatedWheel = wheel.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${wheel.name} (Copy)',
    );

    await _wheelManager.saveWheel(duplicatedWheel);

    // Find the index of the original wheel
    final originalIndex = _savedWheels.indexWhere((w) => w.id == wheel.id);

    // Reload wheels
    await _loadWheels();

    // Update the order to place the copy right after the original
    if (originalIndex != -1 && originalIndex < _savedWheels.length - 1) {
      final prefs = await SharedPreferences.getInstance();
      final List<String> newOrder = List.from(_savedWheels.map((w) => w.id));

      // Find where the duplicated wheel ended up
      final duplicateCurrentIndex = newOrder.indexOf(duplicatedWheel.id);
      if (duplicateCurrentIndex != -1) {
        // Remove it from its current position
        newOrder.removeAt(duplicateCurrentIndex);
        // Insert it right after the original
        newOrder.insert(originalIndex + 1, duplicatedWheel.id);

        // Save the new order
        await prefs.setStringList('wheel_order', newOrder);

        // Reload with new order
        await _loadWheels();
      }
    }

    setState(() {
      _currentWheel = duplicatedWheel;
    });

    return duplicatedWheel;
  }

  Future<bool> _deleteWheel(WheelConfig wheel) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: false,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4D8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(LucideIcons.trash2, color: const Color(0xFFEF4444), size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delete Wheel?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              '"${wheel.name}" will be gone forever.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1E1E2C).withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: PushDownButton(
                    color: const Color(0xFFF4F4F5),
                    onTap: () => Navigator.pop(context, false),
                    child: const Center(
                      child: Text('Cancel', style: TextStyle(color: Color(0xFF1E1E2C), fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PushDownButton(
                    color: const Color(0xFFEF4444),
                    onTap: () => Navigator.pop(context, true),
                    child: const Center(
                      child: Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _wheelManager.deleteWheel(wheel.id);
      await _loadWheels();
      if (_currentWheel?.id == wheel.id) {
        setState(() {
          _currentWheel = _savedWheels.isNotEmpty ? _savedWheels.first : _presets.first;
        });
      }
      return true;
    }
    return false;
  }

  Future<void> _openWheelManager() async {
    // Save current edits if in current_wheel view
    if (_leftPanelView == 'current_wheel' && _previewWheel != null) {
      await _wheelManager.saveWheel(_previewWheel!);
      await _loadWheels();
      setState(() {
        _currentWheel = _previewWheel;
      });
    }

    setState(() {
      _leftPanelView = 'manager';
      // Don't clear _editingWheel or _previewWheel - keep editor state alive
    });
  }

  Future<void> _handleWheelPreview(WheelConfig config) async {
    setState(() {
      _previewWheel = config;
    });

    // Debounce auto-save to avoid saving on every single change
    if (_leftPanelView == 'current_wheel' && _currentWheel != null) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(milliseconds: 500), () async {
        await _wheelManager.saveWheel(config);
        // Update current wheel reference without reloading entire list
        setState(() {
          _currentWheel = config;
        });
      });
    }
  }

  Widget _buildLeftPanel() {
    // Always build both panels so they're ready when switching
    // But only show the active one
    return Stack(
      children: [
        // Wheel Manager Panel
        Offstage(
          offstage: _leftPanelView != 'manager',
          child: _buildWheelManagerPanel(),
        ),
        // Wheel Editor Panel
        Offstage(
          offstage: _leftPanelView == 'manager',
          child: _buildWheelEditorPanel(),
        ),
      ],
    );
  }

  void _closeSheet() {
    _snappingSheetController.snapToPosition(
      const SnappingPosition.pixels(positionPixels: -34),
    );
  }

  Widget _buildWheelEditorPanel({bool showClose = false}) {
    // Always build so it's ready to display
    // Use _editingWheel if set, otherwise use _currentWheel for sync
    final wheelToEdit = _editingWheel ?? _currentWheel;
    return WheelEditor(
      key: ValueKey(wheelToEdit?.id ?? 'new'),
      initialConfig: wheelToEdit,
      onPreview: _handleWheelPreview,
      onClose: showClose ? _closeSheet : null,
      scrollController: showClose ? _sheetScrollController : null,
    );
  }

  Widget _buildWheelCard(WheelConfig wheel, bool isSelected, {VoidCallback? onTap}) {
    final faceColor = isSelected ? const Color(0xFFE0F2FE) : Colors.white;
    final borderColor = isSelected ? const Color(0xFF38BDF8) : const Color(0xFFD4D4D8);
    final shadowSource = isSelected ? borderColor : faceColor;
    final bottomColor = oklchShadow(shadowSource);
    final bottomStrokeColor = oklchShadow(shadowSource, lightnessReduction: 0.16);
    final innerStrokeColor = isSelected ? borderColor : oklchShadow(faceColor, lightnessReduction: 0.06);
    const double bottomDepth = 6.5;
    const double innerStrokeWidth = 2.5;
    const double borderRadius = 21;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () {
        setState(() {
          _currentWheel = wheel;
          _previewWheel = null;
          _editingWheel = null;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bottom face
          Positioned(
            left: 0,
            right: 0,
            top: bottomDepth,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: bottomColor,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: bottomStrokeColor,
                  width: innerStrokeWidth,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
            ),
          ),
          // Top face
          Padding(
            padding: const EdgeInsets.only(bottom: bottomDepth),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: faceColor,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: innerStrokeColor,
                  width: innerStrokeWidth,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(
                      LucideIcons.gripVertical,
                      color: const Color(0xFF1E1E2C).withValues(alpha: 0.3),
                      size: 22,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: _WheelThumbnail(items: wheel.items),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          wheel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${wheel.items.length} segments',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelManagerPanel() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Wheels', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          _savedWheels.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No saved wheels yet.\nCreate your first wheel!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: const Color(0xFF1E1E2C).withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _savedWheels.length,
                    proxyDecorator: (child, index, animation) {
                      return Transform.scale(
                        scale: 1.05,
                        child: child,
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      try {
                        _reorderSavedWheels(oldIndex, newIndex);
                      } catch (e) {
                        debugPrint('Reorder error (safe to ignore): $e');
                      }
                    },
                    itemBuilder: (context, index) {
                      try {
                        final wheel = _savedWheels[index];
                        final isSelected = _currentWheel?.id == wheel.id;
                        final card = _buildWheelCard(wheel, isSelected);
                        return Padding(
                          key: ValueKey(wheel.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Stack(
                            children: [
                              SwipeableActionCell(
                                trailingActions: [
                                  SwipeableAction(
                                    color: const Color(0xFF38BDF8),
                                    icon: LucideIcons.copy,
                                    onTap: () => _duplicateWheel(wheel),
                                  ),
                                  SwipeableAction(
                                    color: const Color(0xFFEF4444),
                                    icon: LucideIcons.trash2,
                                    onTap: () => _deleteWheel(wheel),
                                    expandOnFullSwipe: true,
                                  ),
                                ],
                                child: card,
                              ),
                              // Drag overlay — 45px wide, full height, on top
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: 45,
                                child: ReorderableDragStartListener(
                                  index: index,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        _currentWheel = wheel;
                                        _previewWheel = null;
                                        _editingWheel = null;
                                      });
                                    },
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        debugPrint('Wheel item render error: $e');
                        return Container(key: ValueKey('error_${_savedWheels[index].id}'));
                      }
                    },
                  ),
          const SizedBox(height: 10),
          _chunkyButton(
            icon: LucideIcons.plus,
            label: 'Create New Wheel',
            onTap: _createNewWheel,
            color: const Color(0xFF38BDF8),
          ),
        ],
      ),
    );
  }

  // Reusable chunky pill button
  Widget _chunkyButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF1E1E2C),
  }) {
    return PushDownButton(
      color: color,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildGrabbingHandle() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Color(0xFFE4E4E7), width: 1.5),
          left: BorderSide(color: Color(0xFFE4E4E7), width: 1.5),
          right: BorderSide(color: Color(0xFFE4E4E7), width: 1.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    // Ideal wheel size
    const double idealWheelSize = 700;

    // Calculate scale for both layouts
    final availableWidth = isMobile ? (screenWidth - 16) : (screenWidth - 400 - 32);
    final effectiveWheelSize = availableWidth < idealWheelSize ? availableWidth : idealWheelSize;
    final wheelScale = effectiveWheelSize / idealWheelSize;

    if (isMobile) {
      // Mobile layout: SnappingSheet with dynamic wheel resizing
      final screenHeight = MediaQuery.of(context).size.height;
      final safePadding = MediaQuery.of(context).padding;
      final safeAreaHeight = screenHeight - safePadding.top - safePadding.bottom;
      final upperSnapHeight = safeAreaHeight - 16;
      const midSnapHeight = 460.0;

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          backgroundColor: _backgroundColor,
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: Stack(
              children: [
                // Fixed spin controls at screen bottom
                if (_previewWheel != null || _currentWheel != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE4E4E7), width: 1.5),
                          left: BorderSide(color: Color(0xFFE4E4E7), width: 1.5),
                          right: BorderSide(color: Color(0xFFE4E4E7), width: 1.5),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).padding.bottom),
                      child: Row(
                        children: [
                          PushDownButton(
                            color: const Color(0xFFAE01CB),
                            onTap: () => _wheelKey.currentState?.reset(),
                            child: const SizedBox(
                              width: 59,
                              child: Center(
                                child: Icon(LucideIcons.rotateCcw, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PushDownButton(
                              color: const Color(0xFF38BDF8),
                              onTap: () => _wheelKey.currentState?.spin(),
                              child: const Center(
                                child: Text(
                                  'SPIN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          PushDownButton(
                            color: const Color(0xFF1E1E2C),
                            onTap: () {
                              _openCurrentWheelEditor();
                              _snappingSheetController.snapToPosition(
                                const SnappingPosition.pixels(positionPixels: 460),
                              );
                            },
                            child: const SizedBox(
                              width: 59,
                              child: Center(
                                child: Icon(LucideIcons.pencil, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              SnappingSheet(
                controller: _snappingSheetController,
                lockOverflowDrag: false,
                snappingPositions: [
                  const SnappingPosition.pixels(
                    positionPixels: -34,
                    snappingCurve: Curves.easeOutExpo,
                    snappingDuration: Duration(milliseconds: 900),
                    grabbingContentOffset: GrabbingContentOffset.top,
                  ),
                  const SnappingPosition.pixels(
                    positionPixels: 460,
                    snappingCurve: Curves.easeOutExpo,
                    snappingDuration: Duration(milliseconds: 900),
                  ),
                  SnappingPosition.pixels(
                    positionPixels: upperSnapHeight,
                    snappingCurve: Curves.easeOutExpo,
                    snappingDuration: const Duration(milliseconds: 900),
                  ),
                ],
                onSheetMoved: (positionData) {
                  _currentSheetHeight.value = positionData.pixels;
                },
                grabbingHeight: _grabbingHeight,
                grabbing: _buildGrabbingHandle(),
                sheetBelow: SnappingSheetContent(
                  draggable: true,
                  childScrollController: _sheetScrollController,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Color(0xFFE4E4E7), width: 1.5),
                        right: BorderSide(color: Color(0xFFE4E4E7), width: 1.5),
                      ),
                    ),
                    child: _buildWheelEditorPanel(showClose: true),
                  ),
                ),
                // Main content above the sheet
                child: Column(
                  children: [
                    // Dynamic wheel area that resizes with sheet
                    ValueListenableBuilder<double>(
                      valueListenable: _currentSheetHeight,
                      builder: (context, sheetHeight, _) {
                        final availableHeight = screenHeight - sheetHeight - _grabbingHeight + 45;
                          final spacerProgress = (sheetHeight / midSnapHeight).clamp(0.0, 1.0);
                          final spacerHeight = 15.0 + (_bottomControlsHeight + 36) * (1.0 - spacerProgress);
                          final headerSizeProgress = 1.0 - spacerProgress;
                          final headerOpacity = (headerSizeProgress * 2.0 - 1.0).clamp(0.0, 1.0);
                          final estimatedHeaderHeight = 72.0 * headerSizeProgress;
                          final wheelPadding = 140.0 - 80.0 * spacerProgress;
                          final maxWheelSize = min(availableHeight - wheelPadding - estimatedHeaderHeight, effectiveWheelSize);
                          final clampedWheelSize = maxWheelSize.clamp(80.0, effectiveWheelSize);
                          final dynamicWheelScale = clampedWheelSize / idealWheelSize;
                          final wheelOpacity = 1.0 - (2.0 * (sheetHeight - midSnapHeight) / (upperSnapHeight - midSnapHeight)).clamp(0.0, 1.0);

                          return Opacity(
                            opacity: wheelOpacity,
                            child: SizedBox(
                            height: availableHeight.clamp(200.0, safeAreaHeight - _bottomControlsHeight),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: (_previewWheel != null || _currentWheel != null)
                                      ? GestureDetector(
                                          onTap: () {
                                            if (sheetHeight >= midSnapHeight - 50 &&
                                                (_wheelKey.currentState?.isSpinning ?? false)) {
                                              _wheelKey.currentState?.reset();
                                            }
                                          },
                                          child: RepaintBoundary(
                                          child: SpinningWheel(
                                            key: _wheelKey,
                                            items: (_previewWheel ?? _currentWheel)!.items,
                                            onFinished: _onWheelFinished,
                                            size: clampedWheelSize,
                                            textSizeMultiplier: (_previewWheel ?? _currentWheel)!.textSize * dynamicWheelScale,
                                            headerTextSizeMultiplier: (_previewWheel ?? _currentWheel)!.headerTextSize * dynamicWheelScale,
                                            imageSize: (_previewWheel ?? _currentWheel)!.imageSize * dynamicWheelScale,
                                            cornerRadius: (_previewWheel ?? _currentWheel)!.cornerRadius * dynamicWheelScale,
                                            strokeWidth: (_previewWheel ?? _currentWheel)!.strokeWidth * dynamicWheelScale,
                                            showBackgroundCircle: (_previewWheel ?? _currentWheel)!.showBackgroundCircle,
                                            centerMarkerSize: (_previewWheel ?? _currentWheel)!.centerMarkerSize * dynamicWheelScale,
                                            spinIntensity: _spinIntensity,
                                            isRandomIntensity: _isRandomIntensity,
                                            headerTextColor: _textColor,
                                            overlayColor: _overlayColor,
                                            showWinAnimation: _showWinAnimation,
                                            headerOpacity: headerOpacity,
                                            headerSizeProgress: headerSizeProgress,
                                          ),
                                        ),
                                        )
                                      : Text(
                                          'No wheel selected',
                                          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                                            color: const Color(0xFF1E1E2C).withValues(alpha: 0.3),
                                          ),
                                        ),
                                  ),
                                ),
                                SizedBox(height: spacerHeight),
                              ],
                            ),
                          ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              // Transparent app bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<double>(
                  valueListenable: _currentSheetHeight,
                  builder: (context, sheetHeight, child) {
                    final headerProgress = (sheetHeight / midSnapHeight).clamp(0.0, 1.0);
                    final headerOpacity = 1.0 - headerProgress;
                    final headerHeight = 54.0 * (1.0 - headerProgress);
                    return Opacity(
                      opacity: headerOpacity,
                      child: SizedBox(
                        height: headerHeight,
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Settings button (left)
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(50),
                              onTap: _openGearMenu,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(LucideIcons.settings, color: Colors.black, size: 22),
                              ),
                            ),
                          ),
                          // Wheels button (right)
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(50),
                              onTap: _openWheelsScreen,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(LucideIcons.list, color: Colors.black, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    );
    }

    // Desktop layout: side-by-side
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
          // Left sidebar
          Container(
            width: 400,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE4E4E7), width: 1.5)),
            ),
            child: Column(
              children: [
                // Nav tabs
                if (_leftPanelView != 'new_wheel')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      children: [
                        Expanded(child: _navTab('Wheels', LucideIcons.list, _leftPanelView == 'manager', _leftPanelView == 'manager' ? null : _openWheelManager)),
                        const SizedBox(width: 10),
                        Expanded(child: _navTab('Editor', LucideIcons.pencil, _leftPanelView == 'current_wheel', _currentWheel == null || _leftPanelView == 'current_wheel' ? null : _openCurrentWheelEditor)),
                      ],
                    ),
                  ),
                Expanded(child: _buildLeftPanel()),
              ],
            ),
          ),
          // Right side — wheel area
          Expanded(
            child: Container(
              color: _backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      if (_previewWheel != null || _currentWheel != null) ...[
                        RepaintBoundary(
                          child: SpinningWheel(
                            key: _wheelKey,
                            items: (_previewWheel ?? _currentWheel)!.items,
                            onFinished: _onWheelFinished,
                            size: effectiveWheelSize,
                            textSizeMultiplier: (_previewWheel ?? _currentWheel)!.textSize * wheelScale,
                            headerTextSizeMultiplier: (_previewWheel ?? _currentWheel)!.headerTextSize * wheelScale,
                            imageSize: (_previewWheel ?? _currentWheel)!.imageSize * wheelScale,
                            cornerRadius: (_previewWheel ?? _currentWheel)!.cornerRadius * wheelScale,
                            strokeWidth: (_previewWheel ?? _currentWheel)!.strokeWidth * wheelScale,
                            showBackgroundCircle: (_previewWheel ?? _currentWheel)!.showBackgroundCircle,
                            centerMarkerSize: (_previewWheel ?? _currentWheel)!.centerMarkerSize * wheelScale,
                            spinIntensity: _spinIntensity,
                            isRandomIntensity: _isRandomIntensity,
                            headerTextColor: _textColor,
                            overlayColor: _overlayColor,
                            showWinAnimation: _showWinAnimation,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Spin controls bar
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: effectiveWheelSize),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: const Color(0xFFE4E4E7), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                PushDownButton(
                                  color: const Color(0xFFAE01CB),
                                  onTap: () => _wheelKey.currentState?.reset(),
                                            child: const SizedBox(
                                    width: 59,
                                    child: Center(
                                      child: Icon(LucideIcons.rotateCcw, color: Colors.white, size: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: PushDownButton(
                                    color: const Color(0xFF38BDF8),
                                    onTap: () => _wheelKey.currentState?.spin(),
                                                                  child: const Center(
                                      child: Text(
                                        'SPIN',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                PushDownButton(
                                  color: const Color(0xFF1E1E2C),
                                  onTap: _openGearMenu,
                                  child: const SizedBox(
                                    width: 59,
                                    child: Center(
                                      child: Icon(LucideIcons.settings, color: Colors.white, size: 28),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else
                        Text(
                          'No wheel selected',
                          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                            color: const Color(0xFF1E1E2C).withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  // Nav tab pill
  Widget _navTab(String label, IconData icon, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF38BDF8) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(50),
          border: active ? null : Border.all(color: const Color(0xFFE4E4E7), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? Colors.white : const Color(0xFF1E1E2C).withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: active ? Colors.white : const Color(0xFF1E1E2C).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _WheelsScreen extends StatefulWidget {
  final List<WheelConfig> savedWheels;
  final WheelConfig? currentWheel;
  final ValueChanged<WheelConfig> onWheelSelected;
  final Future<WheelConfig?> Function(WheelConfig) onDuplicateWheel;
  final Future<bool> Function(WheelConfig) onDeleteWheel;
  final Future<void> Function(int, int) onReorderWheels;
  final Future<void> Function() onCreateNewWheel;
  final Widget Function(WheelConfig wheel, bool isSelected, {VoidCallback? onTap}) buildWheelCard;

  const _WheelsScreen({
    required this.savedWheels,
    required this.currentWheel,
    required this.onWheelSelected,
    required this.onDuplicateWheel,
    required this.onDeleteWheel,
    required this.onReorderWheels,
    required this.onCreateNewWheel,
    required this.buildWheelCard,
  });

  @override
  State<_WheelsScreen> createState() => _WheelsScreenState();
}

class _WheelsScreenState extends State<_WheelsScreen> {
  late List<WheelConfig> _wheels;
  String? _selectedWheelId;
  DateTime? _lastTapTime;
  String? _lastTappedWheelId;

  @override
  void initState() {
    super.initState();
    _wheels = List.of(widget.savedWheels);
    _selectedWheelId = widget.currentWheel?.id;
  }

  void _handleWheelTap(WheelConfig wheel) {
    final now = DateTime.now();
    final isDoubleTap = _lastTappedWheelId == wheel.id &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 350);

    if (isDoubleTap) {
      widget.onWheelSelected(wheel);
      Navigator.pop(context);
    } else {
      widget.onWheelSelected(wheel);
      setState(() { _selectedWheelId = wheel.id; });
    }

    _lastTapTime = now;
    _lastTappedWheelId = wheel.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text('Your Wheels', style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Wheel list
            Expanded(
              child: _wheels.isEmpty
                  ? Center(
                      child: Text(
                        'No saved wheels yet.\nCreate your first wheel!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: const Color(0xFF1E1E2C).withValues(alpha: 0.45),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      buildDefaultDragHandles: false,
                      itemCount: _wheels.length,
                      proxyDecorator: (child, index, animation) {
                        return Transform.scale(scale: 1.05, child: child);
                      },
                      onReorder: (oldIndex, newIndex) {
                        try {
                          widget.onReorderWheels(oldIndex, newIndex);
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _wheels.removeAt(oldIndex);
                            _wheels.insert(newIndex, item);
                          });
                        } catch (e) {
                          debugPrint('Reorder error: $e');
                        }
                      },
                      itemBuilder: (context, index) {
                        try {
                          final wheel = _wheels[index];
                          final isSelected = _selectedWheelId == wheel.id;
                          final card = widget.buildWheelCard(wheel, isSelected,
                            onTap: () => _handleWheelTap(wheel),
                          );
                          return Padding(
                            key: ValueKey(wheel.id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Stack(
                              children: [
                                SwipeableActionCell(
                                  trailingActions: [
                                    SwipeableAction(
                                      color: const Color(0xFF38BDF8),
                                      icon: LucideIcons.copy,
                                      onTap: () async {
                                        final copy = await widget.onDuplicateWheel(wheel);
                                        if (!mounted || copy == null) return;
                                        final idx = _wheels.indexWhere((w) => w.id == wheel.id);
                                        setState(() {
                                          _wheels.insert(idx + 1, copy);
                                          _selectedWheelId = copy.id;
                                        });
                                      },
                                    ),
                                    SwipeableAction(
                                      color: const Color(0xFFEF4444),
                                      icon: LucideIcons.trash2,
                                      onTap: () async {
                                        final deleted = await widget.onDeleteWheel(wheel);
                                        if (!mounted || !deleted) return;
                                        setState(() {
                                          _wheels.removeWhere((w) => w.id == wheel.id);
                                        });
                                      },
                                      expandOnFullSwipe: true,
                                    ),
                                  ],
                                  child: card,
                                ),
                                // Drag overlay — 45px wide, full height, on top
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 45,
                                  child: ReorderableDragStartListener(
                                    index: index,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _handleWheelTap(wheel),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } catch (e) {
                          debugPrint('Wheel item render error: $e');
                          return Container(key: ValueKey('error_${_wheels[index].id}'));
                        }
                      },
                    ),
            ),
            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: PushDownButton(
                color: const Color(0xFF38BDF8),
                onTap: () async {
                  await widget.onCreateNewWheel();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.plus, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text('Create New Wheel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  final Color backgroundColor;
  final Color textColor;
  final Color overlayColor;
  final ValueChanged<Color> onBackgroundColorChanged;
  final ValueChanged<Color> onTextColorChanged;
  final ValueChanged<Color> onOverlayColorChanged;

  const _ColorPickerSheet({
    required this.backgroundColor,
    required this.textColor,
    required this.overlayColor,
    required this.onBackgroundColorChanged,
    required this.onTextColorChanged,
    required this.onOverlayColorChanged,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _bgHexController;
  late TextEditingController _textHexController;
  late TextEditingController _overlayHexController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bgHexController = TextEditingController(text: _colorToHex(widget.backgroundColor));
    _textHexController = TextEditingController(text: _colorToHex(widget.textColor));
    _overlayHexController = TextEditingController(text: _colorToHex(widget.overlayColor));
  }

  @override
  void didUpdateWidget(covariant _ColorPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundColor != widget.backgroundColor) {
      _bgHexController.text = _colorToHex(widget.backgroundColor);
    }
    if (oldWidget.textColor != widget.textColor) {
      _textHexController.text = _colorToHex(widget.textColor);
    }
    if (oldWidget.overlayColor != widget.overlayColor) {
      _overlayHexController.text = _colorToHex(widget.overlayColor);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bgHexController.dispose();
    _textHexController.dispose();
    _overlayHexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD4D4D8),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Background'),
              Tab(text: 'Header Text'),
              Tab(text: 'Overlay'),
            ],
          ),
          SizedBox(
            height: 450,
            child: TabBarView(
              controller: _tabController,
              children: [
                _colorTab(widget.backgroundColor, widget.onBackgroundColorChanged, _bgHexController),
                _colorTab(widget.textColor, widget.onTextColorChanged, _textHexController),
                _colorTab(widget.overlayColor, widget.onOverlayColorChanged, _overlayHexController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorTab(Color color, ValueChanged<Color> onChanged, TextEditingController hexController) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      child: Column(
        children: [
          ColorPicker(
            color: color,
            onColorChanged: onChanged,
            wheelDiameter: 280,
            wheelWidth: 28,
            enableShadesSelection: false,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
              ColorPickerType.wheel: true,
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: hexController,
            maxLength: 6,
            style: const TextStyle(fontWeight: FontWeight.w600),
            onSubmitted: (value) {
              final c = _hexToColor(value);
              if (c != null) onChanged(c);
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _WheelThumbnail extends StatelessWidget {
  final List<WheelItem> items;

  const _WheelThumbnail({required this.items});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WheelThumbnailPainter(items),
    );
  }
}

class _WheelThumbnailPainter extends CustomPainter {
  final List<WheelItem> items;

  _WheelThumbnailPainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final totalWeight = items.fold<double>(0.0, (sum, item) => sum + item.weight);
    final paint = Paint()..style = PaintingStyle.fill;

    // Gray background to fill anti-aliasing gaps
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFD4D4D8));

    double startAngle = -pi / 2;
    for (final item in items) {
      final sweep = (item.weight / totalWeight) * 2 * pi;
      paint.color = item.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }

    // Inner stroke
    canvas.drawCircle(
      center,
      radius - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black.withValues(alpha: 0.15)
        ..strokeWidth = 1.5,
    );
    // Outer stroke
    canvas.drawCircle(
      center,
      radius + 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black.withValues(alpha: 0.15)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WheelThumbnailPainter oldDelegate) {
    return oldDelegate.items != items;
  }
}
