import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../helpers/notification_helper.dart';
import 'favorites_screen.dart';
import 'playlist_screen.dart';
import 'recent_listening_screen.dart';
import 'downloads_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';

class LibraryScreen extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final Future<Song> Function(Song song) onPlaySong;

  const LibraryScreen({
    super.key,
    required this.audioPlayer,
    required this.onPlaySong,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppTheme.background,
              elevation: 0,
              pinned: true,
              expandedHeight: 60,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Thư viện',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSection(
                    context,
                    icon: Icons.history,
                    title: 'Nghe gần đây',
                    subtitle: 'Lịch sử nghe nhạc',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecentListeningScreen(
                            audioPlayer: audioPlayer,
                            onPlaySong: onPlaySong,
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16),
                  _buildSection(
                    context,
                    icon: Icons.favorite,
                    title: 'Yêu thích',
                    subtitle: 'Bài hát đã thích',
                    color: Colors.pink,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FavoritesScreen(
                            audioPlayer: audioPlayer,
                            onPlaySong: onPlaySong,
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16),
                  _buildSection(
                    context,
                    icon: Icons.download,
                    title: 'Đã tải về',
                    subtitle: 'Bài hát đã tải về',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DownloadsScreen(
                            audioPlayer: audioPlayer,
                            onPlaySong: onPlaySong,
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16),
                  _buildSection(
                    context,
                    icon: Icons.playlist_play,
                    title: 'Playlist của tôi',
                    subtitle: 'Danh sách phát',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaylistScreen(
                            audioPlayer: audioPlayer,
                            onPlaySong: onPlaySong,
                          ),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
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
          onTap:
              onTap ??
              () {
                NotificationHelper.showInfo(
                  'Tính năng "$title" đang phát triển',
                );
              },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
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
  }
}
