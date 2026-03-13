import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/map_create_info_screen.dart';
import 'screens/map_create_camera_screen.dart';
import 'screens/map_list_screen.dart';
import 'screens/pathfinding_camera_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const IndoorPathfindingApp());
}

class IndoorPathfindingApp extends StatefulWidget {
  const IndoorPathfindingApp({super.key});

  @override
  State<IndoorPathfindingApp> createState() => _IndoorPathfindingAppState();
}

class _IndoorPathfindingAppState extends State<IndoorPathfindingApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '실내 길찾기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/map-create-info': (_) => const MapCreateInfoScreen(),
        '/map-create-camera': (_) => const MapCreateCameraScreen(),
        '/map-list': (_) => const MapListScreen(),
        '/pathfinding-camera': (_) => const PathfindingCameraScreen(),
        '/settings': (_) => SettingsScreen(
              currentMode: _themeMode,
              onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
            ),
      },
    );
  }
}
