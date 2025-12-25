class NotificationModel {
  final int id;
  final int? senderId;
  final int receiverId;
  final String receiverType;
  final String notificationType;
  final String title;
  final String message;
  final Map<String, dynamic>? relatedData;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? senderName;
  final String? senderAvatar;

  NotificationModel({
    required this.id,
    this.senderId,
    required this.receiverId,
    required this.receiverType,
    required this.notificationType,
    required this.title,
    required this.message,
    this.relatedData,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.senderName,
    this.senderAvatar,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      receiverType: json['receiver_type'] ?? 'user',
      notificationType: json['notification_type'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      relatedData: json['related_data'] is Map
          ? Map<String, dynamic>.from(json['related_data'])
          : null,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'receiver_type': receiverType,
      'notification_type': notificationType,
      'title': title,
      'message': message,
      'related_data': relatedData,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
    };
  }

  // Get notification icon based on type
  String getIconData() {
    switch (notificationType) {
      case 'comment':
        return '💬';
      case 'listening':
        return '🎵';
      case 'download':
        return '📥';
      case 'new_song':
        return '🎶';
      case 'new_user':
        return '👤';
      case 'system':
        return '⚙️';
      default:
        return '🔔';
    }
  }

  // Get notification color based on type
  String getTypeColor() {
    switch (notificationType) {
      case 'comment':
        return '0xFF2196F3'; // Blue
      case 'listening':
        return '0xFF4CAF50'; // Green
      case 'download':
        return '0xFFFF9800'; // Orange
      case 'new_song':
        return '0xFF9C27B0'; // Purple
      case 'new_user':
        return '0xFF00BCD4'; // Cyan
      case 'system':
        return '0xFF607D8B'; // Blue Grey
      default:
        return '0xFF757575'; // Grey
    }
  }

  // Get human readable time
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} tuần trước';
    } else {
      return '${(difference.inDays / 30).floor()} tháng trước';
    }
  }

  // Check if notification has song data
  bool hasSongData() {
    return relatedData != null &&
        (relatedData!.containsKey('song_id') ||
            relatedData!.containsKey('song_title'));
  }

  // Get song title from related data
  String? getSongTitle() {
    return relatedData?['song_title'];
  }

  // Get artist name from related data
  String? getArtistName() {
    return relatedData?['artist_name'];
  }

  // Get song ID from related data
  String? getSongId() {
    return relatedData?['song_id']?.toString();
  }
}

class NotificationPagination {
  final List<NotificationModel> notifications;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int perPage;

  NotificationPagination({
    required this.notifications,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.perPage,
  });

  factory NotificationPagination.fromJson(Map<String, dynamic> json) {
    final notificationsList = json['notifications'] as List? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return NotificationPagination(
      notifications: notificationsList
          .map((item) => NotificationModel.fromJson(item))
          .toList(),
      currentPage: pagination['current_page'] ?? 1,
      totalPages: pagination['total_pages'] ?? 1,
      totalItems: pagination['total_items'] ?? 0,
      perPage: pagination['per_page'] ?? 20,
    );
  }

  bool get hasMorePages => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
}
