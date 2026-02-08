import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snapping_sheet_2/snapping_sheet.dart';
import '../widgets/sliders/perceptual_slider_controls.dart';
import '../widgets/sliders/digital_color_controls.dart';
import '../widgets/color grid/reorderable_color_grid_view.dart';
import '../widgets/home/sheet_grabbing_handle.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/delete_zone_overlay.dart';
import '../widgets/home/bottom_action_bar.dart';
import '../widgets/home/undo_redo_buttons.dart';
import '../models/color_grid_item.dart';
import '../models/extreme_color_item.dart';
import '../services/undo_redo_service.dart';
import '../services/clipboard_service.dart';
import '../coordinators/state_history_coordinator.dart';
import '../controllers/drag_drop_controller.dart';
import '../state/color_editor_provider.dart';
import '../state/color_grid_provider.dart';
import '../state/extreme_colors_provider.dart';
import '../state/bg_color_provider.dart';
import '../state/settings_provider.dart';
import '../state/sheet_state_provider.dart';
import '../state/saved_palettes_provider.dart';
import '../services/icc_color_service.dart';
import '../utils/color_operations.dart';
import '../utils/ui_color_utils.dart';
import '../cyclop_eyedropper/eye_dropper_layer.dart';

// Custom scroll physics that resists scrolling and pulls back to position 0
class ResistantScrollPhysics extends ScrollPhysics {
  const ResistantScrollPhysics({super.parent});

  @override
  ResistantScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ResistantScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Reduce the scroll offset to create resistance
    // The further from 0, the more resistance
    final resistanceFactor = 0.4; // Lower = more resistance
    return offset * resistanceFactor;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Allow scrolling beyond bounds with resistance (no clamping)
    // This ensures resistance continues even at the end
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Create a spring simulation that pulls back to position 0
    final SpringDescription spring = SpringDescription.withDampingRatio(
      mass: 0.5,
      stiffness: 100.0,
      ratio: 1.0,
    );

    // Always pull back to position 0 (scroll offset 0)
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      0.0, // Target position (top)
      velocity,
      tolerance: tolerance,
    );
  }
}

