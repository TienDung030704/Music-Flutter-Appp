import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import '../services/play_tracking_service.dart';

class SongTile extends StatefulWidget {
  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.trailing,
    this.showPlayCount = true,
  });

  final Song song;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showPlayCount;

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  final PlayTrackingService _playTrackingService = PlayTrackingService();
  int _playCount = 0;
  bool _loadingPlayCount = false;

  @override
  void initState() {
    super.initState();
    if (widget.showPlayCount) {
      _loadPlayCount();
    }
  }

  Future<void> _loadPlayCount() async {
    if (!widget.showPlayCount || !mounted) return;

    setState(() {
      _loadingPlayCount = true;
    });

    try {
      // Determine song type and ID properly
      String songType = widget.song.type ?? 'itunes';
      String songId = '';

      if (widget.song.trackId != null) {
        songId = widget.song.trackId.toString();
      } else if (widget.song.id.isNotEmpty) {
        songId = widget.song.id;
      }

      print('Loading play count for: $songType/$songId');

      if (songId.isNotEmpty) {
        final count = await _playTrackingService.getPlayCount(songType, songId);
        print('Got play count: $count for song: ${widget.song.title}');

        if (mounted) {
          setState(() {
            _playCount = count;
            _loadingPlayCount = false;
          });
        }
      } else {
        print('Empty songId for song: ${widget.song.title}');
        if (mounted) {
          setState(() {
            _loadingPlayCount = false;
          });
        }
      }
    } catch (e) {
      print('Error loading play count: $e');
      if (mounted) {
        setState(() {
          _loadingPlayCount = false;
        });
      }
    }
  }

  String _formatPlayCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      double k = count / 1000;
      if (k == k.roundToDouble()) {
        return '${k.round()}K';
      } else {
        return '${k.toStringAsFixed(1)}K';
      }
    } else {
      double m = count / 1000000;
      if (m == m.roundToDouble()) {
        return '${m.round()}M';
      } else {
        return '${m.toStringAsFixed(1)}M';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppTheme.surface,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: widget.song.artwork != null
                    ? Image.network(
                        widget.song.artwork!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.black12,
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.black38,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.black12,
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.black38,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.song.artists,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (widget.showPlayCount) ...[
                        Icon(
                          Icons.play_circle_outline,
                          size: 14,
                          color: AppTheme.textSecondary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        _loadingPlayCount
                            ? SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppTheme.textSecondary.withOpacity(
                                    0.7,
                                  ),
                                ),
                              )
                            : Text(
                                '${_formatPlayCount(_playCount)} lượt nghe',
                                style: TextStyle(
                                  color: AppTheme.textSecondary.withOpacity(
                                    0.8,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          widget.song.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            widget.trailing ??
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.play_arrow, color: Colors.white),
                ),
          ],
        ),
      ),
    );
  }
}
