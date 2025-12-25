import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'auth_service.dart';
import '../models/user_model.dart' show ApiConfig;

class PlaylistService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Tạo playlist mới
  static Future<ApiResponse<Map<String, dynamic>>> createPlaylist({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/playlists'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name': name,
              'description': description,
              'is_public': isPublic,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: responseData['data'],
          message: responseData['message'],
        );
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult.success) {
          // Retry the request with new token
          return createPlaylist(
            name: name,
            description: description,
            isPublic: isPublic,
          );
        }
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Phiên đăng nhập hết hạn',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: responseData['error'] ?? 'Không thể tạo playlist',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Lấy danh sách playlist của user
  static Future<ApiResponse<List<Map<String, dynamic>>>>
  getUserPlaylists() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/playlists'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isEmpty) {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: 'Server trả về response rỗng',
          statusCode: response.statusCode,
        );
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final List<dynamic> playlistsData = responseData['data'] ?? [];
        final playlists = playlistsData.cast<Map<String, dynamic>>();

        return ApiResponse<List<Map<String, dynamic>>>(
          success: true,
          data: playlists,
        );
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult.success) {
          // Retry the request with new token
          return getUserPlaylists();
        }
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: 'Phiên đăng nhập hết hạn',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          error: responseData['error'] ?? 'Không thể lấy danh sách playlist',
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

  // Lấy chi tiết playlist
  static Future<ApiResponse<Map<String, dynamic>>> getPlaylistDetails(
    int playlistId,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http.get(
        Uri.parse('$baseUrl/playlists/$playlistId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: responseData['data'],
        );
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult.success) {
          // Retry the request with new token
          return getPlaylistDetails(playlistId);
        }
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Phiên đăng nhập hết hạn',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: responseData['error'] ?? 'Không thể lấy chi tiết playlist',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Thêm bài hát vào playlist
  static Future<ApiResponse<void>> addSongToPlaylist(
    int playlistId,
    Song song,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/playlists/$playlistId/songs'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'song_id': song.id,
              'song_title': song.title,
              'artist_name': song.artists,
              'thumbnail': song.artwork,
              'duration': song.duration?.inMilliseconds,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return ApiResponse<void>(
          success: true,
          message: responseData['message'],
        );
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult.success) {
          // Retry the request with new token
          return addSongToPlaylist(playlistId, song);
        }
        return ApiResponse<void>(
          success: false,
          error: 'Phiên đăng nhập hết hạn',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: responseData['error'] ?? 'Không thể thêm bài hát vào playlist',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      String errorMessage = 'Lỗi không xác định';

      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Timeout - Vui lòng thử lại sau';
      } else if (e.toString().contains('ClientException')) {
        errorMessage = 'Lỗi kết nối - Kiểm tra mạng và thử lại';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Không thể kết nối tới server';
      } else {
        errorMessage = 'Lỗi: ${e.toString()}';
      }

      return ApiResponse<void>(
        success: false,
        error: errorMessage,
        statusCode: 0,
      );
    }
  }

  // Xóa bài hát khỏi playlist
  static Future<ApiResponse<void>> removeSongFromPlaylist(
    int playlistId,
    String songId,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/playlists/$playlistId/songs/$songId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return ApiResponse<void>(
          success: true,
          message: responseData['message'],
        );
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult.success) {
          // Retry the request with new token
          return removeSongFromPlaylist(playlistId, songId);
        }
        return ApiResponse<void>(
          success: false,
          error: 'Phiên đăng nhập hết hạn',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: responseData['error'] ?? 'Không thể xóa bài hát khỏi playlist',
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

  // Xóa playlist
  static Future<ApiResponse<void>> deletePlaylist(int playlistId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/playlists/$playlistId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return ApiResponse<void>(
          success: true,
          message: responseData['message'],
        );
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshResult = await AuthService.refreshAccessToken();
        if (refreshResult.success) {
          // Retry the request with new token
          return deletePlaylist(playlistId);
        }
        return ApiResponse<void>(
          success: false,
          error: 'Phiên đăng nhập hết hạn',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: responseData['error'] ?? 'Không thể xóa playlist',
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

  // Test API connection
  static Future<ApiResponse<Map<String, dynamic>>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/playlists/test'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.body.isEmpty) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Server trả về response rỗng (status: ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final responseData = jsonDecode(response.body);
      return ApiResponse<Map<String, dynamic>>(
        success: responseData['success'] ?? false,
        data: responseData['data'] ?? {},
        message: responseData['message'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }
}
