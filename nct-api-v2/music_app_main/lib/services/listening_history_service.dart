import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/user_model.dart' show ApiConfig;

class ListeningHistoryService {
  static const String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Add a song to listening history
  Future<Map<String, dynamic>> addListeningHistory({
    required String songType, // 'admin' or 'itunes'
    required String songId,
    required String songTitle,
    required String artistName,
    String? thumbnail,
    int durationListened = 0,
  }) async {
    try {
      // Get current user ID
      final currentUser = await AuthService.getCurrentUser();
      final userId = currentUser?.id ?? 1; // Default to 1 for testing

      // For testing, use simplified endpoint without authentication
      final body = jsonEncode({
        'user_id': userId,
        'song_type': songType,
        'song_id': songId,
        'song_title': songTitle,
        'artist_name': artistName,
        'thumbnail': thumbnail,
        'duration_listened': durationListened,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/listening-history/test-add'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'message': data['data']['message'] ?? 'Đã thêm vào lịch sử nghe',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể thêm vào lịch sử nghe',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Get listening history by specific date
  Future<Map<String, dynamic>> getListeningHistoryByDate(String date) async {
    try {
      // Get current user ID
      final currentUser = await AuthService.getCurrentUser();
      final userId = currentUser?.id ?? 1; // Default to 1 for testing

      // For testing, use simplified endpoint
      final response = await http.get(
        Uri.parse(
          '$baseUrl/listening-history/test-by-date?date=$date&user_id=$userId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'date': data['data']['date'],
          'count': data['data']['count'] ?? 0,
          'songs': data['data']['songs'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể lấy lịch sử nghe',
          'songs': [],
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e', 'songs': []};
    }
  }

  /// Get recent listening history (last 7 days)
  Future<Map<String, dynamic>> getRecentListeningHistory() async {
    try {
      // Get current user ID
      final currentUser = await AuthService.getCurrentUser();
      final userId = currentUser?.id ?? 1; // Default to 1 for testing

      // For testing, use simplified endpoint
      final response = await http.get(
        Uri.parse('$baseUrl/listening-history/test-recent?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'recent_days': data['data']['recent_days'] ?? [],
          'total_days': data['data']['total_days'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể lấy lịch sử gần đây',
          'recent_days': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
        'recent_days': [],
      };
    }
  }

  /// Get listening statistics
  Future<Map<String, dynamic>> getListeningStats() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/listening-history/stats'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'today': data['data']['today'] ?? {},
          'total': data['data']['total'] ?? {},
          'top_songs': data['data']['top_songs'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể lấy thống kê',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Clear listening history
  Future<Map<String, dynamic>> clearListeningHistory({String? date}) async {
    try {
      final headers = await _getHeaders();
      String body = '{}';

      if (date != null) {
        body = jsonEncode({'date': date});
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/listening-history/clear'),
        headers: headers,
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Đã xóa lịch sử nghe',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể xóa lịch sử nghe',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// Format duration for display
  static String formatDuration(int durationInSeconds) {
    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;
    final seconds = durationInSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Format Vietnamese date
  static String formatVietnameseDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final targetDate = DateTime(date.year, date.month, date.day);

      final difference = today.difference(targetDate).inDays;

      if (difference == 0) {
        return 'Hôm nay';
      } else if (difference == 1) {
        return 'Hôm qua';
      } else if (difference < 7) {
        return '$difference ngày trước';
      } else {
        final weekdays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
        final months = [
          '',
          'Th1',
          'Th2',
          'Th3',
          'Th4',
          'Th5',
          'Th6',
          'Th7',
          'Th8',
          'Th9',
          'Th10',
          'Th11',
          'Th12',
        ];

        return '${weekdays[date.weekday % 7]}, ${date.day} ${months[date.month]} ${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}
