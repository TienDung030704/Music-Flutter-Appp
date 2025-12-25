class Song {
  final String id;
  final String title;
  final String artists;
  final String album;
  final String? artwork;
  final Duration? duration;
  final String? streamUrl;
  final String? audioUrl;
  final String? imageUrl;
  final String? type;
  final int? trackId;

  const Song({
    required this.id,
    required this.title,
    required this.artists,
    required this.album,
    this.artwork,
    this.duration,
    this.streamUrl,
    this.audioUrl,
    this.imageUrl,
    this.type,
    this.trackId,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    // Determine song type based on data structure
    String? songType;
    int? trackIdValue;

    if (json.containsKey('trackId')) {
      // iTunes song
      songType = 'itunes';
      trackIdValue = int.tryParse(json['trackId']?.toString() ?? '');
    } else if (json.containsKey('category') || json.containsKey('itunes_id')) {
      // Admin/curated song
      songType = 'admin';
      trackIdValue = int.tryParse(json['id']?.toString() ?? '');
    } else {
      // Default to iTunes for backward compatibility
      songType = 'itunes';
      trackIdValue = int.tryParse(
        json['trackId']?.toString() ?? json['id']?.toString() ?? '',
      );
    }

    return Song(
      id: json['id']?.toString() ?? '',
      title:
          json['title']?.toString() ??
          json['trackName']?.toString() ??
          'Unknown title',
      artists:
          json['artists']?.toString() ??
          json['artistName']?.toString() ??
          json['artist']?.toString() ??
          'Unknown artist',
      album:
          json['album']?.toString() ?? json['collectionName']?.toString() ?? '',
      artwork:
          (json['artwork'] ?? json['thumbnail'] ?? json['artworkUrl100'])
              as String?,
      duration: _parseDuration(json),
      streamUrl:
          (json['stream_url'] ?? json['streamUrl'] ?? json['previewUrl'])
              as String?,
      type: songType,
      trackId: trackIdValue,
    );
  }

  Song copyWith({
    String? id,
    String? title,
    String? artists,
    String? album,
    String? artwork,
    Duration? duration,
    String? streamUrl,
    String? type,
    int? trackId,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      artwork: artwork ?? this.artwork,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
      type: type ?? this.type,
      trackId: trackId ?? this.trackId,
    );
  }

  static Duration? _parseDuration(Map<String, dynamic> json) {
    if (json['durationMillis'] == null) {
      return null;
    }

    final millis = int.tryParse(json['durationMillis'].toString());
    if (millis == null) {
      return null;
    }

    return Duration(milliseconds: millis);
  }
}

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final String? error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.error,
    this.statusCode,
  });
}
