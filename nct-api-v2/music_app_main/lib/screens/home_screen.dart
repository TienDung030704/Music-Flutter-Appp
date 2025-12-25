import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/api_service.dart';
import '../services/admin_service.dart';
import '../services/play_tracking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../helpers/notification_helper.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Map<String, String> _featuredQueries = const {
    'Tuyệt Phẩm Bolero': 'bolero Quang Lê Cẩm Ly',
    'V-Pop Thịnh Hành': 'vpop hits',
    'Nhạc Trẻ Remix': 'vinahouse remix',
  };

  Map<String, List<Song>> _sections = {};
  bool _loadingSections = false;
  bool _isSearching = false;
  List<Song> _searchResults = [];
  Song? _currentSong;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
    _initPlayerStreams();
  }

  void _initPlayerStreams() {
    _positionSub = _audioPlayer.onPositionChanged.listen((value) {
      setState(() => _position = value);
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((value) {
      setState(() => _duration = value);
    });
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _playerState = state);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    _log('Refreshing featured sections…');
    setState(() => _loadingSections = true);
    final Map<String, List<Song>> results = {};

    try {
      final futures = _featuredQueries.entries.map((entry) async {
        try {
          // Load từ iTunes API
          final iTunesSongs = await _apiService.searchSongs(entry.value);

          // Load từ admin database
          final adminResponse = await AdminService.getAdminSongs(
            category: entry.key,
          );
          final adminSongs = adminResponse.success
              ? adminResponse.data!
              : <Song>[];

          // Merge cả 2 danh sách (admin songs trước để ưu tiên hiển thị)
          final allSongs = <Song>[...adminSongs, ...iTunesSongs];

          _log(
            'Loaded ${allSongs.length} songs for ${entry.key} (${adminSongs.length} admin + ${iTunesSongs.length} iTunes)',
          );
          return MapEntry(entry.key, allSongs.take(20).toList());
        } catch (e) {
          _log('Error loading ${entry.key}: $e');
          return null;
        }
      });

      final entries = await Future.wait(futures);
      for (final entry in entries) {
        if (entry != null) {
          results[entry.key] = entry.value;
        }
      }

      if (mounted) {
        setState(() => _sections = results);
      }
    } catch (_) {
      // ignore global fetch errors
    } finally {
      if (mounted) {
        setState(() => _loadingSections = false);
      }
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    _log('Searching for "$query"...');
    setState(() => _isSearching = true);
    try {
      final songs = await _apiService.searchSongs(query);
      setState(() => _searchResults = songs);
      _log('Search returned ${songs.length} songs');
    } catch (error) {
      if (!mounted) return;
      NotificationHelper.showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<Song> _ensureStreamUrl(Song song) async {
    if (song.streamUrl != null && song.streamUrl!.isNotEmpty) {
      _log('Song already has stream URL: ${song.streamUrl}');
      return song;
    }

    _log('Fetching details for song ID: ${song.id}, title: ${song.title}');

    try {
      final detail = await _apiService.getSongDetail(song.id);
      _log('Got detail - streamUrl: ${detail.streamUrl}');

      final merged = song.copyWith(
        artwork: detail.artwork ?? song.artwork,
        duration: detail.duration ?? song.duration,
        streamUrl: detail.streamUrl ?? song.streamUrl,
      );

      if (mounted) {
        setState(() {
          _searchResults = _searchResults
              .map((s) => s.id == merged.id ? merged : s)
              .toList();
          _sections = _sections.map(
            (key, value) => MapEntry(
              key,
              value.map((s) => s.id == merged.id ? merged : s).toList(),
            ),
          );
        });
      }

      return merged;
    } catch (e) {
      _log('Error fetching song details: $e');
      throw Exception('Không thể lấy thông tin bài hát: $e');
    }
  }

  Future<Song> _playSong(Song song) async {
    try {
      final playable = await _ensureStreamUrl(song);
      _log('Playing "${playable.title}" by ${playable.artists}');

      if (playable.streamUrl == null || playable.streamUrl!.isEmpty) {
        _log('Stream URL is null or empty for song: ${playable.title}');
        throw Exception('Không thể phát bài hát: URL không hợp lệ');
      }

      _log('Stream URL: ${playable.streamUrl}');
      await _audioPlayer.stop();

      setState(() {
        _currentSong = playable;
        _position = Duration.zero;
        if (playable.duration != null) {
          _duration = playable.duration!;
        }
      });

      await _audioPlayer.setSource(UrlSource(playable.streamUrl!));
      await _audioPlayer.resume();
      return playable;
    } catch (e) {
      _log('Error playing song: $e');
      if (mounted) {
        NotificationHelper.showError('Lỗi phát nhạc: $e');
      }
      rethrow;
    }
  }

  Future<void> _openPlayer(Song song, List<Song> playlist) async {
    try {
      final playable = await _playSong(song);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            audioPlayer: _audioPlayer,
            songs: playlist,
            initialIndex: playlist.indexWhere(
              (element) => element.id == playable.id,
            ),
            onPlaySong: _playSong,
            onSongChange: (updated) => setState(() => _currentSong = updated),
          ),
        ),
      );

      // Refresh play counts when returning from player
      setState(() {}); // Force rebuild to refresh _SongCard play counts
    } catch (e) {
      _log('Error opening player: $e');
      if (mounted) {
        NotificationHelper.showError(
          'Không thể mở trình phát: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _loadFeatured),
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.background,
            title: GestureDetector(
              onTap: () {
                setState(() {
                  _searchController.clear();
                  _isSearching = false;
                  _searchResults = [];
                  FocusManager.instance.primaryFocus?.unfocus();
                });
              },
              child: const Text(
                'KDT Music',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const CircleAvatar(
                  backgroundColor: AppTheme.surface,
                  child: Icon(Icons.menu, color: AppTheme.textSecondary),
                ),
                onSelected: (String value) async {
                  switch (value) {
                    case 'downloads':
                      Navigator.pushNamed(context, '/downloads');
                      break;
                    case 'favorites':
                      Navigator.pushNamed(context, '/favorites');
                      break;
                    case 'playlists':
                      Navigator.pushNamed(context, '/playlists');
                      break;
                    case 'login':
                      Navigator.pushNamed(context, '/login');
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'downloads',
                    child: Row(
                      children: [
                        Icon(Icons.download_outlined),
                        SizedBox(width: 12),
                        Text('Tải về'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'favorites',
                    child: Row(
                      children: [
                        Icon(Icons.favorite_outline),
                        SizedBox(width: 12),
                        Text('Yêu thích'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'playlists',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_play),
                        SizedBox(width: 12),
                        Text('Playlist'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'login',
                    child: Row(
                      children: [
                        Icon(Icons.login),
                        SizedBox(width: 12),
                        Text('Đăng nhập'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(child: _buildSearchBar()),
          if (_searchResults.isEmpty && !_isSearching) ...[
            SliverToBoxAdapter(child: _buildHeroRow()),
            ...(_loadingSections
                ? const [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    ),
                  ]
                : _buildFeaturedSections()),
          ],
          if (_isSearching)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = _searchResults[index];
                  return SongTile(
                    song: song,
                    onTap: () => _openPlayer(song, _searchResults),
                  );
                }, childCount: _searchResults.length),
              ),
            )
          else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Tìm kiếm để khám phá bản nhạc bạn yêu thích',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),
        ],
      ),

      bottomNavigationBar: _currentSong == null
          ? null
          : MiniPlayer(
              song: _currentSong!,
              progress: _duration.inMilliseconds == 0
                  ? 0
                  : (_position.inMilliseconds / _duration.inMilliseconds).clamp(
                      0,
                      1,
                    ),
              isPlaying: _playerState == PlayerState.playing,
              onTap: () {
                if (_currentSong == null) return;
                _openPlayer(
                  _currentSong!,
                  _searchResults.isNotEmpty
                      ? _searchResults
                      : _sections.values.expand((e) => e).toList(),
                );
              },
              onPlayPause: () {
                if (_playerState == PlayerState.playing) {
                  _audioPlayer.pause();
                } else {
                  _audioPlayer.resume();
                }
              },
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm bolero, chill, acoustic...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _performSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Play'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroRow() {
    final heroCards = [
      _HeroCardData(
        title: 'Lâu Đài Tình Ái',
        subtitle: 'Cẩm Ly',
        imageUrl:
            'https://images.unsplash.com/photo-1507878866276-a947ef722fee?auto=format&fit=crop&w=600&q=60',
        query: 'Cẩm Ly',
      ),
      _HeroCardData(
        title: 'Sầu tím thiệp hồng',
        subtitle: 'Quang Lê',
        imageUrl:
            'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=600&q=60',
        query: 'Quang Lê',
      ),
      _HeroCardData(
        title: 'Lo-Fi Chill',
        subtitle: 'Thư giãn cuối ngày',
        imageUrl:
            'https://images.unsplash.com/photo-1485579149621-3123dd979885?auto=format&fit=crop&w=600&q=60',
        query: 'lofi chill',
      ),
    ];

    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = heroCards[index];
          return _HeroCard(
            data: item,
            onTap: () {
              _searchController.text = item.query;
              _performSearch();
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemCount: heroCards.length,
      ),
    );
  }

  List<Widget> _buildFeaturedSections() {
    final widgets = <Widget>[];

    _sections.forEach((title, songs) {
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _searchResults = songs);
                  },
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
        ),
      );

      widgets.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final song = songs[index];
                return _SongCard(
                  song: song,
                  onTap: () => _openPlayer(song, songs),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemCount: songs.length,
            ),
          ),
        ),
      );
    });

    return widgets;
  }

  void _log(String message) {
    debugPrint('[HomeScreen] $message');
  }
}

class _HeroCardData {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String query;

  _HeroCardData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.query,
  });
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data, required this.onTap});

  final _HeroCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(
            image: NetworkImage(data.imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              data.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(data.subtitle, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _SongCard extends StatefulWidget {
  const _SongCard({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> {
  final PlayTrackingService _playTrackingService = PlayTrackingService();
  int _playCount = 0;
  bool _loadingPlayCount = true;

  @override
  void initState() {
    super.initState();
    _loadPlayCount();
  }

  @override
  void didUpdateWidget(_SongCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload play count when parent rebuilds (e.g., returning from player)
    if (oldWidget.song.id != widget.song.id) {
      _loadPlayCount();
    } else {
      // Force reload play count even for same song to get latest data
      _loadPlayCount();
    }
  }

  Future<void> _loadPlayCount() async {
    try {
      // Handle nullable song type and trackId
      final songType = widget.song.type ?? 'itunes';
      final trackId = widget.song.trackId?.toString() ?? '';

      if (trackId.isEmpty) {
        setState(() {
          _loadingPlayCount = false;
        });
        return;
      }

      final playCount = await _playTrackingService.getPlayCount(
        songType,
        trackId,
      );
      if (mounted) {
        setState(() {
          _playCount = playCount;
          _loadingPlayCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPlayCount = false;
        });
      }
    }
  }

  String _formatPlayCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.song.artwork != null
                    ? Image.network(
                        widget.song.artwork!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.black12,
                            child: const Icon(
                              Icons.music_note,
                              size: 32,
                              color: Colors.black38,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.black12,
                        child: const Icon(
                          Icons.music_note,
                          size: 32,
                          color: Colors.black38,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              widget.song.artists,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.play_arrow, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 2),
                Text(
                  _loadingPlayCount
                      ? '...'
                      : '${_formatPlayCount(_playCount)} lượt nghe',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
