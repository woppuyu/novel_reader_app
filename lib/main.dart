import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader_app/state/novel_hub_state.dart';
import 'package:novel_reader_app/screens/novel_hub_screen.dart';

Future<void> main() async {
  // Ensure Flutter is initialised before calling any platform channels
  // (SharedPreferences requires this).
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // Wrap the entire app in a ChangeNotifierProvider so any widget can
    // access NovelHubState via context.watch / context.read.
    ChangeNotifierProvider(
      create: (_) {
        final state = NovelHubState();
        // Kick off the async initialisation (loads sites from SharedPreferences).
        state.init();
        return state;
      },
      child: const NovelHubApp(),
    ),
  );
}

/// The root widget of NovelHub.
///
/// Sets up the Material theme and points [home] at [NovelHubScreen].
class NovelHubApp extends StatelessWidget {
  const NovelHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NovelHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // A deep indigo seed creates a rich purple/blue palette — fitting for
        // a reading app. You can swap this to any color you prefer.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D3B8E), // deep indigo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // NavigationBar styling picks up from the colorScheme automatically.
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D3B8E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, // Respects the device's light/dark setting.
      home: const NovelHubScreen(),
    );
  }
}
