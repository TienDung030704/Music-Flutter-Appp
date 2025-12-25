import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final AudioPlayer _audioPlayer;
  late final ApiService _apiService;
  int _unreadNotificationCount = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _apiService = ApiService();
    _loadUnreadNotificationCount();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadUnreadNotificationCount();
    });
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final result = await NotificationService.getUnreadCount();
      if (result.success && result.data != null) {
        setState(() {
          _unreadNotificationCount = result.data!;
        });
      }
    } catch (e) {
      // Silently fail for notification count
    }
  }

  Future<Song> _onPlaySong(Song song) async {
    try {
      return await _apiService.getSongDetail(song.id);
    } catch (e) {
      return song; // Return original song if API fails
    }
  }

  late final List<Widget> _screens = [
    const HomeScreen(),
    LibraryScreen(audioPlayer: _audioPlayer, onPlaySong: _onPlaySong),
    const SearchScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home, Icons.home_outlined, 'Trang chủ'),
                _buildNavItem(
                  1,
                  Icons.library_music,
                  Icons.library_music_outlined,
                  'Thư viện',
                ),
                _buildNavItem(
                  2,
                  Icons.search,
                  Icons.search_outlined,
                  'Tìm kiếm',
                ),
                _buildNavItem(
                  3,
                  Icons.person,
                  Icons.person_outline,
                  'Cá nhân',
                  hasNotification: _unreadNotificationCount > 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label, {
    bool hasNotification = false,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onItemTapped(index),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? activeIcon : inactiveIcon,
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      size: 24,
                    ),
                    if (hasNotification)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
