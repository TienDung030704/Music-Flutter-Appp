import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminCommentsService {
  static const String baseUrl =
      'http://10.0.2.2/Music-App-Flutter/Music-App-Flutter/backend';

  // Get token from storage
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('AdminCommentsService: Got token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      print('AdminCommentsService: Error getting token: $e');
      return null;
    }
  }

  // Get all comments for admin management
  Future<Map<String, dynamic>> getAdminComments({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'Vui lòng đăng nhập để truy cập'};
      }

      String url = '$baseUrl/comments/admin/list?page=$page&limit=$limit';
      if (status != null && status.isNotEmpty) {
        url += '&status=$status';
      }
      if (search != null && search.isNotEmpty) {
        url += '&search=$search';
      }

      print('AdminCommentsService: Calling URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('AdminCommentsService: Response status: ${response.statusCode}');
      print('AdminCommentsService: Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể lấy danh sách bình luận',
        };
      }
    } catch (e) {
      print('AdminCommentsService: Exception: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // Delete comment (soft delete)
  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'Vui lòng đăng nhập để truy cập'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/comments/admin/delete/$commentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {'success': true, 'message': data['data']['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể xóa bình luận',
        };
      }
    } catch (e) {
      print('AdminCommentsService: Error deleting comment: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // Restore comment
  Future<Map<String, dynamic>> restoreComment(int commentId) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'Vui lòng đăng nhập để truy cập'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/comments/admin/restore/$commentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {'success': true, 'message': data['data']['message']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể khôi phục bình luận',
        };
      }
    } catch (e) {
      print('AdminCommentsService: Error restoring comment: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // Get admin comment stats
  Future<Map<String, dynamic>> getCommentStats() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'Vui lòng đăng nhập để truy cập'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/comments/admin/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể lấy thống kê',
        };
      }
    } catch (e) {
      print('AdminCommentsService: Error getting stats: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }
}
