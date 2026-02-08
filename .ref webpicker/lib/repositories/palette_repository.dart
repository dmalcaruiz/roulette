import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_palette.dart';

/// Repository for managing palette persistence
/// Handles all storage operations using SharedPreferences
class PaletteRepository {
  static const String _palettesKey = 'saved_palettes';
  static const String _paletteIdsKey = 'palette_ids';

  final SharedPreferences _prefs;

  PaletteRepository(this._prefs);

  /// Initialize repository (call once at app startup)
  static Future<PaletteRepository> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return PaletteRepository(prefs);
  }

  /// Save a palette to storage
  Future<bool> savePalette(SavedPalette palette) async {
    try {
      // Save the palette data
      final key = _getPaletteKey(palette.id);
      final success = await _prefs.setString(key, palette.toJsonString());

      if (success) {
        // Update the list of palette IDs
        await _addPaletteId(palette.id);
      }

      return success;
    } catch (e) {
      print('Error saving palette: $e');
      return false;
    }
  }

  /// Get a palette by ID
  Future<SavedPalette?> getPalette(String id) async {
    try {
      final key = _getPaletteKey(id);
      final jsonString = _prefs.getString(key);

      if (jsonString == null) return null;

      return SavedPalette.fromJsonString(jsonString);
    } catch (e) {
      print('Error loading palette: $e');
      return null;
    }
  }

  /// Get all saved palettes
  Future<List<SavedPalette>> getAllPalettes() async {
    try {
      final ids = await _getAllPaletteIds();
      final palettes = <SavedPalette>[];

      for (final id in ids) {
        final palette = await getPalette(id);
        if (palette != null) {
          palettes.add(palette);
        }
      }

      // Sort by last modified (most recent first)
      palettes.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      return palettes;
    } catch (e) {
      print('Error loading all palettes: $e');
      return [];
    }
  }

  /// Delete a palette by ID
  Future<bool> deletePalette(String id) async {
    try {
      final key = _getPaletteKey(id);
      final success = await _prefs.remove(key);

      if (success) {
        await _removePaletteId(id);
      }

      return success;
    } catch (e) {
      print('Error deleting palette: $e');
      return false;
    }
  }

  /// Delete all palettes
  Future<bool> deleteAllPalettes() async {
    try {
      final ids = await _getAllPaletteIds();

      for (final id in ids) {
        final key = _getPaletteKey(id);
        await _prefs.remove(key);
      }

      await _prefs.remove(_paletteIdsKey);
      return true;
    } catch (e) {
      print('Error deleting all palettes: $e');
      return false;
    }
  }

  /// Check if a palette exists
  Future<bool> paletteExists(String id) async {
    final key = _getPaletteKey(id);
    return _prefs.containsKey(key);
  }

  /// Get the number of saved palettes
  Future<int> getPaletteCount() async {
    final ids = await _getAllPaletteIds();
    return ids.length;
  }

  // Private helper methods

  String _getPaletteKey(String id) => '${_palettesKey}_$id';

  Future<List<String>> _getAllPaletteIds() async {
    final idsString = _prefs.getStringList(_paletteIdsKey);
    return idsString ?? [];
  }

  Future<void> _addPaletteId(String id) async {
    final ids = await _getAllPaletteIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await _prefs.setStringList(_paletteIdsKey, ids);
    }
  }

  Future<void> _removePaletteId(String id) async {
    final ids = await _getAllPaletteIds();
    ids.remove(id);
    await _prefs.setStringList(_paletteIdsKey, ids);
  }
}
