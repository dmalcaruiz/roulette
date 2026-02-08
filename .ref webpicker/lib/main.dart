import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'cyclop_eyedropper/eye_dropper_layer.dart';
import 'screens/home_screen.dart';
import 'state/color_editor_provider.dart';
import 'state/color_grid_provider.dart';
import 'state/extreme_colors_provider.dart';
import 'state/bg_color_provider.dart';
import 'state/settings_provider.dart';
import 'state/sheet_state_provider.dart';
import 'state/saved_palettes_provider.dart';
import 'repositories/palette_repository.dart';
import 'utils/global_pointer_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Make navigation bar and status bar completely transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // Initialize palette repository
  final paletteRepository = await PaletteRepository.initialize();

  runApp(MyApp(paletteRepository: paletteRepository));
}

class MyApp extends StatelessWidget {
  final PaletteRepository paletteRepository;

  const MyApp({super.key, required this.paletteRepository});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ColorEditorProvider()),
        ChangeNotifierProvider(create: (_) => ColorGridProvider()),
        ChangeNotifierProvider(create: (_) => ExtremeColorsProvider()),
        ChangeNotifierProvider(create: (_) => BgColorProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SheetStateProvider()),
        ChangeNotifierProvider(create: (_) => SavedPalettesProvider(paletteRepository)),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Livvic',
            ),
            home: GlobalPointerTrackerProvider(
              child: EyeDrop(child: const HomeScreen()),
            ),
          ),
        ),
      ),
    );
  }
}