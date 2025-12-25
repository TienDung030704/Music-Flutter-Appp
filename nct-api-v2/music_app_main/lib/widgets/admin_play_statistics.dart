import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../theme/app_theme.dart';
import '../services/play_tracking_service.dart';

class AdminPlayStatistics extends StatefulWidget {
  const AdminPlayStatistics({super.key});

  @override
  State<AdminPlayStatistics> createState() => _AdminPlayStatisticsState();
}

class _AdminPlayStatisticsState extends State<AdminPlayStatistics> {
  final PlayTrackingService _playTrackingService = PlayTrackingService();

  bool _isLoading = true;
  Map<String, dynamic>? _statistics;
  List<dynamic> _topSongs = [];
  int _currentPage = 0;
  final int _limit = 20;
  bool _loadingMore = false;
  bool _hasMoreSongs = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([_loadStatistics(), _loadTopSongs(reset: true)]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadStatistics() async {
    try {
      final result = await _playTrackingService.getPlayStatistics();
      if (result['success']) {
        setState(() {
          _statistics = result['statistics'];
        });
      }
      // Bỏ toast error - chỉ để loading indicator
    } catch (e) {
      print('Error loading statistics: $e');
      // Bỏ toast error - silent fail
    }
  }

  Future<void> _loadTopSongs({bool reset = false}) async {
    if (_loadingMore || (!reset && !_hasMoreSongs)) return;

    setState(() {
      _loadingMore = true;
      if (reset) {
        _currentPage = 0;
        _topSongs.clear();
        _hasMoreSongs = true;
      }
    });

    try {
      final result = await _playTrackingService.getTopPlayedSongs(
        limit: _limit,
        offset: _currentPage * _limit,
      );

      if (result['success']) {
        final songs = result['songs'] as List;
        final total = result['total'] as int;

        setState(() {
          _topSongs.addAll(songs);
          _currentPage++;
          _hasMoreSongs = _topSongs.length < total;
        });
      } else {
        String errorMsg = result['message'] ?? 'Không thể tải bài hát';
        if (errorMsg.contains('quyền truy cập') ||
            errorMsg.contains('đăng nhập')) {
          errorMsg = 'Cần đăng nhập với tài khoản Admin';
        }
        Fluttertoast.showToast(
          msg: errorMsg,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
        );
      }
    } catch (e) {
      print('Error loading top songs: $e');
      Fluttertoast.showToast(
        msg: 'Lỗi kết nối: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
    } finally {
      setState(() {
        _loadingMore = false;
      });
    }
  }

  String _formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      double k = number / 1000;
      if (k == k.roundToDouble()) {
        return '${k.round()}K';
      } else {
        return '${k.toStringAsFixed(1)}K';
      }
    } else {
      double m = number / 1000000;
      if (m == m.roundToDouble()) {
        return '${m.round()}M';
      } else {
        return '${m.toStringAsFixed(1)}M';
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              const SizedBox(height: 16),
              const Text(
                'Đang tải thống kê...',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final stats = _statistics!;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thống Kê Tổng Quan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Tổng Lượt Nghe',
                    _formatNumber(stats['total_plays'] ?? 0),
                    Icons.play_arrow,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Hôm Nay',
                    _formatNumber(stats['today_plays'] ?? 0),
                    Icons.today,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Tổng Bài Hát',
                    _formatNumber(stats['total_songs'] ?? 0),
                    Icons.music_note,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Trung Bình/Bài',
                    _formatNumber(
                      (stats['average_plays_per_song'] ?? 0).round(),
                    ),
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            if (stats['top_song'] != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Bài Hát Phổ Biến Nhất',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stats['top_song']['song_title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stats['top_song']['artist_name'] ?? '',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatNumber(stats['top_song']['play_count'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopSongsList() {
    if (_topSongs.isEmpty && !_isLoading) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.music_off,
                size: 48,
                color: AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa có dữ liệu bài hát',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Cần đăng nhập với tài khoản Admin để xem dữ liệu',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Bài Hát Được Nghe Nhiều Nhất',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _topSongs.length,
            itemBuilder: (context, index) {
              final song = _topSongs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accent,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  song['song_title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song['artist_name'] ?? '',
                      style: const TextStyle(color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (song['last_played_at'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Nghe lần cuối: ${_formatDate(song['last_played_at'])}',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatNumber(song['play_count'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'lượt nghe',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_hasMoreSongs)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () => _loadTopSongs(),
                        child: const Text('Tải thêm'),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Thống Kê Lượt Nghe'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [_buildStatisticsCard(), _buildTopSongsList()],
                ),
              ),
            ),
    );
  }
}
