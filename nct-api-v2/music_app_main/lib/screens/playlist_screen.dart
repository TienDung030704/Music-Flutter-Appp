import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';
import '../services/playlist_service.dart';
import '../services/auth_service.dart';
import '../helpers/notification_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Future<Song> Function(Song) onPlaySong;

  const PlaylistScreen({
    Key? key,
    required this.audioPlayer,
    required this.onPlaySong,
  }) : super(key: key);

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Map<String, dynamic>> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadPlaylists();
  }

  void _redirectToLogin() {
    // Clear stored tokens
    AuthService.clearTokens();

    // Navigate back to main screen and let it handle authentication
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

  Future<void> _checkAuthAndLoadPlaylists() async {
    final token = await AuthService.getToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        NotificationHelper.showError('Vui lòng đăng nhập để xem playlist');
        _redirectToLogin();
      }
      return;
    }
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await PlaylistService.getUserPlaylists();

      if (mounted) {
        if (response.success && response.data != null) {
          setState(() {
            _playlists = response.data!;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });

          // Check if it's authentication error
          if (response.statusCode == 401) {
            NotificationHelper.showError(
              'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại',
            );
            _redirectToLogin();
            return;
          } else {
            NotificationHelper.showError(
              response.error ?? 'Không thể tải danh sách playlist',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        NotificationHelper.showError('Lỗi: ${e.toString()}');
      }
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    // Check if user is authenticated first
    final token = await AuthService.getToken();
    if (token == null) {
      NotificationHelper.showError('Vui lòng đăng nhập để tạo playlist');
      _redirectToLogin();
      return;
    }

    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'Tạo playlist mới',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Tên playlist',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textSecondary),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accent),
                  ),
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Mô tả (tuỳ chọn)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textSecondary),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accent),
                  ),
                ),
                maxLines: 2,
                maxLength: 200,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Huỷ',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  NotificationHelper.showError('Vui lòng nhập tên playlist');
                  return;
                }

                Navigator.of(context).pop();
                await _createPlaylist(name, descriptionController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Tạo', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPlaylist(String name, String description) async {
    try {
      final response = await PlaylistService.createPlaylist(
        name: name,
        description: description.isNotEmpty ? description : null,
      );

      if (response.success) {
        NotificationHelper.showSuccess('Tạo playlist thành công!');
        _loadPlaylists(); // Refresh the list
      } else {
        // Check if it's authentication error
        if (response.statusCode == 401) {
          NotificationHelper.showError(
            'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại',
          );
          _redirectToLogin();
        } else {
          NotificationHelper.showError(
            response.error ?? 'Không thể tạo playlist',
          );
        }
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi: ${e.toString()}');
    }
  }

  Future<void> _deletePlaylist(int playlistId, String playlistName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'Xóa playlist',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa playlist "$playlistName"?',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Huỷ',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final response = await PlaylistService.deletePlaylist(playlistId);
        if (response.success) {
          NotificationHelper.showSuccess('Xóa playlist thành công!');
          _loadPlaylists(); // Refresh the list
        } else {
          NotificationHelper.showError(
            response.error ?? 'Không thể xóa playlist',
          );
        }
      } catch (e) {
        NotificationHelper.showError('Lỗi: ${e.toString()}');
      }
    }
  }

  Future<void> _openPlaylistDetail(Map<String, dynamic> playlist) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(
          audioPlayer: widget.audioPlayer,
          onPlaySong: widget.onPlaySong,
          playlist: playlist,
          onPlaylistUpdated: _loadPlaylists,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Playlist của tôi',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlaylistDialog,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : _playlists.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.playlist_add,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có playlist nào',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nhấn nút + để tạo playlist đầu tiên',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                final playlist = _playlists[index];
                final songCount = playlist['song_count'] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.playlist_play,
                        color: AppTheme.accent,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      playlist['name'] ?? 'Playlist',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (playlist['description'] != null &&
                            playlist['description'].toString().isNotEmpty) ...[
                          Text(
                            playlist['description'],
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          '$songCount bài hát',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppTheme.textSecondary,
                      ),
                      color: AppTheme.surface,
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deletePlaylist(
                            playlist['id'],
                            playlist['name'] ?? 'Playlist',
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Xóa playlist',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _openPlaylistDetail(playlist),
                  ),
                );
              },
            ),
    );
  }
}

