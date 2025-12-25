import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import '../services/favorites_service.dart';
import '../services/playlist_service.dart';
import '../services/listening_history_service.dart';
import '../services/play_tracking_service.dart';
import '../services/download_service.dart';
import '../helpers/notification_helper.dart';
import '../screens/lyrics_screen.dart';
import '../widgets/comment_bottom_sheet.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.audioPlayer,
    required this.songs,
    required this.initialIndex,
    required this.onPlaySong,
    this.onSongChange,
  });

  final AudioPlayer audioPlayer;
  final List<Song> songs;
  final int initialIndex;
  final Future<Song> Function(Song song) onPlaySong;
  final ValueChanged<Song>? onSongChange;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late int _currentIndex;
  Song? _currentSong;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  bool _isFavorite = false;
  bool _isCheckingFavorite = true;

  // PageView controller for swipe between player and lyrics
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Listening history tracking
  final ListeningHistoryService _historyService = ListeningHistoryService();
  final PlayTrackingService _playTrackingService = PlayTrackingService();

  DateTime? _songStartTime;
  bool _hasTrackedThisSong = false;
  Timer? _trackingTimer;

  // Play count tracking
  int? _currentPlaySession;
  DateTime? _playSessionStart;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.songs.length - 1);
    _currentSong = widget.songs[_currentIndex];
    if (_currentSong?.duration != null) {
      _duration = _currentSong!.duration!;
    }
    _listenPlayer();
    _syncPlayerState();
    _checkFavoriteStatus();

    // Start tracking for initial song
    _songStartTime = DateTime.now();
    _hasTrackedThisSong = false;
    _startTrackingTimer();

    // Start play count tracking
    _startPlaySession();
  }

  void _syncPlayerState() async {
    // Get current player state when PlayerScreen opens
    final currentState = widget.audioPlayer.state;
    final currentPosition = await widget.audioPlayer.getCurrentPosition();
    final currentDuration = await widget.audioPlayer.getDuration();

    setState(() {
      _playerState = currentState;
      if (currentPosition != null) {
        _position = currentPosition;
      }
      if (currentDuration != null && currentDuration.inMilliseconds > 0) {
        _duration = currentDuration;
      }
    });
  }

  void _listenPlayer() {
    _positionSub = widget.audioPlayer.onPositionChanged.listen((position) {
      setState(() => _position = position);

      // Track listening history when reaching 30 seconds
      if (!_hasTrackedThisSong &&
          _songStartTime != null &&
          position.inSeconds >= 30) {
        _trackListeningHistory();
      }
    });
    _durationSub = widget.audioPlayer.onDurationChanged.listen((duration) {
      // Chỉ cập nhật nếu duration hợp lệ (>0) để tránh lỗi đè 0 vào duration có sẵn từ API
      if (duration.inMilliseconds > 0) {
        setState(() => _duration = duration);
      }
    });
    _stateSub = widget.audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _playerState = state);

      // Handle play session based on state changes
      if (state == PlayerState.playing) {
        // Starting to play - start new session if none exists
        if (_currentPlaySession == null) {
          _startPlaySession();
        }
      } else if (state == PlayerState.paused || state == PlayerState.stopped) {
        // Paused or stopped - end current session to track play count
        _endPlaySessionForPlayCount();
      }
    });
  }

  @override
  void dispose() {
    // Track final song before disposing
    _trackListeningHistory();
    _endPlaySession();

    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _trackingTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_playerState == PlayerState.playing) {
      await widget.audioPlayer.pause();
      // Note: _endPlaySession will be called by onPlayerStateChanged listener
    } else {
      await widget.audioPlayer.resume();
      // Note: _startPlaySession will be called by onPlayerStateChanged listener if needed
    }
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= widget.songs.length) return;

    // Track previous song if there was one
    await _trackListeningHistory();
    await _endPlaySession();

    // Immediate UI update to reset previous state
    setState(() {
      _currentIndex = index;
      // Optimistic update
      _currentSong = widget.songs[index];
      _position = Duration.zero;
      _playerState = PlayerState.playing; // Assume playing soon
    });

    try {
      final song = widget.songs[index];
      final updated = await widget.onPlaySong(song);

      if (!mounted) return;
      setState(() {
        _currentSong = updated;
        if (updated.duration != null) {
          _duration = updated.duration!;
        }
      });
      widget.onSongChange?.call(updated);

      // Check favorite status for new song
      _checkFavoriteStatus();

      // Reset tracking for new song
      _songStartTime = DateTime.now();
      _hasTrackedThisSong = false;
      _startTrackingTimer();

      // Start new play session
      _startPlaySession();
    } catch (e) {
      // Error during song change, continue with defaults
      debugPrint('Error during song change: $e');
    }
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Track listening history when song changes or session ends
  Future<void> _trackListeningHistory() async {
    if (_currentSong == null || _songStartTime == null || _hasTrackedThisSong) {
      return;
    }

    try {
      final now = DateTime.now();
      final listeningDuration = now.difference(_songStartTime!).inSeconds;

      // Only track if listened for at least 15 seconds
      // This prevents accidental or brief plays from cluttering history
      if (listeningDuration < 15) {
        return;
      }

      final song = _currentSong!;

      // Determine song type and ID based on source
      String songType = 'itunes'; // Default to iTunes
      String songId = song.id;

      // Admin songs detection:
      // 1. Pure numeric ID with small value (< 1000)
      // 2. iTunes songs usually have very large trackIds (millions)
      if (song.id.isNotEmpty && int.tryParse(song.id) != null) {
        final numericId = int.parse(song.id);
        if (numericId < 1000) {
          // Small numeric IDs are admin songs
          songType = 'admin';
        }
      }

      final result = await _historyService.addListeningHistory(
        songType: songType,
        songId: songId,
        songTitle: song.title,
        artistName: song.artists,
        thumbnail: song.artwork,
        durationListened: listeningDuration,
      );

      if (result['success']) {
        _hasTrackedThisSong = true;
        NotificationHelper.showSuccess(
          'Đã thêm "${song.title}" vào lịch sử nghe',
        );
      } else {
        NotificationHelper.showError(
          'Không thể lưu lịch sử: ${result['message']}',
        );
      }
    } catch (e) {
      NotificationHelper.showError('Không thể lưu lịch sử: ${e.toString()}');
    }
  }

  /// Start play session for play count tracking
  Future<void> _startPlaySession() async {
    if (_currentSong == null) return;

    try {
      String songType = _currentSong!.type ?? 'itunes';
      String songId = _currentSong!.trackId?.toString() ?? _currentSong!.id;

      if (songId.isEmpty) return;

      final result = await _playTrackingService.startPlaySession(
        songType,
        songId,
      );

      if (result['success']) {
        setState(() {
          // Convert session_id to int regardless of whether it comes as String or int
          final sessionId = result['session_id'];
          _currentPlaySession = sessionId is String
              ? int.parse(sessionId)
              : sessionId as int;
          _playSessionStart = DateTime.now();
        });
      }
    } catch (e) {
      // Ignore errors - play counting is not critical functionality
    }
  }

  /// End play session and increment play count if threshold is met
  Future<void> _endPlaySession() async {
    if (_currentPlaySession == null || _playSessionStart == null) return;

    try {
      final now = DateTime.now();
      final playDuration = now.difference(_playSessionStart!).inSeconds;

      await _playTrackingService.endPlaySession(
        _currentPlaySession!,
        playDuration,
        songTitle: _currentSong?.title,
        artistName: _currentSong?.artists,
      );

      // Clear session
      _currentPlaySession = null;
      _playSessionStart = null;
    } catch (e) {
      // Ignore errors - play counting is not critical functionality
    }
  }

  /// End play session for play count tracking but keep session data for potential resume
  Future<void> _endPlaySessionForPlayCount() async {
    if (_currentPlaySession == null || _playSessionStart == null) return;

    try {
      final now = DateTime.now();
      final playDuration = now.difference(_playSessionStart!).inSeconds;

      // Only call endPlaySession if we have meaningful play time
      if (playDuration >= 3) {
        // At least 3 seconds
        await _playTrackingService.endPlaySession(
          _currentPlaySession!,
          playDuration,
          songTitle: _currentSong?.title,
          artistName: _currentSong?.artists,
        );

        // Clear session after tracking
        _currentPlaySession = null;
        _playSessionStart = null;
      }
    } catch (e) {
      // Ignore errors - play counting is not critical functionality
    }
  }

  double _sliderMax() {
    final durationMs = _duration.inMilliseconds.toDouble();
    if (durationMs > 0) {
      return durationMs;
    }
    return 1.0;
  }

  double _sliderValue() {
    final value = _position.inMilliseconds.toDouble();
    final max = _sliderMax();

    // Nếu duration chưa có (max=1), giữ slider ở 0 thay vì nhảy full
    if (max <= 1.0) {
      return 0;
    }

    if (value.isNaN) {
      return 0;
    }
    if (value > max) {
      return max;
    }
    if (value < 0) {
      return 0;
    }
    return value;
  }

  Future<void> _checkFavoriteStatus() async {
    if (_currentSong == null) return;

    setState(() {
      _isCheckingFavorite = true;
    });

    try {
      final response = await FavoritesService.checkFavoriteStatus(
        _currentSong!.id,
      );

      setState(() {
        _isFavorite = response.success ? (response.data ?? false) : false;
        _isCheckingFavorite = false;
      });

      if (!response.success && response.statusCode == 401) {
        NotificationHelper.showError('Vui lòng đăng nhập lại');
      }
    } catch (e) {
      setState(() {
        _isCheckingFavorite = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentSong == null) return;

    try {
      if (_isFavorite) {
        final response = await FavoritesService.removeFromFavorites(
          _currentSong!.id,
        );
        if (response.success) {
          NotificationHelper.showSuccess('Đã xóa khỏi danh sách yêu thích');
          setState(() {
            _isFavorite = false;
          });
        } else {
          NotificationHelper.showError(response.error ?? 'Có lỗi xảy ra');
        }
      } else {
        final response = await FavoritesService.addToFavorites(
          songId: _currentSong!.id,
          songTitle: _currentSong!.title,
          artistName: _currentSong!.artists,
          thumbnail: _currentSong!.artwork ?? '',
          duration: _currentSong!.duration?.inSeconds,
        );
        if (response.success) {
          NotificationHelper.showSuccess('Đã thêm vào danh sách yêu thích');
          setState(() {
            _isFavorite = true;
          });
        } else {
          NotificationHelper.showError(response.error ?? 'Có lỗi xảy ra');
        }
      }
    } catch (e) {
      NotificationHelper.showError('Có lỗi xảy ra: $e');
    }
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'favorite':
        _addToLibrary();
        break;
      case 'playlist':
        _showAddToPlaylistDialog();
        break;
      case 'comment':
        _showCommentBottomSheet();
        break;
      case 'download':
        _addToDownloads();
        break;
    }
  }

  void _addToLibrary() async {
    if (_currentSong == null) return;

    try {
      if (_isFavorite) {
        final response = await FavoritesService.removeFromFavorites(
          _currentSong!.id,
        );
        if (response.success) {
          setState(() {
            _isFavorite = false;
          });
          NotificationHelper.showSuccess('Đã xóa khỏi thư viện');
        } else {
          NotificationHelper.showError(
            response.error ?? 'Không thể xóa khỏi thư viện',
          );
        }
      } else {
        final response = await FavoritesService.addToFavorites(
          songId: _currentSong!.id,
          songTitle: _currentSong!.title,
          artistName: _currentSong!.artists,
          thumbnail: _currentSong!.artwork,
          duration: _currentSong!.duration?.inMilliseconds,
        );
        if (response.success) {
          setState(() {
            _isFavorite = true;
          });
          NotificationHelper.showSuccess('Đã thêm vào thư viện');
        } else {
          NotificationHelper.showError(
            response.error ?? 'Không thể thêm vào thư viện',
          );
        }
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi: ${e.toString()}');
    }
  }

  void _showAddToPlaylistDialog() async {
    if (_currentSong == null) return;

    try {
      // Show loading dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Load playlists
      final response = await PlaylistService.getUserPlaylists();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (!response.success) {
        NotificationHelper.showError(
          response.error ?? 'Không thể tải danh sách playlist',
        );
        return;
      }

      final playlists = response.data;
      if (playlists == null || playlists.isEmpty) {
        NotificationHelper.showInfo(
          'Bạn chưa có playlist nào. Hãy tạo playlist mới trước!',
        );
        return;
      }

      // Show playlist selection dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text(
                'Chọn playlist',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.queue_music,
                        color: AppTheme.accent,
                      ),
                      title: Text(
                        playlist['name'] ?? 'Playlist',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      subtitle: Text(
                        '${playlist['song_count'] ?? 0} bài hát',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _addToPlaylist(playlist['id'].toString());
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      NotificationHelper.showError('Lỗi khi tải playlist: ${e.toString()}');
    }
  }

  void _addToPlaylist(String playlistId) async {
    if (_currentSong == null) return;

    try {
      final response = await PlaylistService.addSongToPlaylist(
        int.parse(playlistId),
        _currentSong!,
      );

      if (response.success) {
        NotificationHelper.showSuccess('Đã thêm bài hát vào playlist');
      } else {
        NotificationHelper.showError(
          response.error ?? 'Không thể thêm vào playlist',
        );
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi: ${e.toString()}');
    }
  }

  String _getSongType(Song song) {
    // Admin songs detection:
    // 1. Pure numeric ID with small value (< 1000)
    // 2. iTunes songs usually have very large trackIds (millions)
    if (song.id.isNotEmpty && int.tryParse(song.id) != null) {
      final numericId = int.parse(song.id);
      if (numericId < 1000) {
        return 'admin';
      }
    }
    return 'itunes';
  }

  void _showCommentBottomSheet() {
    if (_currentSong == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: CommentBottomSheet(
          songType: _getSongType(_currentSong!),
          songId: _currentSong!.id,
          songTitle: _currentSong!.title,
          artistName: _currentSong!.artists,
        ),
      ),
    );
  }

  void _addToDownloads() async {
    if (_currentSong == null) return;

    try {
      // Validate required data before downloading
      final streamUrl = _currentSong!.streamUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        NotificationHelper.showError(
          'Bài hát này không thể tải về (không có URL)',
        );
        debugPrint(
          'Download failed: streamUrl is null or empty for song ${_currentSong!.title}',
        );
        return;
      }

      // Check if URL is accessible
      if (!_isValidUrl(streamUrl)) {
        NotificationHelper.showError('URL bài hát không hợp lệ: $streamUrl');
        debugPrint('Download failed: Invalid URL: $streamUrl');
        return;
      }

      debugPrint(
        'Attempting to download: ${_currentSong!.title} with URL: $streamUrl',
      );

      final response = await DownloadService.addDownload(
        _getSongType(_currentSong!),
        _currentSong!.id,
        _currentSong!.title,
        _currentSong!.artists,
        _currentSong!.artwork ?? '',
        streamUrl,
      );

      if (response.success) {
        NotificationHelper.showSuccess('Đã thêm vào danh sách tải về');
        debugPrint('Download success: ${_currentSong!.title}');
      } else {
        NotificationHelper.showError(response.message ?? 'Có lỗi xảy ra');
        debugPrint('Download failed: ${response.message}');
      }
    } catch (e) {
      NotificationHelper.showError('Có lỗi xảy ra: $e');
      debugPrint('Download exception: $e');
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
    final song = _currentSong;
    if (song == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_currentPage == 0 ? 'Now Playing' : 'Lyrics'),
        backgroundColor: AppTheme.background,
        actions: [
          // Page indicator dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _currentPage == 0 ? Colors.white : Colors.white38,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _currentPage == 1 ? Colors.white : Colors.white38,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuSelected,
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'favorite',
                child: Row(
                  children: [
                    Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: _isFavorite ? Colors.red : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isFavorite ? 'Xóa khỏi thư viện' : 'Thêm vào thư viện',
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, size: 20),
                    SizedBox(width: 12),
                    Text('Thêm vào playlist'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'comment',
                child: Row(
                  children: [
                    Icon(Icons.comment, size: 20),
                    SizedBox(width: 12),
                    Text('Bình luận'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 12),
                    Text('Tải về'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          // Player Page
          _buildPlayerPage(song),
          // Lyrics Page
          LyricsScreen(
            key: ValueKey('lyrics_${song.id}'),
            song: song,
            currentPosition: _position,
            playerState: _playerState,
            onClose: () {
              _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPage(Song song) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1,
                child: song.artwork != null
                    ? Image.network(song.artwork!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.music_note,
                          size: 72,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    song.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                _isCheckingFavorite
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite
                              ? Colors.red
                              : AppTheme.textSecondary,
                          size: 28,
                        ),
                        onPressed: _toggleFavorite,
                      ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.artists,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              song.album,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 40),
            Slider(
              value: _sliderValue(),
              max: _sliderMax(),
              activeColor: AppTheme.accent,
              onChanged: (value) async {
                await widget.audioPlayer.seek(
                  Duration(milliseconds: value.toInt()),
                );
                // Auto play after seeking if not already playing
                if (_playerState != PlayerState.playing) {
                  await widget.audioPlayer.resume();
                }
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(_position),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                Text(
                  _formatTime(_duration),
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 34),
                  color: AppTheme.textPrimary,
                  onPressed: () {
                    final newIndex =
                        (_currentIndex - 1 + widget.songs.length) %
                        widget.songs.length;
                    _playAt(newIndex);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  onPressed: _togglePlayback,
                  child: Icon(
                    _playerState == PlayerState.playing
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 32,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 34),
                  color: AppTheme.textPrimary,
                  onPressed: () =>
                      _playAt((_currentIndex + 1) % widget.songs.length),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Listening history tracking indicator
            _buildTrackingIndicator(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingIndicator() {
    if (_songStartTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final listeningDuration = now.difference(_songStartTime!).inSeconds;
    final isTracked = _hasTrackedThisSong;
    final willTrack = listeningDuration >= 15;
    final remaining = 15 - listeningDuration;

    Color color;
    String text;
    IconData icon;

    if (isTracked) {
      color = Colors.green;
      text = 'Đã thêm vào lịch sử nghe';
      icon = Icons.check_circle;
    } else if (willTrack) {
      color = AppTheme.accent;
      text = 'Sẽ thêm vào lịch sử nghe';
      icon = Icons.history;
    } else {
      color = Colors.grey;
      text = 'Nghe thêm ${remaining}s để lưu lịch sử';
      icon = Icons.timer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _startTrackingTimer() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _songStartTime != null && !_hasTrackedThisSong) {
        setState(() {
          // Force rebuild of tracking indicator
        });
      }
    });
  }
}
