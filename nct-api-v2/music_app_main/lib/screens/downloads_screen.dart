import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/song.dart';
import '../services/download_service.dart';
import '../helpers/notification_helper.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class DownloadsScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Future<Song> Function(Song song) onPlaySong;

  const DownloadsScreen({
    super.key,
    required this.audioPlayer,
    required this.onPlaySong,
  });

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Song> _downloads = [];
  List<int> _downloadIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('[DEBUG] Loading downloads...');
      final response = await DownloadService.getDownloads();
      print(
        '[DEBUG] Downloads response: ${response.success}, Status: ${response.statusCode}',
      );

      if (response.success && response.data != null) {
        final List<Song> downloads = [];
        final List<int> downloadIds = [];

        print('[DEBUG] Processing ${response.data!.length} downloads');

        for (final item in response.data!) {
          downloads.add(
            Song(
              id: item['song_id'].toString(),
              title: item['song_title'] ?? 'Không có tiêu đề',
              artists: item['artist_name'] ?? 'Không có nghệ sĩ',
              album: 'Album không xác định',
              artwork: item['artwork_url'],
              streamUrl: item['download_url'],
            ),
          );

          downloadIds.add(item['id']);
        }

        setState(() {
          _downloads = downloads;
          _downloadIds = downloadIds;
          _isLoading = false;
        });

        print('[DEBUG] Loaded ${downloads.length} downloads successfully');
      } else {
        setState(() {
          _isLoading = false;
        });

        print('[DEBUG] Failed to load downloads: ${response.message}');
        if (response.statusCode == 401) {
          NotificationHelper.showError('Vui lòng đăng nhập lại');
        } else {
          NotificationHelper.showError('Không thể tải danh sách tải về');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('[DEBUG] Exception loading downloads: $e');
      NotificationHelper.showError('Lỗi kết nối: $e');
    }
  }

  Future<void> _removeFromDownloads(Song song, int index) async {
    if (index >= _downloadIds.length) return;

    try {
      final response = await DownloadService.removeDownload(
        _downloadIds[index],
      );
      if (response.success) {
        setState(() {
          _downloads.removeAt(index);
          _downloadIds.removeAt(index);
        });
        NotificationHelper.showSuccess('Đã xóa khỏi danh sách tải về');
      } else {
        NotificationHelper.showError('Không thể xóa: ${response.message}');
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi kết nối: $e');
    }
  }

  Future<void> _playSong(Song song, int index) async {
    try {
      // Validate song has valid stream URL before playing
      if (song.streamUrl == null || song.streamUrl!.isEmpty) {
        NotificationHelper.showError('Bài hát này không có URL để phát');
        return;
      }

      // Check if URL is valid
      if (!_isValidUrl(song.streamUrl!)) {
        NotificationHelper.showError('URL bài hát không hợp lệ');
        return;
      }

      await widget.onPlaySong(song);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              audioPlayer: widget.audioPlayer,
              songs: _downloads,
              initialIndex: index,
              onPlaySong: widget.onPlaySong,
            ),
          ),
        );
      }
    } catch (e) {
      NotificationHelper.showError('Không thể phát bài hát: $e');
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Đã tải về'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloads.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có bài hát nào được tải về',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Thêm bài hát yêu thích vào danh sách tải về',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDownloads,
              child: ListView.builder(
                itemCount: _downloads.length,
                itemBuilder: (context, index) {
                  final song = _downloads[index];
                  return SongTile(
                    song: song,
                    onTap: () => _playSong(song, index),
                    trailing: IconButton(
                      icon: Icon(Icons.more_vert),
                      onPressed: () => _showMoreOptions(song, index),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showMoreOptions(Song song, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Phát ngay'),
              onTap: () {
                Navigator.pop(context);
                _playSong(song, index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Xóa khỏi tải về',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeFromDownloads(song, index);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
