import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../helpers/notification_helper.dart';
import '../services/listening_history_service.dart';
import '../models/song.dart';

class RecentListeningScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Future<Song> Function(Song song) onPlaySong;

  const RecentListeningScreen({
    super.key,
    required this.audioPlayer,
    required this.onPlaySong,
  });

  @override
  State<RecentListeningScreen> createState() => _RecentListeningScreenState();
}

class _RecentListeningScreenState extends State<RecentListeningScreen> {
  final ListeningHistoryService _historyService = ListeningHistoryService();
  List<Map<String, dynamic>> _recentDays = [];
  Map<String, dynamic>? _selectedDayHistory;
  String? _selectedDate;
  bool _isLoading = false;
  bool _isDayHistoryLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentHistory();
  }

  Future<void> _loadRecentHistory() async {
    setState(() => _isLoading = true);

    try {
      final result = await _historyService.getRecentListeningHistory();
      if (result['success']) {
        setState(() {
          _recentDays = List<Map<String, dynamic>>.from(result['recent_days']);
        });
      } else {
        NotificationHelper.showError(result['message']);
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi khi tải dữ liệu: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadDayHistory(String date) async {
    setState(() {
      _isDayHistoryLoading = true;
      _selectedDate = date;
    });

    try {
      final result = await _historyService.getListeningHistoryByDate(date);
      if (result['success']) {
        setState(() {
          _selectedDayHistory = result;
        });
      } else {
        NotificationHelper.showError(result['message']);
        setState(() {
          _selectedDayHistory = null;
        });
      }
    } catch (e) {
      NotificationHelper.showError('Lỗi khi tải lịch sử: $e');
      setState(() {
        _selectedDayHistory = null;
      });
    }

    setState(() => _isDayHistoryLoading = false);
  }

  Future<void> _playHistorySong(Map<String, dynamic> historyItem) async {
    try {
      final song = Song(
        id: historyItem['song_id'],
        title: historyItem['song_title'],
        artists: historyItem['artist_name'],
        album: '',
        artwork: historyItem['thumbnail'] ?? '',
        streamUrl: '', // Will be resolved by onPlaySong
      );

      await widget.onPlaySong(song);
      NotificationHelper.showSuccess('Đang phát: ${song.title}');
    } catch (e) {
      NotificationHelper.showError('Không thể phát bài hát: $e');
    }
  }

  void _clearDayHistory(String date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Xóa lịch sử',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Bạn có chắc muốn xóa lịch sử nghe của ngày này?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await _historyService.clearListeningHistory(
                date: date,
              );
              if (result['success']) {
                NotificationHelper.showSuccess(result['message']);
                _loadRecentHistory();
                setState(() {
                  _selectedDayHistory = null;
                  _selectedDate = null;
                });
              } else {
                NotificationHelper.showError(result['message']);
              }
            },
            child: Text('Xóa', style: TextStyle(color: Colors.red)),
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
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedDate != null
              ? 'Lịch sử ngày ${ListeningHistoryService.formatVietnameseDate(_selectedDate!)}'
              : 'Nghe gần đây',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_selectedDate != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _clearDayHistory(_selectedDate!),
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: _selectedDate != null
                ? () => _loadDayHistory(_selectedDate!)
                : _loadRecentHistory,
          ),
        ],
      ),
      body: _selectedDate == null
          ? _buildRecentDaysView()
          : _buildDayHistoryView(),
    );
  }

  Widget _buildRecentDaysView() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    if (_recentDays.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'Chưa có lịch sử nghe nhạc',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Hãy nghe nhạc để xem lịch sử ở đây',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _recentDays.length,
      itemBuilder: (context, index) {
        final dayData = _recentDays[index];
        final date = dayData['listen_date'];
        final songCount = dayData['song_count'];
        final recentSongs = dayData['recent_songs'];

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _loadDayHistory(date),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: AppTheme.accent,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ListeningHistoryService.formatVietnameseDate(date),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '$songCount bài hát',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          if (recentSongs != null &&
                              recentSongs.isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text(
                              recentSongs,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayHistoryView() {
    if (_isDayHistoryLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    if (_selectedDayHistory == null || _selectedDayHistory!['songs'].isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'Không có bài hát nào trong ngày này',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {
                _selectedDate = null;
                _selectedDayHistory = null;
              }),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: Text('Quay lại', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final songs = List<Map<String, dynamic>>.from(
      _selectedDayHistory!['songs'],
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng cộng: ${songs.length} bài hát',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ngày ${ListeningHistoryService.formatVietnameseDate(_selectedDate!)}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final songType = song['song_type'];
              final thumbnail = song['thumbnail'];

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _playHistorySong(song),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppTheme.accent.withValues(alpha: 0.1),
                            ),
                            child: thumbnail != null && thumbnail.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      thumbnail,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.music_note,
                                              color: AppTheme.accent,
                                              size: 24,
                                            );
                                          },
                                    ),
                                  )
                                : Icon(
                                    Icons.music_note,
                                    color: AppTheme.accent,
                                    size: 24,
                                  ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song['song_title'],
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  song['artist_name'],
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: songType == 'admin'
                                            ? Colors.green.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.blue.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        songType == 'admin'
                                            ? 'Admin'
                                            : 'iTunes',
                                        style: TextStyle(
                                          color: songType == 'admin'
                                              ? Colors.green
                                              : Colors.blue,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      DateTime.parse(
                                        song['listened_at'],
                                      ).toLocal().toString().substring(11, 16),
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.play_arrow,
                            color: AppTheme.accent,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
