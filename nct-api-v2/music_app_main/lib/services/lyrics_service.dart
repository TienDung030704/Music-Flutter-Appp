import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/auth_service.dart';

class LyricsData {
  final String songId;
  final String? songTitle;
  final String? artistName;
  final String? lyricsContent;
  final bool hasSync;
  final int? startTime;
  final List<SyncLyric> syncLyrics;

  LyricsData({
    required this.songId,
    this.songTitle,
    this.artistName,
    this.lyricsContent,
    required this.hasSync,
    this.startTime,
    required this.syncLyrics,
  });

  factory LyricsData.fromJson(Map<String, dynamic> json) {
    var syncLyricsData = json['syncLyrics'] as List? ?? [];

    // Handle hasSync as int (0/1) or bool from backend
    bool hasSync = false;
    var hasSyncValue = json['hasSync'];
    if (hasSyncValue is bool) {
      hasSync = hasSyncValue;
    } else if (hasSyncValue is int) {
      hasSync = hasSyncValue == 1;
    }

    return LyricsData(
      songId: json['songId'] ?? '',
      songTitle: json['lyrics']?['song_title'],
      artistName: json['lyrics']?['artist_name'],
      lyricsContent: json['lyrics']?['lyrics_content'],
      hasSync: hasSync,
      startTime: json['startTime'] ?? json['lyrics']?['lyrics_start_time'],
      syncLyrics: syncLyricsData
          .map((item) => SyncLyric.fromJson(item))
          .toList(),
    );
  }
}

class SyncLyric {
  final int startTime;
  final int endTime;
  final String text;
  final int lineOrder;

  SyncLyric({
    required this.startTime,
    required this.endTime,
    required this.text,
    required this.lineOrder,
  });

  factory SyncLyric.fromJson(Map<String, dynamic> json) {
    return SyncLyric(
      startTime: json['start_time'] ?? 0,
      endTime: json['end_time'] ?? 0,
      text: json['text'] ?? '',
      lineOrder: json['line_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'startTime': startTime, 'endTime': endTime, 'text': text};
  }
}

class LyricsService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // Get lyrics for a song
  static Future<ApiResponse<LyricsData>> getLyrics(String songId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/lyrics/$songId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        final lyricsData = LyricsData.fromJson(responseData['data']);

        return ApiResponse<LyricsData>(
          success: true,
          data: lyricsData,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<LyricsData>(
          success: false,
          error: responseData['error'] ?? 'Failed to load lyrics',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<LyricsData>(
        success: false,
        error: 'Connection error: $e',
        statusCode: 500,
      );
    }
  }

  // Admin: Save lyrics (add/update)
  static Future<ApiResponse<void>> saveLyrics({
    required String songId,
    required String songTitle,
    String? artistName,
    String? lyricsContent,
    List<SyncLyric>? syncLyrics,
    int? startTime,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Not authenticated',
          statusCode: 401,
        );
      }

      final body = {
        'songId': songId,
        'songTitle': songTitle,
        'artistName': artistName,
        'lyricsContent': lyricsContent,
        'startTime': startTime,
        'syncLyrics': syncLyrics?.map((lyric) => lyric.toJson()).toList() ?? [],
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/lyrics'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return ApiResponse<void>(
          success: true,
          message: responseData['data']['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: responseData['error'] ?? 'Failed to save lyrics',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: 'Connection error: $e',
        statusCode: 500,
      );
    }
  }

  // Admin: Delete lyrics
  static Future<ApiResponse<void>> deleteLyrics(String songId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Not authenticated',
          statusCode: 401,
        );
      }

      final response = await http
          .delete(
            Uri.parse('$_baseUrl/lyrics/$songId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return ApiResponse<void>(
          success: true,
          message: responseData['data']['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: responseData['error'] ?? 'Failed to delete lyrics',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: 'Connection error: $e',
        statusCode: 500,
      );
    }
  }

  // Admin: Get all lyrics for management
  static Future<ApiResponse<Map<String, dynamic>>> getAllLyrics({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Not authenticated',
          statusCode: 401,
        );
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/lyrics/admin?page=$page&limit=$limit'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: responseData['data'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: responseData['error'] ?? 'Failed to load lyrics list',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Connection error: $e',
        statusCode: 500,
      );
    }
  }
}
