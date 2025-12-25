import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/lyrics_service.dart';
import '../models/song.dart';

class LyricsScreen extends StatefulWidget {
  final Song song;
  final Duration currentPosition;
  final PlayerState playerState;
  final VoidCallback onClose;

  const LyricsScreen({
    super.key,
    required this.song,
    required this.currentPosition,
    required this.playerState,
    required this.onClose,
  });

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen>
    with SingleTickerProviderStateMixin {
  LyricsData? _lyricsData;
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Auto-scroll variables
  double _scrollSpeed = 0.0; // pixels per second
  int _startTimeSeconds = 15; // Default start time
  bool _isAutoScrolling = false;
  Timer? _autoScrollTimer;
  int _currentLineIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadLyrics();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LyricsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition ||
        widget.playerState != oldWidget.playerState) {
      _checkAndStartAutoScroll();
    }
  }

  Future<void> _loadLyrics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final lyrics = await LyricsService.getLyrics(widget.song.id);

      if (mounted) {
        setState(() {
          if (lyrics.success && lyrics.data != null) {
            _lyricsData = lyrics.data;
            if (lyrics.data!.startTime != null && lyrics.data!.startTime! > 0) {
              _startTimeSeconds = (lyrics.data!.startTime! / 1000).round();
            }
            _calculateAutoScrollSpeed();
          } else {
            _error = lyrics.message ?? 'Failed to load lyrics';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _calculateAutoScrollSpeed() {
    if (_lyricsData == null || _lyricsData!.lyricsContent?.isEmpty != false)
      return;

    // Count lines in lyrics
    final lines = _lyricsData!.lyricsContent!
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return;

    // Estimate song duration (can be improved with actual duration)
    const estimatedSongDurationSeconds = 240; // 4 minutes
    final scrollableSeconds = estimatedSongDurationSeconds - _startTimeSeconds;

    if (scrollableSeconds <= 0) return;

    // Calculate scroll speed
    const itemHeight = 48.0; // Approximate height per line with margin
    final totalScrollHeight = lines.length * itemHeight;

    _scrollSpeed = totalScrollHeight / scrollableSeconds;
  }

  void _calculateCurrentLine() {
    if (_lyricsData == null || _lyricsData!.lyricsContent?.isEmpty != false)
      return;

    final lines = _lyricsData!.lyricsContent!
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) return;

    final currentSeconds = widget.currentPosition.inSeconds;
    if (currentSeconds < _startTimeSeconds) {
      _updateCurrentLine(0);
      return;
    }

    // Use lastIndexWhere to find current line based on timing
    const estimatedSongDurationSeconds = 240;
    final scrollableSeconds = estimatedSongDurationSeconds - _startTimeSeconds;
    final elapsedSeconds = currentSeconds - _startTimeSeconds;

    if (scrollableSeconds <= 0 || elapsedSeconds < 0) return;

    // Create time points for each line
    final timePerLine = scrollableSeconds / lines.length;

    // Use lastIndexWhere to find the current line (convert to List first)
    final newLineIndex = lines.asMap().entries.toList().lastIndexWhere(
      (entry) => elapsedSeconds >= (entry.key * timePerLine),
    );

    if (newLineIndex >= 0) {
      _updateCurrentLine(newLineIndex);
    }
  }

  void _updateCurrentLine(int newIndex) {
    if (newIndex == _currentLineIndex) return; // No change, no update needed

    final oldIndex = _currentLineIndex;
    setState(() {
      _currentLineIndex = newIndex;
    });

    // Only scroll when line changes (not continuously)
    if (oldIndex != newIndex && _scrollController.hasClients) {
      _scrollToLine(newIndex);
    }
  }

  void _scrollToLine(int lineIndex) {
    if (!_scrollController.hasClients) return;

    const itemHeight = 48.0;
    final targetOffset = (lineIndex * itemHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    // Smooth scroll with faster response time
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250), // Faster, more responsive
      curve: Curves.easeInOut,
    );
  }

  void _checkAndStartAutoScroll() {
    if (_lyricsData == null) return;

    if (widget.currentPosition.inSeconds >= _startTimeSeconds &&
        widget.playerState == PlayerState.playing) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _isAutoScrolling = false;
  }

  void _startAutoScroll() {
    if (_isAutoScrolling ||
        _lyricsData == null ||
        !_scrollController.hasClients)
      return;

    _isAutoScrolling = true;

    // Start timer to check line changes (faster response for better sync)
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) {
      if (!mounted ||
          _lyricsData == null ||
          !_scrollController.hasClients ||
          widget.playerState != PlayerState.playing) {
        _stopAutoScroll();
        return;
      }

      // Only calculate current line (scroll happens in _updateCurrentLine when line changes)
      _calculateCurrentLine();

      final currentSeconds = widget.currentPosition.inSeconds;
      if (currentSeconds < _startTimeSeconds) {
        _stopAutoScroll();
        return;
      }

      final elapsedSeconds = currentSeconds - _startTimeSeconds;
      final targetScrollPosition = elapsedSeconds * _scrollSpeed;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final clampedPosition = targetScrollPosition.clamp(0.0, maxScroll);

      // Smooth scroll to position
      if ((_scrollController.position.pixels - clampedPosition).abs() > 5.0) {
        _scrollController.animateTo(
          clampedPosition,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header with close button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Lyrics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44), // Balance the close button
                  ],
                ),
              ),
            ),

            // Song info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    widget.song.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.song.artists,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Lyrics Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _isLoading
                    ? _buildLoadingState()
                    : _error != null
                    ? _buildErrorState()
                    : _buildAutoScrollLyrics(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoScrollLyrics() {
    if (_lyricsData == null || _lyricsData!.lyricsContent?.isEmpty != false) {
      return _buildStaticLyrics();
    }

    final lines = _lyricsData!.lyricsContent!
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const Center(
        child: Text(
          'No lyrics content available',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final isCurrentLine = _isAutoScrolling && index == _currentLineIndex;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: EdgeInsets.symmetric(
            horizontal: isCurrentLine ? 16 : 0,
            vertical: isCurrentLine ? 8 : 0,
          ),
          decoration: isCurrentLine
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                )
              : null,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: isCurrentLine ? 22 : 18,
              fontWeight: isCurrentLine ? FontWeight.w600 : FontWeight.w400,
              color: isCurrentLine ? Colors.white : Colors.white70,
              height: 1.8,
            ),
            child: Text(lines[index].trim(), textAlign: TextAlign.center),
          ),
        );
      },
    );
  }

  Widget _buildStaticLyrics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 100),
          Text(
            _lyricsData?.lyricsContent ?? 'No lyrics available',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Unable to load lyrics',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _loadLyrics,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            'Loading lyrics...',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
