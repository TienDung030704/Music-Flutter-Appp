import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.progress,
    this.onPlayPause,
    this.onTap,
  });

  final Song song;
  final bool isPlaying;
  final double progress;
  final VoidCallback? onPlayPause;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 80,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: song.artwork != null
                              ? Image.network(
                                  song.artwork!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.black12,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: Colors.black12,
                                  child: const Icon(
                                    Icons.music_note,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artists,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          size: 36,
                        ),
                        color: AppTheme.textPrimary,
                        onPressed: onPlayPause,
                      ),
                    ],
                  ),
                ),
              ),
              LinearProgressIndicator(
                value: progress.isFinite ? progress : 0,
                color: AppTheme.accent,
                backgroundColor: Colors
                    .transparent, // Make background transparent for cleaner look
                minHeight: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
