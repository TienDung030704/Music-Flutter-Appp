class ApiConfig {
  static const String baseUrl =
      'http://10.0.2.2/Music-App-Flutter/Music-App-Flutter/backend';
  static const Duration timeoutDuration = Duration(seconds: 30);
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    required this.statusCode,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, int statusCode) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      data: json['data'],
      message: json['message'],
      error: json['error'],
      statusCode: statusCode,
    );
  }
}

class User {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final bool isVerified;
  final String? phone;
  final String? dateOfBirth;
  final String? gender;
  final String? lastLogin;
  final String createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isVerified,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.lastLogin,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      role: json['role'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isVerified: json['is_verified'] == 1 || json['is_verified'] == true,
      phone: json['phone'],
      dateOfBirth: json['date_of_birth'],
      gender: json['gender'],
      lastLogin: json['last_login'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'is_active': isActive,
      'is_verified': isVerified,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'last_login': lastLogin,
      'created_at': createdAt,
    };
  }
}

class LoginResponse {
  final User user;
  final String token;
  final String expiresAt;
  final String message;

  LoginResponse({
    required this.user,
    required this.token,
    required this.expiresAt,
    required this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      user: User.fromJson(json['user']),
      token: json['token'],
      expiresAt: json['expires_at'],
      message: json['message'],
    );
  }
}

class UserStats {
  final int favorites;
  final int playlists;
  final int history;

  UserStats({
    required this.favorites,
    required this.playlists,
    required this.history,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      favorites: json['favorites'] ?? 0,
      playlists: json['playlists'] ?? 0,
      history: json['history'] ?? 0,
    );
  }
}
