import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'wheel_config.dart';
import 'wheel_item.dart';

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
  late double _cornerRadius;
  late double _strokeWidth;
  late bool _showBackgroundCircle;
  late double _centerMarkerSize;
  int? _editingColorIndex;
  Timer? _keyRepeatTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialConfig != null) {
      _nameController = TextEditingController(text: widget.initialConfig!.name);
      _segments = widget.initialConfig!.items.map((item) => _SegmentData(
        text: item.text,
        color: item.color,
        weight: item.weight,
      )).toList();
      _textSize = widget.initialConfig!.textSize;
      _cornerRadius = widget.initialConfig!.cornerRadius;
      _strokeWidth = widget.initialConfig!.strokeWidth;
      _showBackgroundCircle = widget.initialConfig!.showBackgroundCircle;
      _centerMarkerSize = widget.initialConfig!.centerMarkerSize;
    } else {
      _nameController = TextEditingController(text: 'New Wheel');
      _segments = [
        _SegmentData(text: 'Option 1', color: Colors.red, weight: 1.0),
        _SegmentData(text: 'Option 2', color: Colors.blue, weight: 1.0),
      ];
      _textSize = 1.0;
      _cornerRadius = 8.0;
      _strokeWidth = 3.0;
      _showBackgroundCircle = true;
      _centerMarkerSize = 200.0;
    }

    // Trigger initial preview
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePreview();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyRepeatTimer?.cancel();
    super.dispose();
  }

  void _startKeyRepeat(VoidCallback action) {
    _keyRepeatTimer?.cancel();
    action(); // Execute immediately
    _keyRepeatTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      action();
    });
  }

  void _stopKeyRepeat() {
    _keyRepeatTimer?.cancel();
    _keyRepeatTimer = null;
  }

  void _addSegment() {
    setState(() {
      _segments.add(_SegmentData(
        text: 'Option ${_segments.length + 1}',
        color: _getNextColor(),
        weight: 1.0,
      ));
    });
    _updatePreview();
  }

  Color _getNextColor() {
    final colors = [
      Colors.red, Colors.blue, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.amber,
      Colors.cyan, Colors.lime, Colors.indigo, Colors.brown,
    ];
    return colors[_segments.length % colors.length];
  }

  void _removeSegment(int index) {
    if (_segments.length > 2) {
      setState(() {
        _segments.removeAt(index);
      });
      _updatePreview();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wheel must have at least 2 segments')),
      );
    }
  }

  void _reorderSegments(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final segment = _segments.removeAt(oldIndex);
      _segments.insert(newIndex, segment);
    });
    _updatePreview();
  }

  void _pickColor(int index) {
    setState(() {
      _editingColorIndex = _editingColorIndex == index ? null : index;
    });
  }

  void _updatePreview() {
    if (widget.onPreview != null && _nameController.text.trim().isNotEmpty) {
      final config = WheelConfig(
        id: widget.initialConfig?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        items: _segments.map((seg) => WheelItem(
          text: seg.text,
          color: seg.color,
          weight: seg.weight,
        )).toList(),
        textSize: _textSize,
        cornerRadius: _cornerRadius,
        strokeWidth: _strokeWidth,
        showBackgroundCircle: _showBackgroundCircle,
        centerMarkerSize: _centerMarkerSize,
      );
      widget.onPreview!(config);
    }
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

  void _close() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a wheel name before closing')),
      );
      return;
    }

    final config = WheelConfig(
      id: widget.initialConfig?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      items: _segments.map((seg) => WheelItem(
        text: seg.text,
        color: seg.color,
        weight: seg.weight,
      )).toList(),
      textSize: _textSize,
      cornerRadius: _cornerRadius,
      strokeWidth: _strokeWidth,
      showBackgroundCircle: _showBackgroundCircle,
      centerMarkerSize: _centerMarkerSize,
    );

    if (widget.onSave != null) {
      widget.onSave!(config);
    } else {
      Navigator.of(context).pop(config);
    }
  }

  void _cancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initialConfig != null ? 'Edit Wheel' : 'Create Wheel',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Wheel Name',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Text Size: ',
                  style: TextStyle(fontSize: 16),
                ),
                Expanded(
                  child: Slider(
                    value: _textSize,
                    min: 0.051,
                    max: 1.0,
                    divisions: 200,
                    label: _textSize.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _textSize = value;
                      });
                      _updatePreview();
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        if (event is KeyDownEvent) {
                          if (_keyRepeatTimer == null) {
                            _startKeyRepeat(() {
                              setState(() {
                                _textSize = (_textSize + 0.1).clamp(0.051, 1.0);
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
                                _textSize = (_textSize - 0.1).clamp(0.051, 1.0);
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
                    child: TextField(
                      controller: TextEditingController(text: _textSize.toStringAsFixed(1))
                        ..selection = TextSelection.collapsed(offset: _textSize.toStringAsFixed(1).length),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onSubmitted: (value) {
                        final newValue = double.tryParse(value);
                        if (newValue != null && newValue >= 0.051 && newValue <= 1.0) {
                          setState(() {
                            _textSize = newValue;
                          });
                          _updatePreview();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Corner Radius: ',
                  style: TextStyle(fontSize: 16),
                ),
                Expanded(
                  child: Slider(
                    value: _cornerRadius,
                    min: 0.0,
                    max: 100.0,
                    divisions: 40,
                    label: _cornerRadius.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _cornerRadius = value;
                      });
                      _updatePreview();
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        if (event is KeyDownEvent) {
                          if (_keyRepeatTimer == null) {
                            _startKeyRepeat(() {
                              setState(() {
                                _cornerRadius = (_cornerRadius + 0.1).clamp(0.0, 100.0);
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
                                _cornerRadius = (_cornerRadius - 0.1).clamp(0.0, 100.0);
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
                    child: TextField(
                      controller: TextEditingController(text: _cornerRadius.toStringAsFixed(1))
                        ..selection = TextSelection.collapsed(offset: _cornerRadius.toStringAsFixed(1).length),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onSubmitted: (value) {
                        final newValue = double.tryParse(value);
                        if (newValue != null && newValue >= 0.0 && newValue <= 100.0) {
                          setState(() {
                            _cornerRadius = newValue;
                          });
                          _updatePreview();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Stroke Width: ',
                  style: TextStyle(fontSize: 16),
                ),
                Expanded(
                  child: Slider(
                    value: _strokeWidth,
                    min: 0.0,
                    max: 10.0,
                    divisions: 100,
                    label: _strokeWidth.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _strokeWidth = value;
                      });
                      _updatePreview();
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        if (event is KeyDownEvent) {
                          if (_keyRepeatTimer == null) {
                            _startKeyRepeat(() {
                              setState(() {
                                _strokeWidth = (_strokeWidth + 0.1).clamp(0.0, 10.0);
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
                                _strokeWidth = (_strokeWidth - 0.1).clamp(0.0, 10.0);
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
                    child: TextField(
                      controller: TextEditingController(text: _strokeWidth.toStringAsFixed(1))
                        ..selection = TextSelection.collapsed(offset: _strokeWidth.toStringAsFixed(1).length),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onSubmitted: (value) {
                        final newValue = double.tryParse(value);
                        if (newValue != null && newValue >= 0.0 && newValue <= 10.0) {
                          setState(() {
                            _strokeWidth = newValue;
                          });
                          _updatePreview();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _showBackgroundCircle,
                  onChanged: (value) {
                    setState(() {
                      _showBackgroundCircle = value ?? true;
                    });
                    _updatePreview();
                  },
                ),
                const Text(
                  'Show background circle',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Center Marker Size: ',
                  style: TextStyle(fontSize: 16),
                ),
                Expanded(
                  child: Slider(
                    value: _centerMarkerSize,
                    min: 100.0,
                    max: 250.0,
                    divisions: 150,
                    label: _centerMarkerSize.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        _centerMarkerSize = value;
                      });
                      _updatePreview();
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        if (event is KeyDownEvent) {
                          if (_keyRepeatTimer == null) {
                            _startKeyRepeat(() {
                              setState(() {
                                _centerMarkerSize = (_centerMarkerSize + 0.1).clamp(100.0, 250.0);
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
                                _centerMarkerSize = (_centerMarkerSize - 0.1).clamp(100.0, 250.0);
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
                    child: TextField(
                      controller: TextEditingController(text: _centerMarkerSize.toStringAsFixed(0))
                        ..selection = TextSelection.collapsed(offset: _centerMarkerSize.toStringAsFixed(0).length),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onSubmitted: (value) {
                        final newValue = double.tryParse(value);
                        if (newValue != null && newValue >= 100.0 && newValue <= 250.0) {
                          setState(() {
                            _centerMarkerSize = newValue;
                          });
                          _updatePreview();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Segments',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _segments.length,
              onReorder: _reorderSegments,
              itemBuilder: (context, index) {
                final segment = _segments[index];
                final card = Card(
                  key: ValueKey('segment_$index'),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.grey, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _pickColor(index),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: segment.color,
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.color_lens, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Text',
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(text: segment.text)
                                  ..selection = TextSelection.fromPosition(
                                    TextPosition(offset: segment.text.length),
                                  ),
                                onChanged: (value) {
                                  segment.text = value;
                                  _updatePreview();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeSegment(index),
                              color: Colors.red,
                            ),
                          ],
                        ),
                        if (_editingColorIndex == index) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                ColorPicker(
                                  color: segment.color,
                                  onColorChanged: (Color color) {
                                    setState(() {
                                      segment.color = color;
                                    });
                                    _updatePreview();
                                  },
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
                                _buildHSBSlider(
                                  'Hue',
                                  HSVColor.fromColor(segment.color).hue,
                                  0,
                                  360,
                                  (value) {
                                    final hsv = HSVColor.fromColor(segment.color);
                                    setState(() {
                                      segment.color = hsv.withHue(value).toColor();
                                    });
                                    _updatePreview();
                                  },
                                ),
                                _buildHSBSlider(
                                  'Saturation',
                                  HSVColor.fromColor(segment.color).saturation,
                                  0,
                                  1,
                                  (value) {
                                    final hsv = HSVColor.fromColor(segment.color);
                                    setState(() {
                                      segment.color = hsv.withSaturation(value).toColor();
                                    });
                                    _updatePreview();
                                  },
                                ),
                                _buildHSBSlider(
                                  'Brightness',
                                  HSVColor.fromColor(segment.color).value,
                                  0,
                                  1,
                                  (value) {
                                    final hsv = HSVColor.fromColor(segment.color);
                                    setState(() {
                                      segment.color = hsv.withValue(value).toColor();
                                    });
                                    _updatePreview();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Weight: ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Slider(
                                value: segment.weight,
                                min: 0.1,
                                max: 10.0,
                                divisions: 99,
                                label: segment.weight.toStringAsFixed(1),
                                onChanged: (value) {
                                  setState(() {
                                    segment.weight = value;
                                  });
                                  _updatePreview();
                                },
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                segment.weight.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                );

                // Only allow reordering when no color picker is active
                if (_editingColorIndex == null) {
                  return ReorderableDragStartListener(
                    key: ValueKey('drag_$index'),
                    index: index,
                    child: card,
                  );
                } else {
                  return card;
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
                onTap: _addSegment,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      Icon(Icons.add, color: Colors.white),
                      SizedBox(width: 16),
                      Text(
                        'Add Segment',
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
            const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SegmentData {
  String text;
  Color color;
  double weight;

  _SegmentData({
    required this.text,
    required this.color,
    required this.weight,
  });
}
