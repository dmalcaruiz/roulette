import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/settings_provider.dart';
import '../state/saved_palettes_provider.dart';
import '../state/color_grid_provider.dart';
import '../models/saved_palette.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    // Load palettes when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedPalettesProvider>().loadPalettes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final palettesProvider = context.watch<SavedPalettesProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Menu'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Saved Palettes'),
          _buildSavedPalettesSection(palettesProvider),
          const Divider(),
          _buildSectionHeader('Display Settings'),
          _buildGridLayoutSection(settingsProvider),
          const Divider(),
          _buildSectionHeader('Box Height'),
          _buildBoxHeightSection(settingsProvider),
          const Divider(),
          _buildSectionHeader('Color Settings'),
          SwitchListTile(
            title: const Text('Real Pigments Only'),
            subtitle: const Text('Apply ICC profile filtering to colors'),
            value: settingsProvider.useRealPigmentsOnly,
            onChanged: (value) {
              settingsProvider.setRealPigmentsOnly(value);
            },
          ),
          SwitchListTile(
            title: const Text('Pigment Mixing'),
            subtitle: const Text('Enable pigment-based color mixing'),
            value: settingsProvider.usePigmentMixing,
            onChanged: (value) {
              settingsProvider.setUsePigmentMixing(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPalettesSection(SavedPalettesProvider palettesProvider) {
    if (palettesProvider.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        // New Palette button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () => _handleNewPalette(),
            icon: const Icon(Icons.add),
            label: const Text('New Palette'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),

        if (palettesProvider.palettes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                'No saved palettes yet.\nPalettes auto-save every 3 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...palettesProvider.palettes.map((palette) {
            return _buildPaletteCard(palette);
          }),
      ],
    );
  }

  void _handleNewPalette() {
    final grid = context.read<ColorGridProvider>();
    final palettes = context.read<SavedPalettesProvider>();

    // Clear the grid
    grid.clear();

    // Start tracking a new palette
    palettes.startNewPalette();

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Started new palette'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPaletteCard(SavedPalette palette) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildPalettePreview(palette),
        title: Text(
          palette.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${palette.colors.length} colors • ${_formatDate(palette.lastModified)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _handleDeletePalette(palette),
            ),
          ],
        ),
        onTap: () => _handleLoadPalette(palette),
      ),
    );
  }

  Widget _buildPalettePreview(SavedPalette palette) {
    final previewColors = palette.colors
        .where((item) => !item.isEmpty && item.color != null)
        .take(4)
        .toList();

    if (previewColors.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            if (index < previewColors.length) {
              return Container(color: previewColors[index].color);
            }
            return Container(color: Colors.grey.shade200);
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _handleLoadPalette(SavedPalette palette) {
    final grid = context.read<ColorGridProvider>();
    final palettes = context.read<SavedPalettesProvider>();

    // Load palette colors into grid
    grid.syncFromSnapshot(palette.colors);

    // Set this as the current palette being edited
    palettes.setCurrentPalette(palette.id);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded "${palette.name}"'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleDeletePalette(SavedPalette palette) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Palette'),
        content: Text('Are you sure you want to delete "${palette.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final palettes = context.read<SavedPalettesProvider>();

              navigator.pop();
              await palettes.deletePalette(palette.id);

              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${palette.name}"'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildGridLayoutSection(SettingsProvider settingsProvider) {
    return Column(
      children: [
        RadioListTile<GridLayoutMode>(
          title: const Text('Responsive Grid'),
          subtitle: Text('${settingsProvider.responsiveColumnCount} columns, boxes resize to fill width'),
          value: GridLayoutMode.responsive,
          groupValue: settingsProvider.gridLayoutMode,
          onChanged: (value) {
            if (value != null) {
              settingsProvider.setGridLayoutMode(value);
            }
          },
        ),
        // Show column count slider when responsive mode is selected
        if (settingsProvider.gridLayoutMode == GridLayoutMode.responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate max columns based on 70px target size + 8px spacing
              // Using same calculation as fixedSize mode
              const itemSize = 70.0;
              const spacing = 8.0;
              final availableWidth = constraints.maxWidth - 72 - 16; // Subtract padding
              final columnWidth = itemSize + spacing;
              final maxColumns = (availableWidth / columnWidth).floor().clamp(1, 10);

              return Padding(
                padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                child: Row(
                  children: [
                    const Text('Columns:'),
                    Expanded(
                      child: Slider(
                        value: settingsProvider.responsiveColumnCount.toDouble().clamp(1, maxColumns.toDouble()),
                        min: 1,
                        max: maxColumns.toDouble(),
                        divisions: maxColumns - 1,
                        label: settingsProvider.responsiveColumnCount.toString(),
                        onChanged: (value) {
                          settingsProvider.setResponsiveColumnCount(value.round());
                        },
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        settingsProvider.responsiveColumnCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        RadioListTile<GridLayoutMode>(
          title: const Text('Fixed Size Grid'),
          subtitle: const Text('Dynamic columns based on 70px target size'),
          value: GridLayoutMode.fixedSize,
          groupValue: settingsProvider.gridLayoutMode,
          onChanged: (value) {
            if (value != null) {
              settingsProvider.setGridLayoutMode(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBoxHeightSection(SettingsProvider settingsProvider) {
    return Column(
      children: [
        RadioListTile<BoxHeightMode>(
          title: const Text('Proportional (Square)'),
          subtitle: const Text('Height matches width (1:1 aspect ratio)'),
          value: BoxHeightMode.proportional,
          groupValue: settingsProvider.boxHeightMode,
          onChanged: (value) {
            if (value != null) {
              settingsProvider.setBoxHeightMode(value);
            }
          },
        ),
        RadioListTile<BoxHeightMode>(
          title: const Text('Fill Container'),
          subtitle: const Text('Height fills available space based on rows'),
          value: BoxHeightMode.fillContainer,
          groupValue: settingsProvider.boxHeightMode,
          onChanged: (value) {
            if (value != null) {
              settingsProvider.setBoxHeightMode(value);
            }
          },
        ),
        RadioListTile<BoxHeightMode>(
          title: const Text('Fixed Height'),
          subtitle: const Text('Fixed 140px height, independent of width'),
          value: BoxHeightMode.fixed,
          groupValue: settingsProvider.boxHeightMode,
          onChanged: (value) {
            if (value != null) {
              settingsProvider.setBoxHeightMode(value);
            }
          },
        ),
      ],
    );
  }
}
