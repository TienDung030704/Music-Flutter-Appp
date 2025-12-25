import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/song.dart';
import '../services/favorites_service.dart';
import '../helpers/notification_helper.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class FavoritesScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Future<Song> Function(Song song) onPlaySong;

  const FavoritesScreen({
    super.key,
    required this.audioPlayer,
    required this.onPlaySong,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Song> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await FavoritesService.getUserFavorites();
      if (response.success && response.data != null) {
        final List<Song> favorites = [];

        for (final item in response.data!) {
          favorites.add(
            Song(
              id: item['song_id'].toString(),
              title: item['song_title'] ?? 'Không có tiêu đề',
              artists: item['artist_name'] ?? 'Không có nghệ sĩ',
              album: 'Album không xác định',
              artwork: item['thumbnail'],
              duration: item['duration'] != null
                  ? Duration(seconds: item['duration'])
                  : null,
            ),
          );
        }

        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 401) {
          NotificationHelper.showError('Vui lòng đăng nhập lại');
        } else {
          NotificationHelper.showError('Không thể tải danh sách yêu thích');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      NotificationHelper.showError('Lỗi kết nối: $e');
    }
  }

  Future<void> _removeFromFavorites(Song song) async {
    try {
      final response = await FavoritesService.removeFromFavorites(song.id);
      if (response.success) {
        setState(() {
          _favorites.removeWhere((s) => s.id == song.id);
        });
        NotificationHelper.showSuccess('Đã xóa khỏi danh sách yêu thích');
      } else {
        NotificationHelper.showError('Không thể xóa: ${response.error}');
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi kết nối: $e');
    }
  }

  Future<void> _playSong(Song song, int index) async {
    try {
      await widget.onPlaySong(song);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            audioPlayer: widget.audioPlayer,
            songs: _favorites,
            initialIndex: index,
            onPlaySong: widget.onPlaySong,
          ),
        ),
      );
    } catch (e) {
      NotificationHelper.showError('Không thể phát bài hát: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Bài hát yêu thích'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có bài hát yêu thích',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thêm bài hát vào yêu thích để xem tại đây',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final song = _favorites[index];
                return SongTile(
                  song: song,
                  onTap: () => _playSong(song, index),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () => _removeFromFavorites(song),
                  ),
                );
              },
            ),
    );
  }
}
