import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'auth_service.dart';
import '../models/user_model.dart' show ApiConfig;

class FavoritesService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // Thêm bài hát vào favorites
  static Future<ApiResponse<void>> addToFavorites({
    required String songId,
    required String songTitle,
    String? artistName,
    String? thumbnail,
    int? duration,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/favorites'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'song_id': songId,
              'song_title': songTitle,
              'artist_name': artistName,
              'thumbnail': thumbnail,
              'duration': duration,
            }),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201 && responseData['success']) {
        return ApiResponse<void>(
          success: true,
          message: responseData['data']['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: responseData['error'] ?? 'Không thể thêm vào yêu thích',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Xóa bài hát khỏi favorites
  static Future<ApiResponse<void>> removeFromFavorites(String songId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http
          .delete(
            Uri.parse('$_baseUrl/favorites/$songId'),
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
          error: responseData['error'] ?? 'Không thể xóa khỏi yêu thích',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Kiểm tra bài hát có trong favorites không
  static Future<ApiResponse<bool>> checkFavoriteStatus(String songId) async {
    try {
      final response = await _makeAuthenticatedRequest(
        (token) => http
            .get(
              Uri.parse('$_baseUrl/favorites/$songId'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(ApiConfig.timeoutDuration),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return ApiResponse<bool>(
          success: true,
          data: responseData['data']['is_favorite'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<bool>(
          success: false,
          data: false,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<bool>(
        success: false,
        data: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Lấy danh sách favorites
  static Future<ApiResponse<List<Map<String, dynamic>>>>
  getUserFavorites() async {
    try {
      final response = await _makeAuthenticatedRequest(
        (token) => http
            .get(
              Uri.parse('$_baseUrl/favorites'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(ApiConfig.timeoutDuration),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        final List<dynamic> favoritesData = responseData['data']['favorites'];
        final List<Map<String, dynamic>> favorites = favoritesData
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        return ApiResponse<List<Map<String, dynamic>>>(
          success: true,
          data: favorites,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: responseData['error'] ?? 'Không thể lấy danh sách yêu thích',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  static Future<String?> _getToken() async {
    return await AuthService.getToken();
  }

  // Helper method to make API calls with auto retry on token expiry
  static Future<http.Response> _makeAuthenticatedRequest(
    Future<http.Response> Function(String token) requestFunction,
  ) async {
    String? token = await _getToken();
    if (token == null) {
      throw Exception('Chưa đăng nhập');
    }

    // First attempt
    http.Response response = await requestFunction(token);

    // If 401 and need refresh, try to refresh token and retry
    if (response.statusCode == 401) {
      final responseData = jsonDecode(response.body);
      if (responseData['meta'] != null &&
          responseData['meta']['need_refresh'] == true) {
        // Try to refresh token
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult.success && refreshResult.data != null) {
          // Retry with new token
          response = await requestFunction(refreshResult.data!);
        }
      }
    }

    return response;
  }
}
