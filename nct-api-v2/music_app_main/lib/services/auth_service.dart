import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  // Register
  static Future<ApiResponse<User>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': fullName,
              'email': email,
              'password': password,
            }),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201 && responseData['success']) {
        return ApiResponse<User>(
          success: true,
          data: User.fromJson(responseData['data']['user']),
          message: responseData['data']['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<User>(
          success: false,
          error: responseData['error'] ?? 'Đăng ký thất bại',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<User>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Login
  static Future<ApiResponse<LoginResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        final loginResponse = LoginResponse.fromJson(responseData['data']);

        // Save tokens and user data
        await _saveToken(
          responseData['data']['access_token'] ?? responseData['data']['token'],
        );
        if (responseData['data']['refresh_token'] != null) {
          await _saveRefreshToken(responseData['data']['refresh_token']);
        }
        await _saveUser(loginResponse.user);

        return ApiResponse<LoginResponse>(
          success: true,
          data: loginResponse,
          message: responseData['data']['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<LoginResponse>(
          success: false,
          error: responseData['error'] ?? 'Đăng nhập thất bại',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<LoginResponse>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Logout
  static Future<ApiResponse<void>> logout() async {
    try {
      final token = await getToken();

      if (token != null) {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/auth/logout'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(ApiConfig.timeoutDuration);

        final responseData = jsonDecode(response.body);

        if (response.statusCode == 200 && responseData['success']) {
          await _clearAuthData();
          return ApiResponse<void>(
            success: true,
            message: responseData['data']['message'],
            statusCode: response.statusCode,
          );
        }
      }

      // Clear local data even if API call fails
      await _clearAuthData();
      return ApiResponse<void>(
        success: true,
        message: 'Đăng xuất thành công',
        statusCode: 200,
      );
    } catch (e) {
      await _clearAuthData();
      return ApiResponse<void>(
        success: true,
        message: 'Đăng xuất thành công',
        statusCode: 200,
      );
    }
  }

  // Forgot Password
  static Future<ApiResponse<void>> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
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
          error: responseData['error'] ?? 'Gửi email thất bại',
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

  // Get Profile
  static Future<ApiResponse<Map<String, dynamic>>> getProfile() async {
    try {
      final token = await getToken();

      if (token == null) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        // Update saved user data
        await _saveUser(User.fromJson(responseData['data']['user']));

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: responseData['data'],
          statusCode: response.statusCode,
        );
      } else {
        if (response.statusCode == 401) {
          await _clearAuthData();
        }
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          error: responseData['error'] ?? 'Không thể lấy thông tin profile',
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

  // Update Profile
  static Future<ApiResponse<User>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await getToken();

      if (token == null) {
        return ApiResponse<User>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http
          .put(
            Uri.parse('$_baseUrl/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        final updatedUser = User.fromJson(responseData['data']['user']);
        await _saveUser(updatedUser);

        return ApiResponse<User>(
          success: true,
          data: updatedUser,
          message: responseData['data']['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<User>(
          success: false,
          error: responseData['error'] ?? 'Cập nhật thất bại',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<User>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Token management
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<void> _saveRefreshToken(String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  // User data management
  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // Get user profile from server (fresh data)
  static Future<ApiResponse<User>> getUserProfileFromServer() async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse<User>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      final response = await http
          .get(
            Uri.parse('$_baseUrl/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeoutDuration);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        final user = User.fromJson(responseData['data']['user']);
        await _saveUser(user); // Save to cache

        return ApiResponse<User>(
          success: true,
          data: user,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<User>(
          success: false,
          error: responseData['error'] ?? 'Không thể tải thông tin người dùng',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<User>(
        success: false,
        error: 'Lỗi kết nối: $e',
        statusCode: 500,
      );
    }
  }

  static Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Refresh access token
  static Future<ApiResponse<String>> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        return ApiResponse<String>(
          success: false,
          error: 'Không có refresh token',
          statusCode: 401,
        );
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/refresh-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        final newAccessToken = responseData['data']['access_token'];
        final newRefreshToken = responseData['data']['refresh_token'];

        // Save new tokens
        await _saveToken(newAccessToken);
        await _saveRefreshToken(newRefreshToken);

        return ApiResponse<String>(
          success: true,
          data: newAccessToken,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<String>(
          success: false,
          error: responseData['error'] ?? 'Không thể làm mới token',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        error: 'Lỗi kết nối: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Clear auth data
  static Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
  }

  // Change password
  static Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse<void>(
          success: false,
          error: 'Chưa đăng nhập',
          statusCode: 401,
        );
      }

      print('=== CHANGE PASSWORD DEBUG ===');
      print('URL: $_baseUrl/auth/change-password');
      print('Token: ${token.substring(0, 20)}...');
      print('Full token: $token');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      print('Headers: $headers');

      final body = jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      print('Body: $body');

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/change-password'),
        headers: headers,
        body: body,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Clear tokens since password changed (security)
        await _clearAuthData();

        return ApiResponse<void>(
          success: true,
          message: responseData['data']['message'] ?? 'Đổi mật khẩu thành công',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          error: responseData['error'] ?? 'Đổi mật khẩu thất bại',
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

  // Public method to clear tokens (for logout or authentication errors)
  static Future<void> clearTokens() async {
    await _clearAuthData();
  }
}
