import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'spinning_wheel.dart';
import 'wheel_item.dart';
import 'wheel_config.dart';
import 'wheel_manager.dart';
import 'wheel_editor.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Spinning Wheel',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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
  Color _backgroundColor = Colors.white;
  Color _textColor = Colors.black;
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
  final GlobalKey<SpinningWheelState> _wheelKey = GlobalKey<SpinningWheelState>();

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
      ),
    );
  }

  void _openCurrentWheelEditor() {
    if (_currentWheel != null) {
      setState(() {
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

  Future<void> _duplicateWheel(WheelConfig wheel) async {
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
  }

  Future<void> _deleteWheel(WheelConfig wheel) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: false,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.warning, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Delete Wheel',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to delete "${wheel.name}"?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete'),
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
    }
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
      _editingWheel = null;
      _previewWheel = null;
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
    switch (_leftPanelView) {
      case 'current_wheel':
      case 'new_wheel':
        return _buildWheelEditorPanel();
      case 'manager':
      default:
        return _buildWheelManagerPanel();
    }
  }

  Widget _buildWheelEditorPanel() {
    return WheelEditor(
      initialConfig: _editingWheel,
      onPreview: _handleWheelPreview,
    );
  }

  Widget _buildWheelManagerPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                const Text(
                  'Your Wheels',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _savedWheels.isEmpty
                    ? const Center(
                        child: Text(
                          'No saved wheels yet.\nCreate your first wheel!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: _savedWheels.length,
                          onReorder: (oldIndex, newIndex) {
                            try {
                              _reorderSavedWheels(oldIndex, newIndex);
                            } catch (e) {
                              // Ignore Flutter rendering assertions during reorder
                              debugPrint('Reorder error (safe to ignore): $e');
                            }
                          },
                          itemBuilder: (context, index) {
                            try {
                              final wheel = _savedWheels[index];
                              final isSelected = _currentWheel?.id == wheel.id;
                              return ReorderableDragStartListener(
                              key: ValueKey(wheel.id),
                              index: index,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color.fromARGB(255, 220, 240, 255) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border:  isSelected ? Border.all(color: Colors.blue, width: 1.5) : Border.all(color: Colors.grey, width: 1.5) ,
                                  boxShadow: [
                                    // Outer, softer shadow (more blurred, less opaque)
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                    // Inner, sharper shadow (more opaque, closer)
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                leading: Icon(
                                  Icons.casino,
                                  color: isSelected ? Colors.blue : null,
                                ),
                                title: Text(
                                  wheel.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? null : null,
                                  ),
                                ),
                                subtitle: Text('${wheel.items.length} segments'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () => _duplicateWheel(wheel),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      color: Colors.red,
                                      onPressed: () => _deleteWheel(wheel),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    _currentWheel = wheel;
                                    _previewWheel = null;
                                    _editingWheel = null;
                                  });
                                },
                              ),
                            ),
                            );
                            } catch (e) {
                              // Fallback for rendering errors
                              debugPrint('Wheel item render error: $e');
                              return Container(key: ValueKey('error_${_savedWheels[index].id}'));
                            }
                          },
                        ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _createNewWheel,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: const [
                          Icon(Icons.add, color: Colors.white),
                          SizedBox(width: 16),
                          Text(
                            'Create New Wheel',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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

    return Scaffold(
      body: Row(
        children: [
          // Left sidebar with controls
          Container(
            width: 400,
            color: Colors.white,
            child: Column(
              children: [
                // Navigation buttons
                if (_leftPanelView != 'new_wheel')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _leftPanelView == 'manager' ? null : _openWheelManager,
                            icon: const Icon(Icons.list),
                            label: const Text('Wheels'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _leftPanelView == 'manager'
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _currentWheel == null || _leftPanelView == 'current_wheel' ? null : _openCurrentWheelEditor,
                            icon: const Icon(Icons.edit),
                            label: const Text('Current Wheel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _leftPanelView == 'current_wheel'
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Content area
                Expanded(
                  child: _buildLeftPanel(),
                ),
              ],
            ),
          ),
          // Right side with wheel
          Expanded(
            child: Container(
              color: _backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_previewWheel != null || _currentWheel != null) ...[
                      RepaintBoundary(
                        child: SpinningWheel(
                          key: _wheelKey,
                          items: (_previewWheel ?? _currentWheel)!.items,
                          onFinished: _onWheelFinished,
                          size: 700,
                          textSizeMultiplier: (_previewWheel ?? _currentWheel)!.textSize,
                          headerTextSizeMultiplier: (_previewWheel ?? _currentWheel)!.headerTextSize,
                          imageSize: (_previewWheel ?? _currentWheel)!.imageSize,
                          cornerRadius: (_previewWheel ?? _currentWheel)!.cornerRadius,
                          strokeWidth: (_previewWheel ?? _currentWheel)!.strokeWidth,
                          showBackgroundCircle: (_previewWheel ?? _currentWheel)!.showBackgroundCircle,
                          centerMarkerSize: (_previewWheel ?? _currentWheel)!.centerMarkerSize,
                          spinIntensity: _spinIntensity,
                          isRandomIntensity: _isRandomIntensity,
                          headerTextColor: _textColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Spin controls in one row
                      Container(
                        width: 700,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () => _wheelKey.currentState?.reset(),
                              icon: const Icon(Icons.restart_alt),
                              iconSize: 32,
                              tooltip: 'Reset wheel position',
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _wheelKey.currentState?.spin(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                                textStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                elevation: 0,
                              ),
                              child: const Text('SPIN', style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isRandomIntensity,
                                  onChanged: (value) {
                                    setState(() {
                                      _isRandomIntensity = value ?? true;
                                    });
                                  },
                                ),
                                const Text('Random'),
                              ],
                            ),
                            if (!_isRandomIntensity) ...[
                              const SizedBox(width: 16),
                              const Text('Intensity: '),
                              SizedBox(
                                width: 200,
                                child: Slider(
                                  value: _spinIntensity,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 20,
                                  label: '${(_spinIntensity * 100).round()}%',
                                  onChanged: (value) {
                                    setState(() {
                                      _spinIntensity = value;
                                    });
                                  },
                                ),
                              ),
                              Text('${(_spinIntensity * 100).round()}%'),
                            ],
                          ],
                        ),
                      ),
                    ] else
                      const Text(
                        'No wheel selected',
                        style: TextStyle(fontSize: 24, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 16),
        child: FloatingActionButton(
          onPressed: _openColorPickerBottomSheet,
          child: const Icon(Icons.color_lens),
        ),
      ),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  final Color backgroundColor;
  final Color textColor;
  final ValueChanged<Color> onBackgroundColorChanged;
  final ValueChanged<Color> onTextColorChanged;

  const _ColorPickerSheet({
    required this.backgroundColor,
    required this.textColor,
    required this.onBackgroundColorChanged,
    required this.onTextColorChanged,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 16, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Background'),
              Tab(text: 'Text'),
            ],
            labelColor: Colors.black,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          // Tab views
          SizedBox(
            height: 450,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Background color picker
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      ColorPicker(
                        color: widget.backgroundColor,
                        onColorChanged: widget.onBackgroundColorChanged,
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
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Text color picker
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      ColorPicker(
                        color: widget.textColor,
                        onColorChanged: widget.onTextColorChanged,
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
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
