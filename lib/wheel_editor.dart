import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'wheel_config.dart';
import 'wheel_item.dart';

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

  Future<void> _pickImage(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _segments[index].imagePath = file.path;
          });
          _updatePreview(immediate: true);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _segments[index].imagePath = null;
    });
    _updatePreview(immediate: true);
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



  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.initialConfig != null ? 'Edit Wheel' : 'Create Wheel',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Wheel Name',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
              onChanged: (value) {
                _updatePreview();
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Segment Text Size: ',
                  style: TextStyle(fontSize: 16),
                ),
                Expanded(
                  child: Slider(
                    value: _textSize,
                    min: 0.05,
                    max: 1.5,
                    divisions: 29,
                    label: _textSize.toStringAsFixed(2),
                    onChanged: (value) {
                      setState(() {
                        _textSize = value;
                        _textSizeController.text = value.toStringAsFixed(2);
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
                                _textSize = (_textSize + 0.05).clamp(0.05, 1.5);
                                _textSizeController.text = _textSize.toStringAsFixed(2);
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
                                _textSize = (_textSize - 0.05).clamp(0.05, 1.5);
                                _textSizeController.text = _textSize.toStringAsFixed(2);
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
                      controller: _textSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onChanged: (value) {
                        final newValue = double.tryParse(value);
                        if (newValue != null && newValue >= 0.05 && newValue <= 1.5) {
                          setState(() {
                            _textSize = newValue;
                            _textSizeController.text = newValue.toStringAsFixed(2);
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
                  'Header Text Size: ',
                  style: TextStyle(fontSize: 16),
                ),
                Expanded(
                  child: Slider(
                    value: _headerTextSize,
                    min: 0.05,
                    max: 2.0,
                    divisions: 200,
                    label: _headerTextSize.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _headerTextSize = value;
                        _headerTextSizeController.text = value.toStringAsFixed(1);
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
                                _headerTextSize = (_headerTextSize + 0.1).clamp(0.05, 2.0);
                                _headerTextSizeController.text = _headerTextSize.toStringAsFixed(1);
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
                                _headerTextSize = (_headerTextSize - 0.1).clamp(0.05, 2.0);
                                _headerTextSizeController.text = _headerTextSize.toStringAsFixed(1);
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
                      controller: _headerTextSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onChanged: (value) {
                        final newValue = double.tryParse(value);
                        if (newValue != null && newValue >= 0.05 && newValue <= 2.0) {
                          setState(() {
                            _headerTextSize = newValue;
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
                  'Image Size: ',
                  style: TextStyle(fontSize: 16),
                ),
                Expanded(
                  child: Slider(
                    value: _imageSize,
                    min: 20.0,
                    max: 150.0,
                    divisions: 130,
                    label: _imageSize.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        _imageSize = value;
                        _imageSizeController.text = value.toStringAsFixed(0);
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
                                _imageSize = (_imageSize + 1.0).clamp(20.0, 150.0);
                                _imageSizeController.text = _imageSize.toStringAsFixed(0);
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
                                _imageSize = (_imageSize - 1.0).clamp(20.0, 150.0);
                                _imageSizeController.text = _imageSize.toStringAsFixed(0);
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
                      controller: _imageSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onChanged: (value) {
                        final newValue = double.tryParse(value);
                        if (newValue != null && newValue >= 20.0 && newValue <= 150.0) {
                          setState(() {
                            _imageSize = newValue;
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
                        _cornerRadiusController.text = value.toStringAsFixed(1);
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
                                _cornerRadiusController.text = _cornerRadius.toStringAsFixed(1);
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
                                _cornerRadiusController.text = _cornerRadius.toStringAsFixed(1);
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
                      controller: _cornerRadiusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onChanged: (value) {
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
                        _strokeWidthController.text = value.toStringAsFixed(1);
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
                                _strokeWidthController.text = _strokeWidth.toStringAsFixed(1);
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
                                _strokeWidthController.text = _strokeWidth.toStringAsFixed(1);
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
                      controller: _strokeWidthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onChanged: (value) {
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
                        _centerMarkerSizeController.text = value.toStringAsFixed(0);
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
                                _centerMarkerSize = (_centerMarkerSize + 1.0).clamp(100.0, 250.0);
                                _centerMarkerSizeController.text = _centerMarkerSize.toStringAsFixed(0);
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
                                _centerMarkerSize = (_centerMarkerSize - 1.0).clamp(100.0, 250.0);
                                _centerMarkerSizeController.text = _centerMarkerSize.toStringAsFixed(0);
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
                      controller: _centerMarkerSizeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      onChanged: (value) {
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
              onReorder: (oldIndex, newIndex) {
                try {
                  _reorderSegments(oldIndex, newIndex);
                } catch (e) {
                  // Ignore Flutter rendering assertions during reorder
                  debugPrint('Reorder error (safe to ignore): $e');
                }
              },
              itemBuilder: (context, index) {
                try {
                  final segment = _segments[index];
                  final card = Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey, width: 1.5),
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
                              child: RepaintBoundary(
                                child: Builder(
                                  builder: (context) {
                                    try {
                                      return TextField(
                                        decoration: const InputDecoration(
                                          labelText: 'Text',
                                          border: OutlineInputBorder(),
                                        ),
                                        controller: _segmentTextControllers[segment.id],
                                        // Disable text selection during drag to prevent rendering assertions
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
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                segment.imagePath != null ? Icons.image : Icons.add_photo_alternate,
                                color: segment.imagePath != null ? Colors.blue : null,
                              ),
                              onPressed: () => _pickImage(index),
                              tooltip: segment.imagePath != null ? 'Change image' : 'Add image',
                            ),
                            if (segment.imagePath != null)
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeImage(index),
                                tooltip: 'Remove image',
                                iconSize: 20,
                              ),
                            IconButton(
                              icon: const Icon(Icons.content_copy),
                              onPressed: () => _duplicateSegment(index),
                              tooltip: 'Duplicate segment',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeSegment(index),
                              color: Colors.red,
                              tooltip: 'Delete segment',
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
                                      _hexControllers[segment.id]?.text = _colorToHex(color);
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
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _hexControllers.putIfAbsent(
                                    segment.id,
                                    () => TextEditingController(text: _colorToHex(segment.color)),
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Hex',
                                    border: OutlineInputBorder(),
                                    prefixText: '',
                                  ),
                                  maxLength: 6,
                                  onSubmitted: (value) {
                                    final c = _hexToColor(value);
                                    if (c != null) {
                                      setState(() {
                                        segment.color = c;
                                      });
                                      _updatePreview();
                                    }
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
                              width: 60,
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
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                          ),
                                          // Disable text selection during drag to prevent rendering assertions
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
                );

                  // Only allow reordering when no color picker is active
                  if (_editingColorIndex == null) {
                    return ReorderableDragStartListener(
                      key: ValueKey(segment.id),
                      index: index,
                      child: RepaintBoundary(child: card),
                    );
                  } else {
                    return Container(
                      key: ValueKey(segment.id),
                      child: RepaintBoundary(child: card),
                    );
                  }
                } catch (e) {
                  // Fallback for rendering errors
                  debugPrint('Segment render error: $e');
                  return Container(key: ValueKey('error_${_segments[index].id}'));
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
  final String id;
  String text;
  Color color;
  double weight;
  String? imagePath;

  _SegmentData({
    required this.id,
    required this.text,
    required this.color,
    required this.weight,
    this.imagePath,
  });
}