// Color Picker Home Screen
//
// Orchestrates the main color picker UI using Providers for state management.
// Coordination logic lives here where we have easy access to all providers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // ================================================
  // ========== Widget-Scoped Objects ===============
  // ================================================
  //
  // These live in the widget's state and are disposed with the widget.
  //
  // DragDropController:
  //   - Manages UI state for drag-drop behavior (drag position, delete zone)
  //   - Extends ChangeNotifier for reactive UI updates
  //   - Lives here because it's widget-scoped, not app-wide
  //
  // StateHistoryCoordinator:
  //   - Orchestrates undo/redo across ALL providers
  //   - Captures and restores state snapshots
  //   - Lives here because it needs references to all providers
  //
  // UndoRedoService:
  //   - Manages the undo/redo history stack
  //   - Maintains state (undo stack, redo stack, current state)
  //   - Extends ChangeNotifier to notify on history changes

  late DragDropController _dragDropController;
  late StateHistoryCoordinator _coordinator;
  final UndoRedoService _undoRedoService = UndoRedoService(maxHistorySize: 100);

  // ================================================
  // ========== Widget UI State =====================
  // ================================================
  //
  // Local UI state that doesn't need to be shared across the app.
  // This is ephemeral state tied to this widget's lifecycle.
  //
  // - SnappingSheetController: Controls the bottom sheet position/animations
  // - _currentSheetHeight: Tracks sheet height for layout adjustments
  // - ScrollController: Controls scrolling behavior
  // - _isInteractingWithSlider: Prevents sheet dragging during slider interaction
  // - _selectedChips: Toggle states for chip filters (currently unused?)

  final SnappingSheetController snappingSheetController = SnappingSheetController();
  final ValueNotifier<double> _currentSheetHeight = ValueNotifier(0.0);
  final ScrollController scrollController = ScrollController();
  bool _isInteractingWithSlider = false;
  double _rowModifier = 0.0; // Virtual row modifier for resize effect (0.0 to 2.0+)
  Timer? _autoSaveTimer;
  bool _hasAutoSnappedUp = false; // Track if we've done initial auto-snap (first tap)
  bool _hasReturnedToLowSnap = false; // Track if returned to low snap after first auto-snap
  int _selectionCountAfterReturn = 0; // Count selections after returning to low snap
  String? _lastSelectedItemId; // Track last selected item to detect box changes

  // ================================================
  // ========== Lifecycle & Initialization ==========
  // ================================================
  // Widget lifecycle methods that set up and tear down resources.

  // initState():
  //   1. Creates widget-scoped objects (Coordinator, Controller, Service)
  //   2. Loads sample grid data (deferred to postFrameCallback)
  //   3. Initializes ICC color profile asynchronously
  @override
  void initState() {
    super.initState();

    // Create state history coordinator (needs references to all providers)
    _coordinator = StateHistoryCoordinator(
      colorEditor: context.read<ColorEditorProvider>(),
      grid: context.read<ColorGridProvider>(),
      extremes: context.read<ExtremeColorsProvider>(),
      bgColor: context.read<BgColorProvider>(),
      settings: context.read<SettingsProvider>(),
      undoRedo: _undoRedoService,
    );

    // Create drag & drop controller (manages drag UI state)
    _dragDropController = DragDropController(
      gridProvider: context.read<ColorGridProvider>(),
      settingsProvider: context.read<SettingsProvider>(),
      coordinator: _coordinator,
    );

    // Defer state-modifying operations until after first build
    // (Can't modify provider state during initState)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSampleGrid();
      _coordinator.saveState('Initial state');
    });

    // Load ICC profile asynchronously (doesn't block UI)
    _initializeIccProfile();

    // Start auto-save timer (saves palette every 3 seconds)
    _startAutoSaveTimer();
  }

  // Loads sample colors into the grid on first launch
  void _initializeSampleGrid() {
    final sampleColors = [
      ColorGridItem.fromColor(const Color.fromARGB(255, 240, 98, 82), name: 'Red'),
      ColorGridItem.fromColor(const Color.fromARGB(255, 87, 165, 218), name: 'Blue'),
      ColorGridItem.fromColor(const Color.fromARGB(255, 85, 219, 141), name: 'Green'),
      ColorGridItem.fromColor(const Color.fromARGB(255, 255, 190, 86), name: 'Orange'),
      ColorGridItem.fromColor(const Color.fromARGB(255, 168, 100, 253), name: 'Purple'),
    ];
    context.read<ColorGridProvider>().syncFromSnapshot(sampleColors);

    // Initialize ColorEditorProvider with the first sample color
    // This ensures the add button works immediately on app launch
    final colorEditor = context.read<ColorEditorProvider>();
    colorEditor.setFromOklchValues(sampleColors.first.oklchValues!);
  }

  // Loads ICC color profile for "Real Pigments Only" feature
  //
  // Runs asynchronously - app works fine if this fails
  Future<void> _initializeIccProfile() async {
    try {
      const profilePath = 'reference-icc/Canon ImagePROGRAPH PRO-1000.icc';
      final profileData = await rootBundle.load(profilePath);
      final bytes = profileData.buffer.asUint8List();
      final success = await IccColorManager.instance.initialize(bytes);

      if (success) {
        debugPrint('✓ ICC Profile loaded successfully');
      } else {
        debugPrint('⚠ ICC Profile initialization failed');
      }
    } catch (e) {
      debugPrint('⚠ ICC Profile loading error: $e');
    }
  }

  // Starts auto-save timer that saves palette every 3 seconds
  void _startAutoSaveTimer() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _autoSavePalette();
    });
  }

  // Auto-saves the current palette
  Future<void> _autoSavePalette() async {
    final grid = context.read<ColorGridProvider>();
    final palettes = context.read<SavedPalettesProvider>();

    // Only save if there are colors in the grid
    if (grid.items.isNotEmpty) {
      await palettes.saveCurrentPalette(grid.items);
      debugPrint('Auto-saved palette');
    }
  }

  // dispose():
  //   Cleans up all resources to prevent memory leaks
  @override
  void dispose() {
    // Cancel auto-save timer
    _autoSaveTimer?.cancel();

    // Clean up singleton service
    IccColorManager.instance.dispose();

    // Clean up widget-scoped objects
    _undoRedoService.dispose();
    _dragDropController.dispose();
    scrollController.dispose();
    _currentSheetHeight.dispose();

    // Call the parent class's dispose method to complete widget lifecycle, after this,
    //the widget is dead and doesnt access any resources.
    super.dispose();
  }

  // ================================================
  // ========== Cross-Provider Coordination =========
  // ================================================
  //
  // These methods coordinate operations across multiple providers.
  // They live here because they need access to all providers via context.read<>()
  //
  // This is the "glue code" that makes providers work together.

  // ========== Color Update Coordination ===========

  // Handles OKLCH color changes from sliders
  void _handleOklchChanged({
    required double lightness,
    required double chroma,
    required double hue,
    double alpha = 1.0,
  }) {
    final colorEditor = context.read<ColorEditorProvider>();
    final grid = context.read<ColorGridProvider>();
    final extremes = context.read<ExtremeColorsProvider>();
    final bgColor = context.read<BgColorProvider>();

    // Update ColorEditorProvider (source of truth)
    colorEditor.updateOklch(
      lightness: lightness,
      chroma: chroma,
      hue: hue,
      alpha: alpha,
    );

    // Coordinate with selected item
    final selectedItem = grid.selectedItem;

    if (selectedItem != null) {
      grid.updateItemOklch(
        itemId: selectedItem.id,
        lightness: lightness,
        chroma: chroma,
        hue: hue,
        alpha: alpha,
      );
      _coordinator.saveState('Modified ${selectedItem.name ?? "color"}');
    } else if (extremes.selectedExtremeId != null) {
      extremes.updateExtremeOklch(
        extremeId: extremes.selectedExtremeId!,
        lightness: lightness,
        chroma: chroma,
        hue: hue,
        alpha: alpha,
      );
      final extremeName = extremes.selectedExtremeId == 'left' ? 'left' : 'right';
      _coordinator.saveState('Modified $extremeName extreme');
    } else if (bgColor.isSelected) {
      bgColor.updateOklch(
        lightness: lightness,
        chroma: chroma,
        hue: hue,
        alpha: alpha,
      );
      _coordinator.saveState('Modified background color');
    }
  }

  // Converts sRGB Color to OKLCH and delegates to _handleOklchChanged
  void _handleColorChanged(Color? color) {
    if (color == null) return;
    final oklch = srgbToOklch(color);
    _handleOklchChanged(
      lightness: oklch.l,
      chroma: oklch.c,
      hue: oklch.h,
      alpha: oklch.alpha,
    );
  }

  // Handles color selection from eyedropper or paste
  void _handleColorSelection(Color color) {
    _handleColorChanged(color);
    _coordinator.saveState('Color selected from eyedropper/paste');
  }

  // Applies ICC color profile filter if "Real Pigments Only" is enabled
  //
  // Transforms colors through printer gamut (sRGB → Lab → CMYK → Lab → sRGB)
  // Returns original color if filter is disabled or ICC profile not loaded
  Color _applyIccFilter(Color idealColor, {
    double? lightness,
    double? chroma,
    double? hue,
    double? alpha,
  }) {
    final settings = context.read<SettingsProvider>();
    if (!settings.useRealPigmentsOnly || !IccColorManager.instance.isReady) {
      return idealColor;
    }

    final colorEditor = context.read<ColorEditorProvider>();
    final l = lightness ?? colorEditor.lightness ?? 0.5;
    final c = chroma ?? colorEditor.chroma ?? 0.0;
    final h = hue ?? colorEditor.hue ?? 0.0;
    final a = alpha ?? 1.0;

    try {
      final cieLab = oklchToCieLab(l, c, h);
      final mappedLab = IccColorManager.instance.transformLab(cieLab.l, cieLab.a, cieLab.b);
      final mappedOklch = cieLabToOklch(mappedLab[0], mappedLab[1], mappedLab[2]);
      return colorFromOklch(mappedOklch.l, mappedOklch.c, mappedOklch.h, a);
    } catch (e) {
      debugPrint('⚠ ICC filter error: $e');
      return idealColor;
    }
  }

  // ========== Selection Coordination ============

  // When user selects something (grid item, extreme, background),
  // we need to:
  // 1. Deselect everything else across all providers
  // 2. Select the new item
  // 3. Update ColorEditorProvider with the selected color
  // 4. Optionally auto-copy to clipboard

  // Handles reordering grid items via drag-and-drop
  void _handleGridReorder(int oldIndex, int newIndex) {
    final grid = context.read<ColorGridProvider>();
    final settings = context.read<SettingsProvider>();

    grid.reorderItems(oldIndex, newIndex);

    // Clean up trailing empty rows after reorder
    grid.cleanupEmptyRows(settings.responsiveColumnCount);

    _coordinator.saveState('Reordered grid items');
  }

  // Handles tapping a grid item
  //
  // Coordinates selection across:
  // - ColorGridProvider (select this item)
  // - ExtremeColorsProvider (deselect extremes)
  // - BgColorProvider (deselect background)
  // - ColorEditorProvider (load item's color)
  // - ClipboardService (auto-copy if enabled)
  // - Snaps sheet up if in collapsed position
  void _handleGridItemTap(ColorGridItem item) {
    final grid = context.read<ColorGridProvider>();
    final extremes = context.read<ExtremeColorsProvider>();
    final bgColor = context.read<BgColorProvider>();
    final colorEditor = context.read<ColorEditorProvider>();
    final settings = context.read<SettingsProvider>();

    if (item.isSelected) {
      grid.deselectAll();
      return;
    }

    grid.selectItem(item.id);
    extremes.deselectAll();
    bgColor.setSelected(false);
    colorEditor.setFromOklchValues(item.oklchValues!);

    if (settings.autoCopyEnabled) {
      ClipboardService.copyColorToClipboard(item.color!);
    }

    // Auto-snap behavior when in low snap mode
    if (_currentSheetHeight.value < 100) {
      if (!_hasAutoSnappedUp) {
        // First tap ever - snap immediately
        const expandedPosition = SnappingPosition.pixels(
          positionPixels: 327,
          snappingCurve: Curves.easeOutExpo,
          snappingDuration: Duration(milliseconds: 900),
        );
        snappingSheetController.snapToPosition(expandedPosition);
        _hasAutoSnappedUp = true;
      } else if (_hasReturnedToLowSnap) {
        // Get current selection ID - use item.id for grid items
        final currentId = item.id;

        // Reset counter if different box is selected
        if (_lastSelectedItemId != null && _lastSelectedItemId != currentId) {
          _selectionCountAfterReturn = 0;
        }

        // Track this selection
        _lastSelectedItemId = currentId;

        // After returning to low snap, count taps before snapping again
        _selectionCountAfterReturn++;
        if (_selectionCountAfterReturn >= 2) {
          // After 2 taps (selection + deselection), snap on 3rd tap
          const expandedPosition = SnappingPosition.pixels(
            positionPixels: 327,
            snappingCurve: Curves.easeOutExpo,
            snappingDuration: Duration(milliseconds: 900),
          );
          snappingSheetController.snapToPosition(expandedPosition);
          _hasReturnedToLowSnap = false; // Reset for next time
          _selectionCountAfterReturn = 0;
          _lastSelectedItemId = null;
        }
      }
    }
  }

  // Handles tapping the background color box
  //
  // Coordinates selection across all providers (deselects grid items and extremes)
  // - Snaps sheet up if in collapsed position
  void _handleBgColorBoxTap() {
    final bgColor = context.read<BgColorProvider>();
    final grid = context.read<ColorGridProvider>();
    final extremes = context.read<ExtremeColorsProvider>();
    final colorEditor = context.read<ColorEditorProvider>();

    if (bgColor.isSelected) {
      bgColor.setSelected(false);
      return;
    }

    grid.deselectAll();
    extremes.deselectAll();
    bgColor.setSelected(true);

    colorEditor.updateOklch(
      lightness: bgColor.lightness,
      chroma: bgColor.chroma,
      hue: bgColor.hue,
      alpha: bgColor.alpha,
    );

    // Auto-snap behavior when in low snap mode
    if (_currentSheetHeight.value < 100) {
      if (!_hasAutoSnappedUp) {
        // First tap ever - snap immediately
        const expandedPosition = SnappingPosition.pixels(
          positionPixels: 327,
          snappingCurve: Curves.easeOutExpo,
          snappingDuration: Duration(milliseconds: 900),
        );
        snappingSheetController.snapToPosition(expandedPosition);
        _hasAutoSnappedUp = true;
      } else if (_hasReturnedToLowSnap) {
        // Get current selection ID
        final currentId = 'bg'; // Background color box

        // Reset counter if different box is selected
        if (_lastSelectedItemId != null && _lastSelectedItemId != currentId) {
          _selectionCountAfterReturn = 0;
        }

        // Track this selection
        _lastSelectedItemId = currentId;

        // After returning to low snap, count taps before snapping again
        _selectionCountAfterReturn++;
        if (_selectionCountAfterReturn >= 2) {
          // After 2 taps (selection + deselection), snap on 3rd tap
          const expandedPosition = SnappingPosition.pixels(
            positionPixels: 327,
            snappingCurve: Curves.easeOutExpo,
            snappingDuration: Duration(milliseconds: 900),
          );
          snappingSheetController.snapToPosition(expandedPosition);
          _hasReturnedToLowSnap = false; // Reset for next time
          _selectionCountAfterReturn = 0;
          _lastSelectedItemId = null;
        }
      }
    }
  }

  // Handles tapping a mixer extreme (left or right)
  //
  // Coordinates selection across all providers
  // - Snaps sheet up if in collapsed position
  void _handleExtremeTap(String extremeId) {
    final extremes = context.read<ExtremeColorsProvider>();
    final grid = context.read<ColorGridProvider>();
    final bgColor = context.read<BgColorProvider>();
    final colorEditor = context.read<ColorEditorProvider>();
    final settings = context.read<SettingsProvider>();

    if (extremes.selectedExtremeId == extremeId) {
      extremes.deselectAll();
      return;
    }

    grid.deselectAll();
    bgColor.setSelected(false);
    extremes.selectExtreme(extremeId);

    final selectedExtreme = extremeId == 'left' ? extremes.leftExtreme : extremes.rightExtreme;
    colorEditor.setFromOklchValues(selectedExtreme.oklchValues);

    if (settings.autoCopyEnabled) {
      ClipboardService.copyColorToClipboard(selectedExtreme.color);
    }

    // Auto-snap behavior when in low snap mode
    if (_currentSheetHeight.value < 100) {
      if (!_hasAutoSnappedUp) {
        // First tap ever - snap immediately
        const expandedPosition = SnappingPosition.pixels(
          positionPixels: 327,
          snappingCurve: Curves.easeOutExpo,
          snappingDuration: Duration(milliseconds: 900),
        );
        snappingSheetController.snapToPosition(expandedPosition);
        _hasAutoSnappedUp = true;
      } else if (_hasReturnedToLowSnap) {
        // Get current selection ID - use extremeId for extremes
        final currentId = 'extreme_$extremeId';

        // Reset counter if different box is selected
        if (_lastSelectedItemId != null && _lastSelectedItemId != currentId) {
          _selectionCountAfterReturn = 0;
        }

        // Track this selection
        _lastSelectedItemId = currentId;

        // After returning to low snap, count taps before snapping again
        _selectionCountAfterReturn++;
        if (_selectionCountAfterReturn >= 2) {
          // After 2 taps (selection + deselection), snap on 3rd tap
          const expandedPosition = SnappingPosition.pixels(
            positionPixels: 327,
            snappingCurve: Curves.easeOutExpo,
            snappingDuration: Duration(milliseconds: 900),
          );
          snappingSheetController.snapToPosition(expandedPosition);
          _hasReturnedToLowSnap = false; // Reset for next time
          _selectionCountAfterReturn = 0;
          _lastSelectedItemId = null;
        }
      }
    }
  }

  // Handles when user touches the mixer slider
  //
  // Deselects extremes. If BG is selected, applies current mixer color
  // to background and stays in BG edit mode.
  void _handleMixerSliderTouched() {
    final extremes = context.read<ExtremeColorsProvider>();
    final bgColor = context.read<BgColorProvider>();
    final colorEditor = context.read<ColorEditorProvider>();

    // Always deselect extremes when touching mixer
    extremes.deselectAll();

    // If BG is selected, apply current mixer color to it and stay in BG edit mode
    if (bgColor.isSelected && colorEditor.hasValues) {
      bgColor.updateOklch(
        lightness: colorEditor.lightness!,
        chroma: colorEditor.chroma!,
        hue: colorEditor.hue!,
        alpha: colorEditor.alpha ?? 1.0,
      );
      _coordinator.saveState('Applied mixer color to background');
    }
  }

  // Handles long press on a grid item
  //
  // Shows a bottom sheet menu with options (delete, etc.)
  void _handleGridItemLongPress(ColorGridItem item) {
    _showColorItemMenu(item);
  }

  // Handles deletion of a grid item
  //
  // Removes the item from the grid and saves undo state
  void _handleGridItemDelete(ColorGridItem item) {
    final grid = context.read<ColorGridProvider>();
    final settings = context.read<SettingsProvider>();

    debugPrint('DELETE: Deleting item, grid size before remove: ${grid.items.length}');
    grid.removeColor(item.id);
    debugPrint('DELETE: Grid size after remove: ${grid.items.length}');

    // Clean up trailing empty rows after deletion
    debugPrint('DELETE: Calling cleanup with columns: ${settings.responsiveColumnCount}');
    grid.cleanupEmptyRows(settings.responsiveColumnCount);
    debugPrint('DELETE: Grid size after cleanup: ${grid.items.length}');

    _coordinator.saveState('Deleted ${item.name ?? "color"} from grid');
  }

  // Handles adding a new color to the grid (tap behavior)
  //
  // Adds the currently selected color (or current editor color if nothing selected)
  // to the grid and selects it automatically
  void _handleAddColor() {
    final grid = context.read<ColorGridProvider>();
    final colorEditor = context.read<ColorEditorProvider>();
    final selectedItem = grid.selectedItem;
    final colorToAdd = selectedItem?.color ?? colorEditor.currentColor;

    if (colorToAdd != null) {
      grid.addColor(colorToAdd, selectNew: true);
      _coordinator.saveState('Added color to grid');
    }
  }

  // Handles adding multiple colors via drag gesture (drag-to-reveal behavior)
  //
  // Adds enough colors to fill the incomplete row + a complete new row
  // Example: If grid has 3 columns and last row has 1 item, adds 2 (to fill) + 3 (new row) = 5 items
  void _handleDragToAddColor() {
    final grid = context.read<ColorGridProvider>();
    final colorEditor = context.read<ColorEditorProvider>();
    final settings = context.read<SettingsProvider>();
    final selectedItem = grid.selectedItem;
    final colorToAdd = selectedItem?.color ?? colorEditor.currentColor;

    if (colorToAdd != null) {
      final columns = settings.responsiveColumnCount;
      final currentItemCount = grid.items.length;

      // Calculate items in the last row
      final itemsInLastRow = currentItemCount % columns;

      // If last row is incomplete, fill it first, then add a complete row
      // If last row is complete (or empty grid), just add a complete row
      final itemsToFillLastRow = itemsInLastRow == 0 ? 0 : (columns - itemsInLastRow);
      final totalItemsToAdd = itemsToFillLastRow + columns;

      for (int i = 0; i < totalItemsToAdd; i++) {
        // Only select the last added color
        final isLast = i == totalItemsToAdd - 1;
        grid.addColor(colorToAdd, selectNew: isLast);
      }

      _coordinator.saveState('Added $totalItemsToAdd color${totalItemsToAdd > 1 ? 's' : ''} to grid');
    }
  }

  // Handles tapping an empty slot
  //
  // Replaces the empty slot with the current color from ColorEditor
  void _handleEmptySlotTap(ColorGridItem emptySlot) {
    final grid = context.read<ColorGridProvider>();
    final colorEditor = context.read<ColorEditorProvider>();
    final settings = context.read<SettingsProvider>();
    final colorToAdd = colorEditor.currentColor;

    if (colorToAdd != null) {
      grid.replaceEmptySlot(
        slotId: emptySlot.id,
        color: colorToAdd,
        selectNew: true,
      );

      // Clean up trailing empty rows after replacement
      grid.cleanupEmptyRows(settings.responsiveColumnCount);

      _coordinator.saveState('Filled empty slot with color');
    }
  }

  // ========== Other Actions & Handlers ============

  // Starts eyedropper tool for background color selection
  //
  // Launches the eyedropper overlay to pick a color from screen,
  // then updates background color and ColorEditor with the picked color
  void _startEyedropperForBgColor(DragStartDetails details) {
    try {
      Future.delayed(
        const Duration(milliseconds: 50),
        () => EyeDrop.of(context).capture(context, (color) {
          final oklchColor = srgbToOklch(color);
          final bgColor = context.read<BgColorProvider>();
          final colorEditor = context.read<ColorEditorProvider>();

          bgColor.updateOklch(
            lightness: oklchColor.l,
            chroma: oklchColor.c,
            hue: oklchColor.h,
            alpha: oklchColor.alpha,
          );
          bgColor.setSelected(true);

          colorEditor.updateOklch(
            lightness: oklchColor.l,
            chroma: oklchColor.c,
            hue: oklchColor.h,
            alpha: oklchColor.alpha,
          );

          _coordinator.saveState('Eyedropper picked color for background');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Picked ${ClipboardService.colorToHex(color)} for background'),
              duration: const Duration(milliseconds: 100),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
            ),
          );
        }, null),
      );
    } catch (err) {
      debugPrint('EyeDrop capture error for background: $err');
    }
  }

  // Starts eyedropper tool for mixer extreme color selection
  //
  // Launches the eyedropper overlay to pick a color from screen,
  // then updates the specified extreme (left or right) and ColorEditor
  void _startEyedropperForExtreme(String extremeId, DragStartDetails details) {
    try {
      Future.delayed(
        const Duration(milliseconds: 50),
        () => EyeDrop.of(context).capture(context, (color) {
          final oklchColor = srgbToOklch(color);
          final extremes = context.read<ExtremeColorsProvider>();
          final colorEditor = context.read<ColorEditorProvider>();

          extremes.updateExtremeOklch(
            extremeId: extremeId,
            lightness: oklchColor.l,
            chroma: oklchColor.c,
            hue: oklchColor.h,
            alpha: oklchColor.alpha,
          );

          colorEditor.updateOklch(
            lightness: oklchColor.l,
            chroma: oklchColor.c,
            hue: oklchColor.h,
            alpha: oklchColor.alpha,
          );

          _coordinator.saveState('Eyedropper picked color for $extremeId extreme');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Picked ${ClipboardService.colorToHex(color)} for extreme'),
              duration: const Duration(milliseconds: 100),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
            ),
          );
        }, null),
      );
    } catch (err) {
      debugPrint('EyeDrop capture error for extreme: $err');
    }
  }

  // Triggers undo operation via coordinator
  void _handleUndo() => _coordinator.undo();

  // Triggers redo operation via coordinator
  void _handleRedo() => _coordinator.redo();

  // Randomizes all colors in the grid
  //
  // Generates random OKLCH values for all existing grid items
  // while preserving names and selection state
  void _handleGenerateColors() {
    _coordinator.saveState('Randomize colors');
    context.read<ColorGridProvider>().randomizeAllColors();
  }

  // Handles toggle of "Real Pigments Only" setting
  //
  // When enabled, colors are filtered through ICC profile to simulate
  // printer gamut limitations (only colors achievable with real pigments)
  void _handleRealPigmentsOnlyChanged(bool value) {
    context.read<SettingsProvider>().setRealPigmentsOnly(value);
  }

  // Handles menu button press - saves palette before opening menu
  void _handleMenuPressed() {
    _autoSavePalette();
  }

  // ========== UI Helpers ==========

  // Shows a bottom sheet menu for a color item
  //
  // Displays item details (color swatch, name, hex code) and actions (delete)
  void _showColorItemMenu(ColorGridItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: item.color!,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              title: Text(item.name ?? 'Unnamed Color'),
              subtitle: Text('#${item.color!.toARGB32().toRadixString(16).substring(2).toUpperCase()}'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _handleGridItemDelete(item);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ================================================
  // ========== Build & UI Rendering ================
  // ================================================
  //
  // Renders the complete home screen with a snapping bottom sheet UI.
  //
  // UI Hierarchy (bottom to top):
  // 1. Background (bgColor fills entire screen)
  // 2. SnappingSheet with grabbable handle containing:
  //    - Color grid (reorderable, drag-to-delete)
  //    - Real Pigments toggle
  //    - Home app bar
  //    - Delete zone overlay (appears during drag)
  // 3. Bottom sheet content (color picker controls/sliders)
  // 4. Bottom action bar (background color box, undo/redo, randomize, eyedropper)
  //
  // State Management:
  // - Watches all providers for reactive updates
  // - Uses ListenableBuilder for drag-drop controller updates
  // - UndoRedoShortcuts wrapper handles keyboard shortcuts

  // Builds sheet content based on selected chip
  Widget _buildSheetContent(
    int chipIndex,
    Color bgColor,
    ExtremeColorItem leftExtreme,
    ExtremeColorItem rightExtreme,
    bool useRealPigmentsOnly,
  ) {
    switch (chipIndex) {
      case 0: // My Picks
        return Center(
          child: Text(
            'My Picks Content',
            style: TextStyle(
              color: bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              fontSize: 24,
            ),
          ),
        );

      case 1: // Perceptual (OKLCH sliders)
        return PerceptualSliderControls(
          onOklchChanged: _handleOklchChanged,
          leftExtreme: leftExtreme,
          rightExtreme: rightExtreme,
          extremeColorFilter: (extreme) => _applyIccFilter(
            extreme.color,
            lightness: extreme.oklchValues.lightness,
            chroma: extreme.oklchValues.chroma,
            hue: extreme.oklchValues.hue,
            alpha: extreme.oklchValues.alpha,
          ),
          gradientColorFilter: (color, l, c, h, a) => _applyIccFilter(
            color,
            lightness: l,
            chroma: c,
            hue: h,
            alpha: a,
          ),
          onExtremeTap: _handleExtremeTap,
          onMixerSliderTouched: _handleMixerSliderTouched,
          onSliderInteractionChanged: (interacting) =>
              setState(() => _isInteractingWithSlider = interacting),
          useRealPigmentsOnly: useRealPigmentsOnly,
          bgColor: bgColor,
          onPanStartExtreme: _startEyedropperForExtreme,
        );

      case 2: // Digital (HSB)
        return DigitalColorControls(
          onOklchChanged: _handleOklchChanged,
          leftExtreme: leftExtreme,
          rightExtreme: rightExtreme,
          extremeColorFilter: (extreme) => _applyIccFilter(
            extreme.color,
            lightness: extreme.oklchValues.lightness,
            chroma: extreme.oklchValues.chroma,
            hue: extreme.oklchValues.hue,
            alpha: extreme.oklchValues.alpha,
          ),
          gradientColorFilter: (color, l, c, h, a) => _applyIccFilter(
            color,
            lightness: l,
            chroma: c,
            hue: h,
            alpha: a,
          ),
          onExtremeTap: _handleExtremeTap,
          onMixerSliderTouched: _handleMixerSliderTouched,
          onSliderInteractionChanged: (interacting) =>
              setState(() => _isInteractingWithSlider = interacting),
          useRealPigmentsOnly: useRealPigmentsOnly,
          bgColor: bgColor,
          onPanStartExtreme: _startEyedropperForExtreme,
        );

      case 3: // Add (CMYK/Additional)
        return Center(
          child: Text(
            'Add Content',
            style: TextStyle(
              color: bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              fontSize: 24,
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColorProvider = context.watch<BgColorProvider>();
    final extremesProvider = context.watch<ExtremeColorsProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final colorEditor = context.watch<ColorEditorProvider>();
    final sheetState = context.watch<SheetStateProvider>();

    final bgColor = bgColorProvider.color;
    final bgLightness = bgColorProvider.lightness;
    final bgChroma = bgColorProvider.chroma;
    final bgHue = bgColorProvider.hue;
    final bgAlpha = bgColorProvider.alpha;
    final isBgColorSelected = bgColorProvider.isSelected;

    final leftExtreme = extremesProvider.leftExtreme;
    final rightExtreme = extremesProvider.rightExtreme;
    final selectedExtremeId = extremesProvider.selectedExtremeId;

    final useRealPigmentsOnly = settingsProvider.useRealPigmentsOnly;

    return ListenableBuilder(
      listenable: _dragDropController,
      builder: (context, _) => UndoRedoShortcuts(
        onUndo: _handleUndo,
        onRedo: _handleRedo,
        child: Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
            SnappingSheet(
              controller: snappingSheetController,
              lockOverflowDrag: true,
              // Bottom sheet snap positions (height in pixels from bottom)
              snappingPositions: const [
                SnappingPosition.pixels(
                  positionPixels: 6,
                  snappingCurve: Curves.easeOutExpo,
                  snappingDuration: Duration(milliseconds: 900),
                  grabbingContentOffset: GrabbingContentOffset.top,
                ),
                SnappingPosition.pixels(
                  positionPixels: 327,
                  snappingCurve: Curves.easeOutExpo,
                  snappingDuration: Duration(milliseconds: 900),
                ),
              ],
              onSheetMoved: (positionData) {
                _currentSheetHeight.value = positionData.pixels;

                // Detect when sheet returns to low snap after first auto-snap
                if (_hasAutoSnappedUp && positionData.pixels < 100 && !_hasReturnedToLowSnap) {
                  _hasReturnedToLowSnap = true;
                  _selectionCountAfterReturn = 0; // Reset counter
                }

                // Reset flag when sheet goes up
                if (positionData.pixels >= 100) {
                  _hasReturnedToLowSnap = false;
                  _selectionCountAfterReturn = 0;
                }
              },

              grabbingHeight: 80,
              grabbing: SheetGrabbingHandle(
                bgColor: bgColor,
              ),

              sheetBelow: SnappingSheetContent(
                draggable: (details) => !_isInteractingWithSlider,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: getTextColor(bgColor).withOpacity(0.15),
                                width: 1.5,
                              ),
                              right: BorderSide(
                                color: getTextColor(bgColor).withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: _buildSheetContent(
                            sheetState.selectedChipIndex,
                            bgColor,
                            leftExtreme,
                            rightExtreme,
                            useRealPigmentsOnly,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: const SystemUiOverlayStyle(
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarIconBrightness: Brightness.dark,
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
                child: SafeArea(
                  child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerMove: (event) {
                    if (_dragDropController.isDragging) {
                      _dragDropController.onDragUpdate(event.position);
                    }
                  },
                  child: Stack(
                  children: [
                    Column(
                      children: [
                        Container(
                          height: HomeAppBar.height,
                          color: Colors.transparent,
                        ),
                        ValueListenableBuilder<double>(
                          valueListenable: _currentSheetHeight,
                          builder: (context, sheetHeight, _) {
                            // Calculate available height for the scrollable area
                            // = screen height - header - bottom sheet - bottom bar (-8px overlap)
                            final screenHeight = MediaQuery.of(context).size.height;
                            final scrollableHeight = screenHeight - HomeAppBar.height - sheetHeight - 40;
                            final gridContentHeight = scrollableHeight;
                            final containerHeight = scrollableHeight + 30;  // Blue box 30px taller than red
                            debugPrint('DEBUG: screenHeight=$screenHeight, _currentSheetHeight=$sheetHeight, scrollableHeight=$scrollableHeight, gridContentHeight=$gridContentHeight');

                            return Container(
                              height: containerHeight,
                              color: Colors.transparent,
                              child: settingsProvider.boxHeightMode == BoxHeightMode.fillContainer
                                ? GestureDetector(
                                    onVerticalDragUpdate: (details) {
                                      // Don't handle sheet drag if a color item is being dragged
                                      if (_dragDropController.isDragging) {
                                        debugPrint('SHEET: Blocked - item is being dragged');
                                        return;
                                      }

                                      // Control the sheet position directly
                                      // Drag down (positive dy) = move sheet down (reduce height)
                                      // Drag up (negative dy) = move sheet up (increase height)
                                      final newPosition = (_currentSheetHeight.value - details.delta.dy).clamp(46.0, 327.0);

                                      snappingSheetController.setSnappingSheetPosition(newPosition);

                                      debugPrint('SHEET: Moving sheet - delta.dy=${details.delta.dy}, newPosition=$newPosition');
                                    },
                                    onVerticalDragEnd: (details) {
                                      // Snap to nearest position based on current position and velocity
                                      final velocity = details.primaryVelocity ?? 0;

                                      debugPrint('SHEET: Drag ended - position=${_currentSheetHeight.value}, velocity=$velocity');

                                      // Define snap positions with full configuration to match sheet behavior
                                      const collapsedPosition = SnappingPosition.pixels(
                                        positionPixels: 6,
                                        snappingCurve: Curves.easeOutExpo,
                                        snappingDuration: Duration(milliseconds: 900),
                                        grabbingContentOffset: GrabbingContentOffset.top,
                                      );
                                      const expandedPosition = SnappingPosition.pixels(
                                        positionPixels: 327,
                                        snappingCurve: Curves.easeOutExpo,
                                        snappingDuration: Duration(milliseconds: 900),
                                      );

                                      // Snap to closest position based on current position and velocity
                                      if (velocity.abs() > 500) {
                                        // Fast swipe - snap based on direction
                                        if (velocity < 0) {
                                          // Swiping up - snap to expanded
                                          snappingSheetController.snapToPosition(expandedPosition);
                                        } else {
                                          // Swiping down - snap to collapsed
                                          snappingSheetController.snapToPosition(collapsedPosition);
                                        }
                                      } else {
                                        // Slow drag - snap to nearest position
                                        if (_currentSheetHeight.value < 166.5) {
                                          snappingSheetController.snapToPosition(collapsedPosition);
                                        } else {
                                          snappingSheetController.snapToPosition(expandedPosition);
                                        }
                                      }
                                    },
                                    child: ReorderableColorGridView(
                                      onReorder: _handleGridReorder,
                                      onItemTap: _handleGridItemTap,
                                      onEmptySlotTap: _handleEmptySlotTap,
                                      onItemLongPress: _handleGridItemLongPress,
                                      onItemDelete: _handleGridItemDelete,
                                      onAddColor: _handleAddColor,
                                      onDragStarted: _dragDropController.onDragStarted,
                                      onDragEnded: _dragDropController.onDragEnded,
                                      crossAxisCount: settingsProvider.responsiveColumnCount,
                                      spacing: ReorderableColorGridView.defaultSpacing,
                                      itemWidth: 70.0,
                                      itemHeight: 140.0,
                                      showAddButton: false, // Disabled - can be re-enabled if needed
                                      emptyStateMessage: 'No colors in grid\nCreate a color above and tap + to add it',
                                      layoutMode: settingsProvider.gridLayoutMode,
                                      heightMode: settingsProvider.boxHeightMode,
                                      availableHeight: gridContentHeight,
                                      bgColor: bgColor,
                                      rowModifier: _rowModifier,
                                      colorFilter: (item) => _applyIccFilter(
                                        item.color!,
                                        lightness: item.oklchValues!.lightness,
                                        chroma: item.oklchValues!.chroma,
                                        hue: item.oklchValues!.hue,
                                        alpha: item.oklchValues!.alpha,
                                      ),
                                    )
                                  )
                                : ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context).copyWith(
                                      dragDevices: {
                                        PointerDeviceKind.touch,
                                        PointerDeviceKind.mouse,
                                      },
                                    ),
                                    child: SingleChildScrollView(
                                      controller: scrollController,
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      child: ReorderableColorGridView(
                                        onReorder: _handleGridReorder,
                                        onItemTap: _handleGridItemTap,
                                        onEmptySlotTap: _handleEmptySlotTap,
                                        onItemLongPress: _handleGridItemLongPress,
                                        onItemDelete: _handleGridItemDelete,
                                        onAddColor: _handleAddColor,
                                        onDragStarted: _dragDropController.onDragStarted,
                                        onDragEnded: _dragDropController.onDragEnded,
                                        crossAxisCount: settingsProvider.responsiveColumnCount,
                                        spacing: ReorderableColorGridView.defaultSpacing,
                                        itemWidth: 70.0,
                                        itemHeight: 140.0,
                                        showAddButton: true,
                                        emptyStateMessage: 'No colors in grid\nCreate a color above and tap + to add it',
                                        layoutMode: settingsProvider.gridLayoutMode,
                                        heightMode: settingsProvider.boxHeightMode,
                                        availableHeight: gridContentHeight,
                                        bgColor: bgColor,
                                        colorFilter: (item) => _applyIccFilter(
                                          item.color!,
                                          lightness: item.oklchValues!.lightness,
                                          chroma: item.oklchValues!.chroma,
                                          hue: item.oklchValues!.hue,
                                          alpha: item.oklchValues!.alpha,
                                        ),
                                      ),
                                    ),
                                  ),
                            );
                          },
                        ),
                      ],
                    ),

                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: HomeAppBar(
                        bgColor: bgColor,
                        onBgEditMode: _handleBgColorBoxTap,
                        isBgColorSelected: isBgColorSelected,
                        onBgColorPanStart: _startEyedropperForBgColor,
                        colorFilter: _applyIccFilter,
                        onMenuPressed: _handleMenuPressed,
                      ),
                    ),

                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: DeleteZoneOverlay(
                        isDragging: _dragDropController.isDragging,
                        isInDeleteZone: _dragDropController.isInDeleteZone,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
            ),

            Positioned(
              bottom: 0,
              left: 20,
              right: 20,
              child: BottomActionBar(
                bgColor: bgColor,
                currentColor: colorEditor.currentColor,
                selectedExtremeId: selectedExtremeId,
                leftExtreme: leftExtreme,
                rightExtreme: rightExtreme,
                onColorSelected: _handleColorSelection,
                undoRedoManager: _undoRedoService,
                onUndo: _handleUndo,
                onRedo: _handleRedo,
                onGenerateColors: _handleGenerateColors,
                colorFilter: _applyIccFilter,
                bgLightness: bgLightness,
                bgChroma: bgChroma,
                bgHue: bgHue,
                bgAlpha: bgAlpha,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
