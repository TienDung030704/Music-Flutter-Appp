import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart' show ApiConfig, ApiResponse;

class DownloadService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // Get current user token
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Add a download
  static Future<ApiResponse<dynamic>> addDownload(
    String songType,
    String songId,
    String title,
    String artist,
    String imageUrl,
    String audioUrl,
  ) async {
    try {
      // Get auth token
      final token = await _getToken();
      if (token == null) {
        return ApiResponse<dynamic>(
          success: false,
          message: 'Vui lòng đăng nhập lại',
          data: null,
          statusCode: 401,
        );
      }

      // Validate inputs
      if (songType.isEmpty ||
          songId.isEmpty ||
          title.isEmpty ||
          artist.isEmpty) {
        return ApiResponse<dynamic>(
          success: false,
          message: 'Thiếu thông tin bắt buộc',
          data: null,
          statusCode: 400,
        );
      }

      // Validate audio URL
      if (audioUrl.isEmpty || !_isValidUrl(audioUrl)) {
        return ApiResponse<dynamic>(
          success: false,
          message: 'URL âm thanh không hợp lệ',
          data: null,
          statusCode: 400,
        );
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/downloads'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'song_type': songType,
              'song_id': songId,
              'song_title': title,
              'artist_name': artist,
              'artwork_url': imageUrl.isNotEmpty ? imageUrl : null,
              'download_url': audioUrl,
            }),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = json.decode(response.body);
      return ApiResponse<dynamic>(
        success: response.statusCode == 200 && responseData['success'] == true,
        data: responseData['data'],
        message: responseData['message'],
        error: responseData['error'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<dynamic>(
        success: false,
        message: 'Lỗi kết nối: $e',
        data: null,
        statusCode: 500,
      );
    }
  }

  // Helper method to validate URLs
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // Check if song is downloaded
  static Future<ApiResponse<dynamic>> checkDownload(
    String songType,
    String songId,
  ) async {
    try {
      // Get auth token
      final token = await _getToken();
      if (token == null) {
        return ApiResponse<dynamic>(
          success: false,
          message: 'Vui lòng đăng nhập lại',
          data: null,
          statusCode: 401,
        );
      }

      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/downloads/check?song_type=$songType&song_id=$songId',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = json.decode(response.body);
      return ApiResponse<dynamic>(
        success: response.statusCode == 200 && responseData['success'] == true,
        data: responseData['data'],
        message: responseData['message'],
        error: responseData['error'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<dynamic>(
        success: false,
        message: 'Network error: $e',
        data: null,
        statusCode: 500,
      );
    }
  }

  // Get user's downloads
  static Future<ApiResponse<dynamic>> getDownloads() async {
    try {
      // Get auth token
      final token = await _getToken();
      if (token == null) {
        return ApiResponse<dynamic>(
          success: false,
          message: 'Vui lòng đăng nhập lại',
          data: null,
          statusCode: 401,
        );
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/downloads'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = json.decode(response.body);
      return ApiResponse<dynamic>(
        success: response.statusCode == 200 && responseData['success'] == true,
        data: responseData['data'],
        message: responseData['message'],
        error: responseData['error'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<dynamic>(
        success: false,
        message: 'Network error: $e',
        data: null,
        statusCode: 500,
      );
    }
  }

  // Remove a download
  static Future<ApiResponse<dynamic>> removeDownload(int downloadId) async {
    try {
      // Get auth token
      final token = await _getToken();
      if (token == null) {
        return ApiResponse<dynamic>(
          success: false,
          message: 'Vui lòng đăng nhập lại',
          data: null,
          statusCode: 401,
        );
      }

      final response = await http
          .delete(
            Uri.parse('$_baseUrl/api/downloads/$downloadId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = json.decode(response.body);
      return ApiResponse<dynamic>(
        success: response.statusCode == 200 && responseData['success'] == true,
        data: responseData['data'],
        message: responseData['message'],
        error: responseData['error'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<dynamic>(
        success: false,
        message: 'Network error: $e',
        data: null,
        statusCode: 500,
      );
    }
  }
}
