import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart' show ApiConfig;
import 'auth_service.dart';

class NotificationService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Get notifications with pagination
  static Future<ApiResponse<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          statusCode: 401,
          error: 'Cần đăng nhập để xem thông báo',
        );
      }

      final url = '$baseUrl/api/notifications';

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'page': page, 'limit': limit}),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      return ApiResponse(
        success: response.statusCode == 200 && responseData['success'] == true,
        statusCode: response.statusCode,
        data: responseData['success'] ? responseData['data'] : null,
        error: responseData['success']
            ? null
            : (responseData['message'] ??
                  responseData['error'] ??
                  'Lỗi không xác định'),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        statusCode: 500,
        error: 'Lỗi kết nối: $e',
      );
    }
  }

  // Get unread notifications count
  static Future<ApiResponse<int>> getUnreadCount() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          statusCode: 401,
          error: 'Cần đăng nhập',
        );
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      return ApiResponse(
        success: response.statusCode == 200 && responseData['success'] == true,
        statusCode: response.statusCode,
        data: responseData['success']
            ? responseData['data']['unread_count']
            : 0,
        error: responseData['success']
            ? null
            : (responseData['message'] ?? 'Lỗi không xác định'),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        statusCode: 500,
        error: 'Lỗi kết nối: $e',
      );
    }
  }

  // Mark notification as read
  static Future<ApiResponse<String>> markAsRead(int notificationId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          statusCode: 401,
          error: 'Cần đăng nhập',
        );
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'notification_id': notificationId}),
      );

      final responseData = jsonDecode(response.body);

      return ApiResponse(
        success: response.statusCode == 200 && responseData['success'] == true,
        statusCode: response.statusCode,
        data: responseData['success'] ? responseData['data']['message'] : null,
        error: responseData['success']
            ? null
            : (responseData['message'] ?? 'Lỗi không xác định'),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        statusCode: 500,
        error: 'Lỗi kết nối: $e',
      );
    }
  }

  // Mark all notifications as read
  static Future<ApiResponse<String>> markAllAsRead() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          statusCode: 401,
          error: 'Cần đăng nhập',
        );
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/mark-all-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      return ApiResponse(
        success: response.statusCode == 200 && responseData['success'] == true,
        statusCode: response.statusCode,
        data: responseData['success'] ? responseData['data']['message'] : null,
        error: responseData['success']
            ? null
            : (responseData['message'] ?? 'Lỗi không xác định'),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        statusCode: 500,
        error: 'Lỗi kết nối: $e',
      );
    }
  }
}

class ApiResponse<T> {
  final bool success;
  final int statusCode;
  final T? data;
  final String? error;

  ApiResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });
}
