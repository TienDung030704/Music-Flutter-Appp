import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/song.dart' hide ApiResponse;
import '../models/api_response.dart';
import '../models/user_model.dart' show ApiConfig;

class AdminService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Thêm bài hát mới với URL
  static Future<ApiResponse<Song>> addSongWithUrl({
    required String title,
    required String artist,
    required String thumbnail,
    required String category,
    required String audioUrl,
    int? duration,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/admin/songs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'artist': artist,
              'thumbnail': thumbnail,
              'category': category,
              'streamUrl': audioUrl,
              'duration': duration ?? 180, // default 3 minutes if not provided
            }),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['success'] == true) {
          return ApiResponse<Song>(
            success: true,
            data: Song.fromJson(responseData['data']),
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Song>(
        success: false,
        error: responseData['error'] ?? 'Lỗi thêm bài hát',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Song>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Lấy danh sách bài hát admin theo category
  static Future<ApiResponse<List<Song>>> getAdminSongs({
    String? category,
  }) async {
    try {
      String url = '$baseUrl/admin/songs';
      if (category != null) {
        url += '?category=${Uri.encodeComponent(category)}';
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          final List<dynamic> songsJson = responseData['data'] ?? [];
          print(
            '[AdminService] DEBUG: Parsed ${songsJson.length} songs from response',
          );

          final List<Song> songs = songsJson
              .map((json) => Song.fromJson(json))
              .toList();

          print(
            '[AdminService] DEBUG: Successfully converted ${songs.length} songs',
          );
          return ApiResponse<List<Song>>(
            success: true,
            data: songs,
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<List<Song>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi lấy danh sách bài hát',
        statusCode: response.statusCode,
        data: [],
      );
    } catch (e) {
      return ApiResponse<List<Song>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
        data: [],
      );
    }
  }

  // Thêm bài hát mới
  static Future<ApiResponse<Song>> createSong({
    required String title,
    required String artist,
    required String thumbnail,
    required String category,
    String? streamUrl,
    int? duration,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/admin/songs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': title,
              'artist': artist,
              'thumbnail': thumbnail,
              'category': category,
              'streamUrl': streamUrl,
              'duration': duration,
            }),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['success'] == true) {
          return ApiResponse<Song>(
            success: true,
            data: Song.fromJson(responseData['data']),
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Song>(
        success: false,
        error: responseData['error'] ?? 'Lỗi thêm bài hát',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Song>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Cập nhật bài hát
  static Future<ApiResponse<Song>> updateSong({
    required String songId,
    required String title,
    required String artist,
    required String thumbnail,
    required String category,
    String? streamUrl,
    int? duration,
  }) async {
    try {
      // Only send non-empty values to preserve existing URLs
      Map<String, dynamic> requestBody = {
        'title': title,
        'artist': artist,
        'category': category,
      };

      // Only include if not empty
      if (thumbnail.isNotEmpty) {
        requestBody['thumbnail'] = thumbnail;
      }
      if (streamUrl != null && streamUrl.isNotEmpty) {
        requestBody['streamUrl'] = streamUrl;
      }
      if (duration != null) {
        requestBody['duration'] = duration;
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/admin/songs/$songId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<Song>(
            success: true,
            data: Song.fromJson(responseData['data']),
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Song>(
        success: false,
        error: responseData['error'] ?? 'Lỗi cập nhật bài hát',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Song>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Xóa bài hát
  static Future<ApiResponse<void>> deleteSong(String songId) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/admin/songs/$songId'))
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<void>(
            success: true,
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<void>(
        success: false,
        error: responseData['error'] ?? 'Lỗi xóa bài hát',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Lấy danh sách bài hát theo thể loại
  static Future<ApiResponse<List<Song>>> getSongsByCategory(
    String category,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/admin/songs?category=${Uri.encodeComponent(category)}',
            ),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          final List<dynamic> songsJson = responseData['data'];
          final List<Song> songs = songsJson
              .map((json) => Song.fromJson(json))
              .toList();

          return ApiResponse<List<Song>>(
            success: true,
            data: songs,
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<List<Song>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi tải danh sách bài hát',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<List<Song>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Lấy thống kê admin
  static Future<ApiResponse<Map<String, dynamic>>> getAdminStats() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/admin/stats'))
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            data: responseData['data'],
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi tải thống kê',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Upload file nhạc với thông tin bài hát
  static Future<ApiResponse<Song>> uploadSong({
    required String title,
    required String artist,
    required String thumbnail,
    required String category,
    required File audioFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/admin/upload'),
      );

      // Add form fields
      request.fields['title'] = title;
      request.fields['artist'] = artist;
      request.fields['thumbnail'] = thumbnail;
      request.fields['category'] = category;

      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['success'] == true) {
          return ApiResponse<Song>(
            success: true,
            data: Song.fromJson(responseData['data']),
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Song>(
        success: false,
        error: responseData['error'] ?? 'Lỗi upload bài hát',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Song>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Đồng bộ dữ liệu từ iTunes API
  static Future<ApiResponse<Map<String, dynamic>>> syncFromItunes() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/admin/sync'))
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            data: responseData['data'],
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi đồng bộ',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // ==================== USER MANAGEMENT METHODS ====================

  // Lấy danh sách người dùng
  static Future<ApiResponse<Map<String, dynamic>>> getUsers({
    String? search,
    String? role,
    int? page,
    int? limit,
  }) async {
    try {
      String url = '$baseUrl/admin/users';
      List<String> params = [];

      if (search != null && search.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search)}');
      }
      if (role != null && role.isNotEmpty) {
        params.add('role=${Uri.encodeComponent(role)}');
      }
      if (page != null) {
        params.add('page=$page');
      }
      if (limit != null) {
        params.add('limit=$limit');
      }

      if (params.isNotEmpty) {
        url += '?' + params.join('&');
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            data: responseData['data'],
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi lấy danh sách người dùng',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Tạo người dùng mới
  static Future<ApiResponse<Map<String, dynamic>>> createUser({
    required String fullName,
    required String email,
    required String password,
    String? role,
    String? avatar,
    String? phone,
    String? dateOfBirth,
    String? gender,
    bool? isActive,
    bool? isVerified,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/admin/users'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullName,
              'email': email,
              'password': password,
              'role': role ?? 'user',
              'avatar': avatar,
              'phone': phone,
              'dateOfBirth': dateOfBirth,
              'gender': gender,
              'isActive': isActive ?? true,
              'isVerified': isVerified ?? false,
            }),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['success'] == true) {
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            data: responseData['data'],
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi tạo người dùng',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Cập nhật người dùng
  static Future<ApiResponse<Map<String, dynamic>>> updateUser({
    required int userId,
    required String fullName,
    required String email,
    String? password,
    String? role,
    String? avatar,
    String? phone,
    String? dateOfBirth,
    String? gender,
    bool? isActive,
    bool? isVerified,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'fullName': fullName,
        'email': email,
        'role': role ?? 'user',
        'avatar': avatar,
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'isActive': isActive ?? true,
        'isVerified': isVerified ?? false,
      };

      // Chỉ thêm password nếu có
      if (password != null && password.isNotEmpty) {
        requestBody['password'] = password;
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/admin/users/$userId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            data: responseData['data'],
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi cập nhật người dùng',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Xóa người dùng
  static Future<ApiResponse<String>> deleteUser(int userId) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/admin/users/$userId'))
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<String>(
            success: true,
            data: responseData['data']['message'] ?? 'Đã xóa người dùng',
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<String>(
        success: false,
        error: responseData['error'] ?? 'Lỗi xóa người dùng',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Thay đổi trạng thái người dùng
  static Future<ApiResponse<Map<String, dynamic>>> toggleUserStatus(
    int userId,
  ) async {
    try {
      final response = await http
          .put(Uri.parse('$baseUrl/admin/users/$userId/toggle-status'))
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            data: responseData['data'],
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi thay đổi trạng thái',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  // Lấy thống kê người dùng
  static Future<ApiResponse<Map<String, dynamic>>> getUserStats() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/admin/user-stats'))
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            data: responseData['data'],
            statusCode: response.statusCode,
          );
        }
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: responseData['error'] ?? 'Lỗi lấy thống kê',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }
}
