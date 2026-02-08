import 'package:flutter/foundation.dart';
import '../models/saved_palette.dart';
import '../models/color_grid_item.dart';
import '../repositories/palette_repository.dart';

/// Provider for managing saved palettes
/// Handles loading, saving, and deleting palettes with repository
class SavedPalettesProvider extends ChangeNotifier {
  final PaletteRepository _repository;
  List<SavedPalette> _palettes = [];
  bool _isLoading = false;
  String? _currentPaletteId; // Tracks which palette is currently being edited

  SavedPalettesProvider(this._repository);

  List<SavedPalette> get palettes => List.unmodifiable(_palettes);
  bool get isLoading => _isLoading;
  int get paletteCount => _palettes.length;
  String? get currentPaletteId => _currentPaletteId;
  bool get isEditingExistingPalette => _currentPaletteId != null;

  /// Load all saved palettes from storage
  Future<void> loadPalettes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _palettes = await _repository.getAllPalettes();
    } catch (e) {
      debugPrint('Error loading palettes: $e');
      _palettes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save current palette (auto-save or manual save)
  /// If editing an existing palette, updates it; otherwise creates a new one
  Future<bool> saveCurrentPalette(List<ColorGridItem> colors, {String? customName}) async {
    try {
      SavedPalette palette;

      if (_currentPaletteId != null) {
        // Update existing palette
        final existingPalette = await _repository.getPalette(_currentPaletteId!);

        if (existingPalette != null) {
          // Keep the same ID and name, just update colors and timestamp
          palette = existingPalette.copyWith(
            colors: colors,
            name: customName ?? existingPalette.name,
            lastModified: DateTime.now(),
          );
        } else {
          // Palette was deleted, create a new one
          _currentPaletteId = null;
          palette = SavedPalette.create(
            name: customName ?? _generatePaletteName(),
            colors: colors,
          );
          _currentPaletteId = palette.id;
        }
      } else {
        // Create new palette
        palette = SavedPalette.create(
          name: customName ?? _generatePaletteName(),
          colors: colors,
        );
        _currentPaletteId = palette.id;
      }

      // Save to repository
      final success = await _repository.savePalette(palette);

      if (success) {
        // Reload palettes to update the list
        await loadPalettes();
      }

      return success;
    } catch (e) {
      debugPrint('Error saving palette: $e');
      return false;
    }
  }

  /// Load a palette by ID
  Future<SavedPalette?> getPalette(String id) async {
    try {
      return await _repository.getPalette(id);
    } catch (e) {
      debugPrint('Error getting palette: $e');
      return null;
    }
  }

  /// Set the current palette being edited
  void setCurrentPalette(String id) {
    _currentPaletteId = id;
    notifyListeners();
  }

  /// Start a new palette (clears current palette tracking)
  void startNewPalette() {
    _currentPaletteId = null;
    notifyListeners();
  }

  /// Delete a palette
  Future<bool> deletePalette(String id) async {
    try {
      final success = await _repository.deletePalette(id);

      if (success) {
        _palettes.removeWhere((p) => p.id == id);

        // If we deleted the current palette, clear the current ID
        if (_currentPaletteId == id) {
          _currentPaletteId = null;
        }

        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting palette: $e');
      return false;
    }
  }

  /// Delete all palettes
  Future<bool> deleteAllPalettes() async {
    try {
      final success = await _repository.deleteAllPalettes();

      if (success) {
        _palettes.clear();
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error deleting all palettes: $e');
      return false;
    }
  }

  /// Rename a palette
  Future<bool> renamePalette(String id, String newName) async {
    try {
      final palette = await _repository.getPalette(id);
      if (palette == null) return false;

      final updatedPalette = palette.copyWith(
        name: newName,
        lastModified: DateTime.now(),
      );

      final success = await _repository.savePalette(updatedPalette);

      if (success) {
        await loadPalettes();
      }

      return success;
    } catch (e) {
      debugPrint('Error renaming palette: $e');
      return false;
    }
  }

  /// Generate a default palette name based on timestamp
  String _generatePaletteName() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'Palette ${now.year}-$month-$day $hour:$minute';
  }
}