// PlaylistDetailScreen để xem chi tiết playlist và các bài hát trong đó
class PlaylistDetailScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Future<Song> Function(Song) onPlaySong;
  final Map<String, dynamic> playlist;
  final VoidCallback onPlaylistUpdated;

  const PlaylistDetailScreen({
    Key? key,
    required this.audioPlayer,
    required this.onPlaySong,
    required this.playlist,
    required this.onPlaylistUpdated,
  }) : super(key: key);

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Map<String, dynamic>> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylistDetails();
  }

  Future<void> _loadPlaylistDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await PlaylistService.getPlaylistDetails(
        widget.playlist['id'],
      );

      if (response.success && response.data != null) {
        final playlistData = response.data!;
        setState(() {
          _songs = List<Map<String, dynamic>>.from(playlistData['songs'] ?? []);
          _isLoading = false;
        });
      } else {
        NotificationHelper.showError(
          response.error ?? 'Không thể tải chi tiết playlist',
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi: ${e.toString()}');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeSongFromPlaylist(String songId, int index) async {
    try {
      final response = await PlaylistService.removeSongFromPlaylist(
        widget.playlist['id'],
        songId,
      );

      if (response.success) {
        setState(() {
          _songs.removeAt(index);
        });
        NotificationHelper.showSuccess('Xóa bài hát khỏi playlist thành công!');
        widget.onPlaylistUpdated(); // Refresh parent screen
      } else {
        NotificationHelper.showError(response.error ?? 'Không thể xóa bài hát');
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi: ${e.toString()}');
    }
  }

  Future<void> _playSong(Map<String, dynamic> songData, int index) async {
    try {
      final song = Song(
        id: songData['song_id'],
        title: songData['song_title'],
        artists: songData['artist_name'] ?? '',
        album: '',
        artwork: songData['thumbnail'],
        duration: songData['duration'] != null
            ? Duration(milliseconds: songData['duration'])
            : null,
      );

      await widget.onPlaySong(song);

      if (!mounted) return;

      // Convert songs to Song objects for player
      final songList = _songs
          .map(
            (s) => Song(
              id: s['song_id'],
              title: s['song_title'],
              artists: s['artist_name'] ?? '',
              album: '',
              artwork: s['thumbnail'],
              duration: s['duration'] != null
                  ? Duration(milliseconds: s['duration'])
                  : null,
            ),
          )
          .toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            audioPlayer: widget.audioPlayer,
            songs: songList,
            initialIndex: index,
            onPlaySong: widget.onPlaySong,
          ),
        ),
      );
    } catch (e) {
      NotificationHelper.showError('Lỗi phát nhạc: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          widget.playlist['name'] ?? 'Playlist',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : Column(
              children: [
                // Playlist info header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.playlist_play,
                          color: AppTheme.accent,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.playlist['name'] ?? 'Playlist',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.playlist['description'] != null &&
                                widget.playlist['description']
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.playlist['description'],
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${_songs.length} bài hát',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Songs list
                Expanded(
                  child: _songs.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_note,
                                size: 64,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Chưa có bài hát nào',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _songs.length,
                          itemBuilder: (context, index) {
                            final songData = _songs[index];
                            final song = Song(
                              id: songData['song_id'],
                              title: songData['song_title'],
                              artists: songData['artist_name'] ?? '',
                              album: '',
                              artwork: songData['thumbnail'],
                            );

                            return SongTile(
                              song: song,
                              onTap: () => _playSong(songData, index),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeSongFromPlaylist(
                                  songData['song_id'],
                                  index,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
