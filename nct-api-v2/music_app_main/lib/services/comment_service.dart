import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/comment.dart';
import '../models/user_model.dart' show ApiConfig;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class CommentService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Get token from storage
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  // Add comment to a song
  Future<Map<String, dynamic>> addComment({
    required String songType,
    required String songId,
    required String songTitle,
    required String artistName,
    required String commentText,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {'success': false, 'message': 'Vui lòng đăng nhập để bình luận'};
      }

      final requestData = {
        'song_type': songType,
        'song_id': songId,
        'song_title': songTitle,
        'artist_name': artistName,
        'comment_text': commentText,
      };

      // Try the request
      var response = await _makeAuthenticatedRequest(
        'POST',
        '$baseUrl/comments/add',
        body: requestData,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'message': data['data']['message'],
          'comment': Comment.fromJson(data['data']['comment']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể thêm bình luận',
        };
      }
    } catch (e) {
      print('Error adding comment: $e');
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }

  // Helper method to make authenticated requests with automatic token refresh
  Future<http.Response> _makeAuthenticatedRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _getToken();

    if (token == null) {
      throw Exception('No auth token available');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Make the initial request
    http.Response response;
    switch (method.toUpperCase()) {
      case 'POST':
        response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(Uri.parse(url), headers: headers);
        break;
      default: // GET
        response = await http.get(Uri.parse(url), headers: headers);
        break;
    }

    // If we get 401, try to refresh token and retry once
    if (response.statusCode == 401) {
      print('DEBUG - Token expired, attempting refresh...');

      final refreshResult = await AuthService.refreshAccessToken();
      if (refreshResult.success && refreshResult.data != null) {
        print('DEBUG - Token refreshed successfully, retrying request...');

        // Update headers with new token
        headers['Authorization'] = 'Bearer ${refreshResult.data}';

        // Retry the request
        switch (method.toUpperCase()) {
          case 'POST':
            response = await http.post(
              Uri.parse(url),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              Uri.parse(url),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(Uri.parse(url), headers: headers);
            break;
          default: // GET
            response = await http.get(Uri.parse(url), headers: headers);
            break;
        }

        print('DEBUG - Retry response status: ${response.statusCode}');
      } else {
        print('DEBUG - Token refresh failed: ${refreshResult.error}');
        // Return the original 401 response
      }
    }

    return response;
  }

  // Get comments for a song
  Future<Map<String, dynamic>> getCommentsBySong({
    required String songType,
    required String songId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final url =
          '$baseUrl/comments/song?song_type=$songType&song_id=$songId&page=$page&limit=$limit';
      print('DEBUG - GetComments URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('DEBUG - GetComments response status: ${response.statusCode}');
      print('DEBUG - GetComments response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'data': CommentsPagination.fromJson(data['data']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể lấy danh sách bình luận',
        };
      }
    } catch (e) {
      print('Error getting comments: $e');
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }

  // Update comment
  Future<Map<String, dynamic>> updateComment({
    required int commentId,
    required String commentText,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Vui lòng đăng nhập để chỉnh sửa bình luận',
        };
      }

      print('DEBUG - UpdateComment token: $token');
      print('DEBUG - UpdateComment URL: $baseUrl/comments/update/$commentId');
      print('DEBUG - UpdateComment data: {"comment_text": "$commentText"}');

      final response = await _makeAuthenticatedRequest(
        'PUT',
        '$baseUrl/comments/update/$commentId',
        body: {'comment_text': commentText},
      );

      print('DEBUG - UpdateComment response status: ${response.statusCode}');
      print('DEBUG - UpdateComment response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final responseData = <String, dynamic>{
          'success': true,
          'message': data['data']['message'],
        };

        // Add comment data if present
        if (data['data']['comment'] != null) {
          responseData['comment'] = Comment.fromJson(data['data']['comment']);
        }

        return responseData;
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể cập nhật bình luận',
        };
      }
    } catch (e) {
      print('Error updating comment: $e');
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }

  // Delete comment
  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Vui lòng đăng nhập để xóa bình luận',
        };
      }

      final response = await _makeAuthenticatedRequest(
        'DELETE',
        '$baseUrl/comments/delete/$commentId',
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
      print('Error deleting comment: $e');
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }

  // Admin: Get all comments with pagination
  Future<Map<String, dynamic>> getCommentsForAdmin({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    try {
      final token = await _getToken();
      print('[DEBUG] Admin comments - Token: ${token?.substring(0, 10)}...');

      if (token == null) {
        print('[DEBUG] Admin comments - No token found');
        return {'success': false, 'message': 'Vui lòng đăng nhập để truy cập'};
      }

      String url = '$baseUrl/comments/admin/list?page=$page&limit=$limit';
      if (status != null && status.isNotEmpty) {
        url += '&status=$status';
      }
      if (search != null && search.isNotEmpty) {
        url += '&search=$search';
      }

      print('[DEBUG] Admin comments - URL: $url');
      print(
        '[DEBUG] Admin comments - Headers: Authorization Bearer ${token.substring(0, 10)}...',
      );

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('[DEBUG] Admin comments - Status code: ${response.statusCode}');
      print('[DEBUG] Admin comments - Response body: ${response.body}');

      final data = jsonDecode(response.body);
      print('[DEBUG] Admin comments - Parsed data success: ${data['success']}');

      if (response.statusCode == 200 && data['success']) {
        print(
          '[DEBUG] Admin comments - Data structure: ${data['data'].runtimeType}',
        );
        final pagination = AdminCommentsPagination.fromJson(data['data']);
        print(
          '[DEBUG] Admin comments - Comments count: ${pagination.comments.length}',
        );
        return {'success': true, 'data': pagination};
      } else {
        print('[DEBUG] Admin comments - API error: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể lấy danh sách bình luận',
        };
      }
    } catch (e, stackTrace) {
      print('[DEBUG] Admin comments - Exception: $e');
      print('[DEBUG] Admin comments - Stack trace: $stackTrace');
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }

  // Admin: Delete comment (soft delete)
  Future<Map<String, dynamic>> adminDeleteComment(int commentId) async {
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
      print('Error admin deleting comment: $e');
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }

  // Admin: Restore comment
  Future<Map<String, dynamic>> adminRestoreComment(int commentId) async {
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
      print('Error admin restoring comment: $e');
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }

  // Admin: Get comment statistics
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
          'message': data['message'] ?? 'Không thể lấy thống kê bình luận',
        };
      }
    } catch (e) {
      print('Error getting comment stats: $e');
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }
}
