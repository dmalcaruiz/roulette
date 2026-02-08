import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'wheel_config.dart';
import 'wheel_item.dart';
import 'icon_map.dart';

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

class WheelEditor extends StatefulWidget {
  final WheelConfig? initialConfig;
  final Function(WheelConfig)? onSave;
  final VoidCallback? onCancel;
  final Function(WheelConfig)? onPreview;

  const WheelEditor({
    super.key,
    this.initialConfig,
    this.onSave,
    this.onCancel,
    this.onPreview,
  });

  @override
  State<WheelEditor> createState() => _WheelEditorState();
}

class _WheelEditorState extends State<WheelEditor> {
  late TextEditingController _nameController;
  late List<_SegmentData> _segments;
  late double _textSize;
  late double _headerTextSize;
  late double _imageSize;
  late double _cornerRadius;
  late double _imageCornerRadius;
  late double _strokeWidth;
  late bool _showBackgroundCircle;
  late double _centerMarkerSize;
  int? _editingColorIndex;
  Timer? _keyRepeatTimer;
  Timer? _previewDebounceTimer;
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _segmentTextControllers = {};
  final Map<String, TextEditingController> _hexControllers = {};
  late TextEditingController _textSizeController;
  late TextEditingController _headerTextSizeController;
  late TextEditingController _imageSizeController;
  late TextEditingController _cornerRadiusController;
  late TextEditingController _imageCornerRadiusController;
  late TextEditingController _strokeWidthController;
  late TextEditingController _centerMarkerSizeController;
  int _segmentIdCounter = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialConfig != null) {
      _nameController = TextEditingController(text: widget.initialConfig!.name);
      _segments = widget.initialConfig!.items.map((item) {
        final id = '${_segmentIdCounter++}';
        final segment = _SegmentData(
          id: id,
          text: item.text,
          color: item.color,
          weight: item.weight,
          imagePath: item.imagePath,
          iconName: item.iconName,
        );
        _weightControllers[id] = TextEditingController(text: item.weight.toStringAsFixed(1));
        _segmentTextControllers[id] = TextEditingController(text: item.text);
        return segment;
      }).toList();
      _textSize = widget.initialConfig!.textSize;
      _headerTextSize = widget.initialConfig!.headerTextSize;
      _imageSize = widget.initialConfig!.imageSize;
      _cornerRadius = widget.initialConfig!.cornerRadius;
      _imageCornerRadius = widget.initialConfig!.imageCornerRadius;
      _strokeWidth = widget.initialConfig!.strokeWidth;
      _showBackgroundCircle = widget.initialConfig!.showBackgroundCircle;
      _centerMarkerSize = widget.initialConfig!.centerMarkerSize;

      _textSizeController = TextEditingController(text: _textSize.toStringAsFixed(2));
      _headerTextSizeController = TextEditingController(text: _headerTextSize.toStringAsFixed(1));
      _imageSizeController = TextEditingController(text: _imageSize.toStringAsFixed(0));
      _cornerRadiusController = TextEditingController(text: _cornerRadius.toStringAsFixed(1));
      _imageCornerRadiusController = TextEditingController(text: _imageCornerRadius.toStringAsFixed(1));
      _strokeWidthController = TextEditingController(text: _strokeWidth.toStringAsFixed(1));
      _centerMarkerSizeController = TextEditingController(text: _centerMarkerSize.toStringAsFixed(0));
    } else {
      _nameController = TextEditingController(text: 'New Wheel');
      _segments = [];

      // Add first segment (gets color 10, index 9)
      final id1 = '${_segmentIdCounter++}';
      _segments.add(_SegmentData(
        id: id1,
        text: 'Option 1',
        color: _getNextColor(),
        weight: 1.0,
      ));
      _weightControllers[id1] = TextEditingController(text: '1.0');
      _segmentTextControllers[id1] = TextEditingController(text: 'Option 1');

      // Add second segment (gets color 1, index 0)
      final id2 = '${_segmentIdCounter++}';
      _segments.add(_SegmentData(
        id: id2,
        text: 'Option 2',
        color: _getNextColor(),
        weight: 1.0,
      ));
      _weightControllers[id2] = TextEditingController(text: '1.0');
      _segmentTextControllers[id2] = TextEditingController(text: 'Option 2');

      _textSize = 1.0;
      _headerTextSize = 1.0;
      _imageSize = 60.0;
      _cornerRadius = 8.0;
      _imageCornerRadius = 8.0;
      _strokeWidth = 3.0;
      _showBackgroundCircle = true;
      _centerMarkerSize = 200.0;

      _textSizeController = TextEditingController(text: _textSize.toStringAsFixed(2));
      _headerTextSizeController = TextEditingController(text: _headerTextSize.toStringAsFixed(1));
      _imageSizeController = TextEditingController(text: _imageSize.toStringAsFixed(0));
      _cornerRadiusController = TextEditingController(text: _cornerRadius.toStringAsFixed(1));
      _imageCornerRadiusController = TextEditingController(text: _imageCornerRadius.toStringAsFixed(1));
      _strokeWidthController = TextEditingController(text: _strokeWidth.toStringAsFixed(1));
      _centerMarkerSizeController = TextEditingController(text: _centerMarkerSize.toStringAsFixed(0));
    }

    // Trigger initial preview
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePreview();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _textSizeController.dispose();
    _headerTextSizeController.dispose();
    _imageSizeController.dispose();
    _cornerRadiusController.dispose();
    _strokeWidthController.dispose();
    _centerMarkerSizeController.dispose();
    _keyRepeatTimer?.cancel();
    _previewDebounceTimer?.cancel();
    for (var controller in _weightControllers.values) {
      controller.dispose();
    }
    for (var controller in _segmentTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startKeyRepeat(VoidCallback action) {
    _keyRepeatTimer?.cancel();
    action(); // Execute immediately
    // Wait 400ms before starting the repeating timer
    // This ensures a quick tap only increments once
    _keyRepeatTimer = Timer(const Duration(milliseconds: 400), () {
      _keyRepeatTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        action();
      });
    });
  }

  void _stopKeyRepeat() {
    _keyRepeatTimer?.cancel();
    _keyRepeatTimer = null;
  }

  void _addSegment() {
    setState(() {
      final id = '${_segmentIdCounter++}';
      final text = 'Option ${_segments.length + 1}';
      _segments.add(_SegmentData(
        id: id,
        text: text,
        color: _getNextColor(),
        weight: 1.0,
      ));
      _weightControllers[id] = TextEditingController(text: '1.0');
      _segmentTextControllers[id] = TextEditingController(text: text);
    });
    _updatePreview(immediate: true);
  }

  Color _getNextColor() {
    final colors = [
      const Color(0xFFfb2d29), // Red
      const Color(0xFFfb9000), // Orange
      const Color(0xFFf5cc00), // Yellow
      const Color(0xFF88d515), // Green
      const Color(0xFF00c485), // Teal
      const Color(0xFF00ace7), // Blue
      const Color(0xFF303dcb), // Indigo
      const Color(0xFFc827d4), // Purple
      const Color(0xFFfd41a4), // Pink
      const Color(0xFF322d2a), // Dark Gray
    ];
    // Start from color 10 (index 9), then color 1 (index 0), then color 2 (index 1), etc.
    return colors[(_segments.length - 1 + colors.length) % colors.length];
  }

  void _removeSegment(int index) {
    if (_segments.length > 2) {
      setState(() {
        final segment = _segments.removeAt(index);
        _weightControllers[segment.id]?.dispose();
        _weightControllers.remove(segment.id);
        _segmentTextControllers[segment.id]?.dispose();
        _segmentTextControllers.remove(segment.id);
        _hexControllers[segment.id]?.dispose();
        _hexControllers.remove(segment.id);
      });
      _updatePreview(immediate: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wheel must have at least 2 segments')),
      );
    }
  }

  void _duplicateSegment(int index) {
    setState(() {
      final original = _segments[index];
      final id = '${_segmentIdCounter++}';
      final duplicate = _SegmentData(
        id: id,
        text: original.text,
        color: original.color,
        weight: original.weight,
      );
      _segments.insert(index + 1, duplicate);
      _weightControllers[id] = TextEditingController(text: original.weight.toStringAsFixed(1));
      _segmentTextControllers[id] = TextEditingController(text: original.text);
    });
    _updatePreview(immediate: true);
  }

  void _reorderSegments(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final segment = _segments.removeAt(oldIndex);
      _segments.insert(newIndex, segment);
    });
    _updatePreview(immediate: true);
  }

  void _pickColor(int index) {
    setState(() {
      _editingColorIndex = _editingColorIndex == index ? null : index;
    });
  }

  void _openVisualConfigSheet(int index) {
    final segment = _segments[index];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _VisualConfigSheet(
        imagePath: segment.imagePath,
        iconName: segment.iconName,
        onImagePicked: (path) {
          setState(() {
            _segments[index].imagePath = path;
            _segments[index].iconName = null;
          });
          _updatePreview(immediate: true);
        },
        onImageRemoved: () {
          setState(() {
            _segments[index].imagePath = null;
          });
          _updatePreview(immediate: true);
        },
        onIconSelected: (name) {
          setState(() {
            _segments[index].iconName = name;
            _segments[index].imagePath = null;
          });
          _updatePreview(immediate: true);
        },
        onIconRemoved: () {
          setState(() {
            _segments[index].iconName = null;
          });
          _updatePreview(immediate: true);
        },
      ),
    );
  }

  void _updatePreview({bool immediate = false}) {
    if (widget.onPreview != null && _nameController.text.trim().isNotEmpty) {
      // Cancel any pending debounced preview
      _previewDebounceTimer?.cancel();

      if (immediate) {
        // Immediate update for major changes (add/remove segments, etc.)
        _triggerPreview();
      } else {
        // Debounce updates for continuous changes (sliders, text input, etc.)
        _previewDebounceTimer = Timer(const Duration(milliseconds: 150), () {
          _triggerPreview();
        });
      }
    }
  }

  void _triggerPreview() {
    final config = WheelConfig(
      id: widget.initialConfig?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      items: _segments.map((seg) => WheelItem(
        text: seg.text,
        color: seg.color,
        weight: seg.weight,
        imagePath: seg.imagePath,
        iconName: seg.iconName,
      )).toList(),
      textSize: _textSize,
      headerTextSize: _headerTextSize,
      imageSize: _imageSize,
      cornerRadius: _cornerRadius,
      strokeWidth: _strokeWidth,
      showBackgroundCircle: _showBackgroundCircle,
      centerMarkerSize: _centerMarkerSize,
    );
    widget.onPreview!(config);
  }

  Widget _buildHSBSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              max == 1 ? value.toStringAsFixed(2) : value.toStringAsFixed(0),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }



  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                width: 48, height: 5,
                decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 20),
              const Text('Wheel Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              _settingSlider('Segment Text', _textSize, 0.05, 1.5, 29, (v) { setSheetState(() => _textSize = v); setState(() { _textSize = v; _textSizeController.text = v.toStringAsFixed(2); }); _updatePreview(); }),
              _settingSlider('Header Text', _headerTextSize, 0.05, 2.0, 200, (v) { setSheetState(() => _headerTextSize = v); setState(() { _headerTextSize = v; _headerTextSizeController.text = v.toStringAsFixed(1); }); _updatePreview(); }),
              _settingSlider('Image Size', _imageSize, 20, 150, 130, (v) { setSheetState(() => _imageSize = v); setState(() { _imageSize = v; _imageSizeController.text = v.toStringAsFixed(0); }); _updatePreview(); }),
              _settingSlider('Corner Radius', _cornerRadius, 0, 100, 40, (v) { setSheetState(() => _cornerRadius = v); setState(() { _cornerRadius = v; _cornerRadiusController.text = v.toStringAsFixed(1); }); _updatePreview(); }),
              _settingSlider('Stroke Width', _strokeWidth, 0, 10, 100, (v) { setSheetState(() => _strokeWidth = v); setState(() { _strokeWidth = v; _strokeWidthController.text = v.toStringAsFixed(1); }); _updatePreview(); }),
              _settingSlider('Center Marker', _centerMarkerSize, 100, 250, 150, (v) { setSheetState(() => _centerMarkerSize = v); setState(() { _centerMarkerSize = v; _centerMarkerSizeController.text = v.toStringAsFixed(0); }); _updatePreview(); }),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setSheetState(() => _showBackgroundCircle = !_showBackgroundCircle);
                  setState(() {});
                  _updatePreview();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _showBackgroundCircle ? const Color(0xFF38BDF8).withValues(alpha: 0.12) : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _showBackgroundCircle ? const Color(0xFF38BDF8) : const Color(0xFFD4D4D8), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(_showBackgroundCircle ? LucideIcons.checkCircle : LucideIcons.circle, color: _showBackgroundCircle ? const Color(0xFF38BDF8) : const Color(0xFFD4D4D8), size: 22),
                      const SizedBox(width: 12),
                      Text('Background Circle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: _showBackgroundCircle ? const Color(0xFF1E1E2C) : const Color(0xFF1E1E2C).withValues(alpha: 0.5))),
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

  Widget _settingSlider(String label, double value, double min, double max, int divisions, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Expanded(
            child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
          ),
          SizedBox(width: 44, child: Text(max > 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initialConfig != null ? 'Edit Wheel' : 'Create Wheel',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            onChanged: (value) => _updatePreview(),
          ),
          const SizedBox(height: 16),
          // Settings button — opens all sliders in a bottom sheet
          _editorPillButton(
            icon: LucideIcons.settings,
            label: 'Wheel Settings',
            onTap: _openSettingsSheet,
            color: const Color(0xFFF4F4F5),
            textColor: const Color(0xFF1E1E2C),
            borderColor: const Color(0xFFD4D4D8),
          ),
          const SizedBox(height: 24),
          const Text('Segments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _segments.length,
            proxyDecorator: (child, index, animation) {
              return Transform.scale(
                scale: 1.05,
                child: Material(
                  color: Colors.transparent,
                  child: child,
                ),
              );
            },
            onReorder: (oldIndex, newIndex) {
              try {
                _reorderSegments(oldIndex, newIndex);
              } catch (e) {
                debugPrint('Reorder error (safe to ignore): $e');
              }
            },
            itemBuilder: (context, index) {
              try {
                final segment = _segments[index];
                final card = ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD4D4D8), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Color swatch
                            GestureDetector(
                              onTap: () => _pickColor(index),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: segment.color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(LucideIcons.palette, color: Colors.white, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RepaintBoundary(
                                child: Builder(
                                  builder: (context) {
                                    try {
                                      return TextField(
                                        controller: _segmentTextControllers[segment.id],
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        enableInteractiveSelection: _editingColorIndex != null || true,
                                        onChanged: (value) {
                                          try {
                                            segment.text = value;
                                            _updatePreview();
                                          } catch (e) {
                                            debugPrint('Error updating segment text: $e');
                                          }
                                        },
                                      );
                                    } catch (e) {
                                      debugPrint('Error building TextField: $e');
                                      return Container();
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _segIconBtn(
                              segment.imagePath != null ? LucideIcons.image : segment.iconName != null ? LucideIcons.smile : LucideIcons.imagePlus,
                              () => _openVisualConfigSheet(index),
                              active: segment.imagePath != null || segment.iconName != null,
                            ),
                            _segIconBtn(LucideIcons.copy, () => _duplicateSegment(index)),
                            _segIconBtn(LucideIcons.trash2, () => _removeSegment(index), color: const Color(0xFFEF4444)),
                          ],
                        ),
                        if (_editingColorIndex == index) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                ColorPicker(
                                  color: segment.color,
                                  onColorChanged: (Color color) {
                                    setState(() {
                                      segment.color = color;
                                      _hexControllers[segment.id]?.text = _colorToHex(color);
                                    });
                                    _updatePreview();
                                  },
                                  wheelDiameter: 260,
                                  wheelWidth: 26,
                                  enableShadesSelection: false,
                                  pickersEnabled: const <ColorPickerType, bool>{
                                    ColorPickerType.both: false,
                                    ColorPickerType.primary: false,
                                    ColorPickerType.accent: false,
                                    ColorPickerType.wheel: true,
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _hexControllers.putIfAbsent(
                                    segment.id,
                                    () => TextEditingController(text: _colorToHex(segment.color)),
                                  ),
                                  maxLength: 6,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  onSubmitted: (value) {
                                    final c = _hexToColor(value);
                                    if (c != null) {
                                      setState(() => segment.color = c);
                                      _updatePreview();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildHSBSlider('Hue', HSVColor.fromColor(segment.color).hue, 0, 360, (value) {
                                  final hsv = HSVColor.fromColor(segment.color);
                                  setState(() => segment.color = hsv.withHue(value).toColor());
                                  _updatePreview();
                                }),
                                _buildHSBSlider('Saturation', HSVColor.fromColor(segment.color).saturation, 0, 1, (value) {
                                  final hsv = HSVColor.fromColor(segment.color);
                                  setState(() => segment.color = hsv.withSaturation(value).toColor());
                                  _updatePreview();
                                }),
                                _buildHSBSlider('Brightness', HSVColor.fromColor(segment.color).value, 0, 1, (value) {
                                  final hsv = HSVColor.fromColor(segment.color);
                                  setState(() => segment.color = hsv.withValue(value).toColor());
                                  _updatePreview();
                                }),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('Weight', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E1E2C).withValues(alpha: 0.5))),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Slider(
                                value: segment.weight,
                                min: 0.1,
                                max: 10.0,
                                divisions: 200,
                                label: segment.weight.toStringAsFixed(1),
                                onChanged: (value) {
                                  setState(() {
                                    segment.weight = value;
                                    _weightControllers[segment.id]?.text = value.toStringAsFixed(1);
                                  });
                                  _updatePreview();
                                },
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: RepaintBoundary(
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                      if (event is KeyDownEvent) {
                                        if (_keyRepeatTimer == null) {
                                          _startKeyRepeat(() {
                                            setState(() {
                                              segment.weight = (segment.weight + 0.05).clamp(0.1, 10.0);
                                              _weightControllers[segment.id]?.text = segment.weight.toStringAsFixed(1);
                                            });
                                            _updatePreview();
                                          });
                                        }
                                        return KeyEventResult.handled;
                                      } else if (event is KeyUpEvent) {
                                        _stopKeyRepeat();
                                        return KeyEventResult.handled;
                                      }
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                      if (event is KeyDownEvent) {
                                        if (_keyRepeatTimer == null) {
                                          _startKeyRepeat(() {
                                            setState(() {
                                              segment.weight = (segment.weight - 0.05).clamp(0.1, 10.0);
                                              _weightControllers[segment.id]?.text = segment.weight.toStringAsFixed(1);
                                            });
                                            _updatePreview();
                                          });
                                        }
                                        return KeyEventResult.handled;
                                      } else if (event is KeyUpEvent) {
                                        _stopKeyRepeat();
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      try {
                                        return TextField(
                                          controller: _weightControllers[segment.id],
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          decoration: const InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                          ),
                                          enableInteractiveSelection: _editingColorIndex != null || true,
                                          onChanged: (value) {
                                            try {
                                              final newValue = double.tryParse(value);
                                              if (newValue != null && newValue >= 0.05 && newValue <= 10.0) {
                                                segment.weight = newValue;
                                                _updatePreview();
                                              }
                                            } catch (e) {
                                              debugPrint('Error updating weight: $e');
                                            }
                                          },
                                        );
                                      } catch (e) {
                                        debugPrint('Error building weight TextField: $e');
                                        return Container();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                );

                final itemContent = Column(
                  children: [
                    card,
                    const SizedBox(height: 10),
                  ],
                );

                if (_editingColorIndex == null) {
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(segment.id),
                    index: index,
                    child: itemContent,
                  );
                } else {
                  return Container(
                    key: ValueKey(segment.id),
                    child: itemContent,
                  );
                }
              } catch (e) {
                debugPrint('Segment render error: $e');
                return Container(key: ValueKey('error_${_segments[index].id}'));
              }
            },
          ),
          const SizedBox(height: 10),
          _editorPillButton(
            icon: LucideIcons.plus,
            label: 'Add Segment',
            onTap: _addSegment,
            color: const Color(0xFF38BDF8),
            textColor: Colors.white,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _editorPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
    Color? borderColor,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segIconBtn(IconData icon, VoidCallback onTap, {Color color = const Color(0xFF1E1E2C), bool active = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 20, color: active ? const Color(0xFF38BDF8) : color),
        ),
      ),
    );
  }
}

class _SegmentData {
  final String id;
  String text;
  Color color;
  double weight;
  String? imagePath;
  String? iconName;

  _SegmentData({
    required this.id,
    required this.text,
    required this.color,
    required this.weight,
    this.imagePath,
    this.iconName,
  });
}

class _VisualConfigSheet extends StatefulWidget {
  final String? imagePath;
  final String? iconName;
  final ValueChanged<String> onImagePicked;
  final VoidCallback onImageRemoved;
  final ValueChanged<String> onIconSelected;
  final VoidCallback onIconRemoved;

  const _VisualConfigSheet({
    required this.imagePath,
    required this.iconName,
    required this.onImagePicked,
    required this.onImageRemoved,
    required this.onIconSelected,
    required this.onIconRemoved,
  });

  @override
  State<_VisualConfigSheet> createState() => _VisualConfigSheetState();
}

class _VisualConfigSheetState extends State<_VisualConfigSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.iconName != null ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          widget.onImagePicked(file.path!);
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
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
            width: 48, height: 5,
            decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Image'),
              Tab(text: 'Icon'),
            ],
          ),
          SizedBox(
            height: 420,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImageTab(),
                _buildIconTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          if (widget.imagePath != null) ...[
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD4D4D8), width: 1.5),
                image: DecorationImage(
                  image: FileImage(File(widget.imagePath!)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sheetPillButton(
              icon: LucideIcons.trash2,
              label: 'Remove Image',
              onTap: () {
                widget.onImageRemoved();
                Navigator.pop(context);
              },
              color: const Color(0xFFFEE2E2),
              textColor: const Color(0xFFEF4444),
              borderColor: const Color(0xFFFECACA),
            ),
            const SizedBox(height: 12),
          ],
          _sheetPillButton(
            icon: LucideIcons.imagePlus,
            label: widget.imagePath != null ? 'Change Image' : 'Choose Image',
            onTap: _pickImage,
            color: const Color(0xFFF4F4F5),
            textColor: const Color(0xFF1E1E2C),
            borderColor: const Color(0xFFD4D4D8),
          ),
        ],
      ),
    );
  }

  Widget _buildIconTab() {
    final iconEntries = lucideIconMap.entries.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          if (widget.iconName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _sheetPillButton(
                icon: LucideIcons.trash2,
                label: 'Remove Icon',
                onTap: () {
                  widget.onIconRemoved();
                  Navigator.pop(context);
                },
                color: const Color(0xFFFEE2E2),
                textColor: const Color(0xFFEF4444),
                borderColor: const Color(0xFFFECACA),
              ),
            ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: iconEntries.length,
              itemBuilder: (context, index) {
                final entry = iconEntries[index];
                final isSelected = widget.iconName == entry.key;
                return GestureDetector(
                  onTap: () {
                    widget.onIconSelected(entry.key);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFD4D4D8),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      size: 24,
                      color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E1E2C),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
    Color? borderColor,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.2), width: 4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
