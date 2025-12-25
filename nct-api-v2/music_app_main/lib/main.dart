import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:music_app_main/theme/app_theme.dart';
import 'package:music_app_main/screens/main_screen.dart';

import 'package:music_app_main/screens/favorites_screen.dart';
import 'package:music_app_main/screens/playlist_screen.dart';
import 'package:music_app_main/screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KDT Music',
      theme: AppTheme.lightTheme(),
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: false,
      checkerboardRasterCacheImages: false,
      checkerboardOffscreenLayers: false,
      showSemanticsDebugger: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),

        '/login': (context) => const LoginScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle routes that need parameters
        if (settings.name == '/favorites') {
          return MaterialPageRoute(
            builder: (context) => FavoritesScreen(
              audioPlayer: AudioPlayer(), // Create new instance
              onPlaySong: (song) async => song, // Dummy implementation
            ),
          );
        }
        if (settings.name == '/playlists') {
          return MaterialPageRoute(
            builder: (context) => PlaylistScreen(
              audioPlayer: AudioPlayer(), // Create new instance
              onPlaySong: (song) async => song, // Dummy implementation
            ),
          );
        }
        return null;
      },
    );
  }
}
