import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PlayTrackingService {
  static String get baseUrl {
    if (kIsWeb) {
      // For web (localhost)
      return 'http://localhost/Music-App-Flutter/Music-App-Flutter/backend';
    } else if (Platform.isAndroid) {
      // For Android emulator
      return 'http://10.0.2.2/Music-App-Flutter/Music-App-Flutter/backend';
    } else if (Platform.isIOS) {
      // For iOS simulator
      return 'http://localhost/Music-App-Flutter/Music-App-Flutter/backend';
    } else {
      // For desktop (Windows, macOS, Linux)
      return 'http://localhost/Music-App-Flutter/Music-App-Flutter/backend';
    }
  }

  Future<Map<String, dynamic>> startPlaySession(
    String songType,
    String songId,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      Map<String, String> headers = {'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('$baseUrl/play/start-session'),
        headers: headers,
        body: jsonEncode({'song_type': songType, 'song_id': songId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {'success': true, 'session_id': data['data']['session_id']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể bắt đầu phiên nghe nhạc',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  Future<Map<String, dynamic>> endPlaySession(
    int sessionId,
    int playDuration, {
    String? songTitle,
    String? artistName,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      Map<String, String> headers = {'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      Map<String, dynamic> body = {
        'session_id': sessionId,
        'play_duration': playDuration,
      };

      if (songTitle != null) body['song_title'] = songTitle;
      if (artistName != null) body['artist_name'] = artistName;

      final response = await http.post(
        Uri.parse('$baseUrl/play/end-session'),
        headers: headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'counted_as_play': data['data']['counted_as_play'],
          'play_duration': data['data']['play_duration'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể kết thúc phiên nghe nhạc',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  Future<int> getPlayCount(String songType, String songId) async {
    try {
      if (songId.isEmpty) return 0;

      final response = await http.get(
        Uri.parse('$baseUrl/play/count/$songType/$songId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return data['data']['play_count'] ?? 0;
        }
      }

      return 0;
    } catch (e) {
      print('Error getting play count: $e');
      return 0;
    }
  }

  Future<Map<String, int>> getPlayCounts(
    List<Map<String, String>> songs,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/play/counts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'songs': songs}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        Map<String, int> playCounts = {};

        for (var item in data['data']) {
          String key = '${item['song_type']}_${item['song_id']}';
          playCounts[key] = item['play_count'] ?? 0;
        }

        return playCounts;
      } else {
        return {};
      }
    } catch (e) {
      return {};
    }
  }

  // Admin only methods
  Future<Map<String, dynamic>> getTopPlayedSongs({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      print('DEBUG - getTopPlayedSongs token: $token');

      if (token == null) {
        print('DEBUG - No auth token found for top songs');
        return {'success': false, 'message': 'Cần đăng nhập'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/play/top-songs?limit=$limit&offset=$offset'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(
        'DEBUG - getTopPlayedSongs response status: ${response.statusCode}',
      );
      print('DEBUG - getTopPlayedSongs response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'songs': data['data']['songs'],
          'total': data['data']['total'],
          'limit': data['data']['limit'],
          'offset': data['data']['offset'],
        };
      } else {
        return {
          'success': false,
          'message':
              data['message'] ??
              data['error'] ??
              'Không thể lấy danh sách bài hát',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  Future<Map<String, dynamic>> getPlayStatistics() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'message': 'Cần đăng nhập'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/play/statistics'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {'success': true, 'statistics': data['data']};
      } else {
        return {
          'success': false,
          'message':
              data['message'] ?? data['error'] ?? 'Không thể lấy thống kê',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }
}
