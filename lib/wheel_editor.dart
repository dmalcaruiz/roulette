import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'wheel_config.dart';
import 'wheel_item.dart';
import 'icon_map.dart';
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

class WheelEditor extends StatefulWidget {
  final WheelConfig? initialConfig;
  final Function(WheelConfig)? onSave;
  final VoidCallback? onCancel;
  final Function(WheelConfig)? onPreview;
  final VoidCallback? onClose;

  const WheelEditor({
    super.key,
    this.initialConfig,
    this.onSave,
    this.onCancel,
    this.onPreview,
    this.onClose,
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
  int? _expandedSegmentIndex;
  Timer? _keyRepeatTimer;
  Timer? _previewDebounceTimer;
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _segmentTextControllers = {};
  final Map<String, TextEditingController> _hexControllers = {};
  final Map<String, FocusNode> _segmentFocusNodes = {};
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
    for (var node in _segmentFocusNodes.values) {
      node.dispose();
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
        _segmentFocusNodes[segment.id]?.dispose();
        _segmentFocusNodes.remove(segment.id);
        _expandedSegmentIndex = null;
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
      _expandedSegmentIndex = null;
    });
    _updatePreview(immediate: true);
  }

  void _pickColor(int index) {
    final segment = _segments[index];
    // Non-modal bottom sheet so the wheel is still visible behind
    showBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          // Calculate height: parent sheet snap (460) - 24
          final sheetHeight = 460.0 - 24.0;
          return Container(
            height: sheetHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4)),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 48, height: 5,
                  decoration: BoxDecoration(color: const Color(0xFFD4D4D8), borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(height: 16),
                const Text('Segment Color', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        ColorPicker(
                          color: segment.color,
                          onColorChanged: (Color color) {
                            setState(() {
                              segment.color = color;
                              _hexControllers[segment.id]?.text = _colorToHex(color);
                            });
                            setSheetState(() {});
                            _updatePreview();
                          },
                          wheelDiameter: 220,
                          wheelWidth: 22,
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
                              setSheetState(() {});
                              _updatePreview();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
      padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.initialConfig != null ? 'Edit Wheel' : 'Edit Wheel',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (widget.onClose != null)
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(LucideIcons.x, size: 16, color: Color(0xFF1E1E2C)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
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
                final isExpanded = _expandedSegmentIndex == index;

                final card = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedSegmentIndex = null;
                      } else {
                        _expandedSegmentIndex = index;
                        if (!foundation.kIsWeb) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _segmentFocusNodes[segment.id]?.requestFocus();
                          });
                        }
                      }
                    });
                  },
                  child: _SegmentCard3D(
                  color: isExpanded ? Colors.white : segment.color,
                  expandedBorderColor: isExpanded ? segment.color : null,
                  child: Column(
                    children: [
                      // ── Collapsed row (always visible) ──
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Drag handle icon (visual only — drag listener is stacked on top)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Center(
                                child: Icon(
                                  LucideIcons.gripVertical,
                                  size: 22,
                                  color: isExpanded
                                      ? const Color(0xFF1E1E2C).withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            // Name field
                            Expanded(
                              child: IgnorePointer(
                                ignoring: !isExpanded,
                                child: TextField(
                                  controller: _segmentTextControllers[segment.id],
                                  focusNode: _segmentFocusNodes.putIfAbsent(segment.id, () => FocusNode()),
                                  maxLines: 1,
                                  cursorColor: isExpanded ? null : Colors.transparent,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: isExpanded ? const Color(0xFF1E1E2C) : Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    hintText: 'Segment name',
                                    hintStyle: TextStyle(
                                      color: isExpanded
                                          ? const Color(0xFF1E1E2C).withValues(alpha: 0.35)
                                          : Colors.white.withValues(alpha: 0.6),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isExpanded ? const Color(0xFFD4D4D8) : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: isExpanded ? const Color(0xFF38BDF8) : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isExpanded ? const Color(0xFFF8F8F9) : Colors.transparent,
                                  ),
                                  onChanged: (value) {
                                    segment.text = value;
                                    _updatePreview();
                                  },
                                ),
                              ),
                            ),
                            // Chevron
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                              child: AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  LucideIcons.chevronDown,
                                  size: 26,
                                  color: isExpanded
                                      ? const Color(0xFF1E1E2C).withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                      // ── Expanded editing content ──
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: isExpanded
                            ? GestureDetector(
                                onTap: () {}, // Absorb taps on expanded content so they don't collapse
                                child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                child: Column(
                                  children: [
                                    // Row 1: Weight with +/- buttons
                                    Row(
                                      children: [
                                        // Minus button
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              segment.weight = (segment.weight - 0.1).clamp(0.1, 10.0);
                                              _weightControllers[segment.id]?.text = segment.weight.toStringAsFixed(1);
                                            });
                                            _updatePreview();
                                          },
                                          onLongPressStart: (_) {
                                            _startKeyRepeat(() {
                                              setState(() {
                                                segment.weight = (segment.weight - 0.1).clamp(0.1, 10.0);
                                                _weightControllers[segment.id]?.text = segment.weight.toStringAsFixed(1);
                                              });
                                              _updatePreview();
                                            });
                                          },
                                          onLongPressEnd: (_) => _stopKeyRepeat(),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF4F4F5),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE4E4E7), width: 1.5),
                                            ),
                                            child: Icon(LucideIcons.minus, size: 20, color: const Color(0xFF1E1E2C).withValues(alpha: 0.5)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Weight label + value + slider
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Weight',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                  Text(
                                                    segment.weight.toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF1E1E2C),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Slider(
                                                value: segment.weight,
                                                min: 0.1,
                                                max: 10.0,
                                                divisions: 99,
                                                onChanged: (value) {
                                                  setState(() {
                                                    segment.weight = value;
                                                    _weightControllers[segment.id]?.text = value.toStringAsFixed(1);
                                                  });
                                                  _updatePreview();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Plus button
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              segment.weight = (segment.weight + 0.1).clamp(0.1, 10.0);
                                              _weightControllers[segment.id]?.text = segment.weight.toStringAsFixed(1);
                                            });
                                            _updatePreview();
                                          },
                                          onLongPressStart: (_) {
                                            _startKeyRepeat(() {
                                              setState(() {
                                                segment.weight = (segment.weight + 0.1).clamp(0.1, 10.0);
                                                _weightControllers[segment.id]?.text = segment.weight.toStringAsFixed(1);
                                              });
                                              _updatePreview();
                                            });
                                          },
                                          onLongPressEnd: (_) => _stopKeyRepeat(),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF4F4F5),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE4E4E7), width: 1.5),
                                            ),
                                            child: Icon(LucideIcons.plus, size: 20, color: const Color(0xFF1E1E2C).withValues(alpha: 0.5)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Row 3: Icon + Color split
                                    Row(
                                      children: [
                                        // Icon / Image button
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _openVisualConfigSheet(index),
                                            child: Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF4F4F5),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE4E4E7), width: 1.5),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    segment.imagePath != null
                                                        ? LucideIcons.image
                                                        : segment.iconName != null
                                                            ? LucideIcons.smile
                                                            : LucideIcons.imagePlus,
                                                    size: 18,
                                                    color: (segment.imagePath != null || segment.iconName != null)
                                                        ? const Color(0xFF38BDF8)
                                                        : const Color(0xFF1E1E2C).withValues(alpha: 0.45),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Icon',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Color button
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _pickColor(index),
                                            child: Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF4F4F5),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE4E4E7), width: 1.5),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      color: segment.color,
                                                      borderRadius: BorderRadius.circular(5),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Color',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                );

                final swipeableCard = SwipeableActionCell(
                  trailingActions: [
                    SwipeableAction(
                      color: const Color(0xFF38BDF8),
                      icon: LucideIcons.copy,
                      onTap: () => _duplicateSegment(index),
                    ),
                    SwipeableAction(
                      color: const Color(0xFFEF4444),
                      icon: LucideIcons.trash2,
                      onTap: () => _removeSegment(index),
                      expandOnFullSwipe: true,
                    ),
                  ],
                  child: card,
                );

                return Padding(
                  key: ValueKey(segment.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      swipeableCard,
                      // Drag listener on top — covers full card height, 45px wide
                      // Taps pass through to expand/collapse; drags trigger reorder
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
                                if (isExpanded) {
                                  _expandedSegmentIndex = null;
                                } else {
                                  _expandedSegmentIndex = index;
                                  if (!foundation.kIsWeb) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _segmentFocusNodes[segment.id]?.requestFocus();
                                    });
                                  }
                                }
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
            color: const Color(0xFF1E1E2C),
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
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );

    if (borderColor != null) {
      // Flat style (e.g. Wheel Settings) — no push-down effect
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: child,
        ),
      );
    }

    // Chunky style (e.g. Add Segment) — push-down effect
    return PushDownButton(
      color: color,
      onTap: onTap,
      child: child,
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
          if (widget.imagePath != null && !foundation.kIsWeb) ...[
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD4D4D8), width: 1.5),
              ),
              child: const Center(
                child: Icon(LucideIcons.image, size: 40, color: Color(0xFFD4D4D8)),
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
    return PushDownButton(
      color: color,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _SegmentCard3D extends StatelessWidget {
  final Color color;
  final Color? expandedBorderColor;
  final Widget child;

  static const double _bottomDepth = 6.5;
  static const double _innerStrokeWidth = 2.5;
  static const double _borderRadius = 21;

  const _SegmentCard3D({
    required this.color,
    this.expandedBorderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final shadowSource = expandedBorderColor ?? color;
    final bottomColor = oklchShadow(shadowSource);
    final bottomStrokeColor = oklchShadow(shadowSource, lightnessReduction: 0.16);
    final innerStrokeColor = oklchShadow(color, lightnessReduction: 0.06);
    final isExpanded = expandedBorderColor != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bottom face — positioned behind, offset down by depth
        Positioned(
          left: 0,
          right: 0,
          top: _bottomDepth,
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: bottomColor,
              borderRadius: BorderRadius.circular(_borderRadius),
              border: Border.all(
                color: bottomStrokeColor,
                width: _innerStrokeWidth,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
          ),
        ),
        // Top face — determines stack height, padded for depth
        Padding(
          padding: const EdgeInsets.only(bottom: _bottomDepth),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(_borderRadius),
              border: Border.all(
                color: isExpanded ? expandedBorderColor! : innerStrokeColor,
                width: isExpanded ? 3 : _innerStrokeWidth,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ],
    );
  }
}
