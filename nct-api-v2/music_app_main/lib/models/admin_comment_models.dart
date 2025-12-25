class AdminCommentItem {
  final int id;
  final int userId;
  final String songType;
  final String songId;
  final String songTitle;
  final String artistName;
  final String commentText;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String fullName;
  final String? avatar;
  final String email;

  AdminCommentItem({
    required this.id,
    required this.userId,
    required this.songType,
    required this.songId,
    required this.songTitle,
    required this.artistName,
    required this.commentText,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.fullName,
    this.avatar,
    required this.email,
  });

  factory AdminCommentItem.fromJson(Map<String, dynamic> json) {
    return AdminCommentItem(
      id: json['id'] != null ? int.parse(json['id'].toString()) : 0,
      userId: json['user_id'] != null
          ? int.parse(json['user_id'].toString())
          : 0,
      songType: json['song_type']?.toString() ?? '',
      songId: json['song_id']?.toString() ?? '',
      songTitle: json['song_title']?.toString() ?? '',
      artistName: json['artist_name']?.toString() ?? '',
      commentText: json['comment_text']?.toString() ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      email: json['email']?.toString() ?? '',
    );
  }

  String getRelativeTime() {
    try {
      final DateTime commentDateTime = DateTime.parse(createdAt);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(commentDateTime);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds} giây trước';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} phút trước';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} giờ trước';
      } else {
        return '${difference.inDays} ngày trước';
      }
    } catch (e) {
      return createdAt;
    }
  }
}

class AdminCommentsPagination {
  final List<AdminCommentItem> comments;
  final int currentPage;
  final int totalPages;
  final int totalComments;
  final int perPage;

  AdminCommentsPagination({
    required this.comments,
    required this.currentPage,
    required this.totalPages,
    required this.totalComments,
    required this.perPage,
  });

  bool get hasNextPage => currentPage < totalPages;
  bool get hasPrevPage => currentPage > 1;

  factory AdminCommentsPagination.fromJson(Map<String, dynamic> json) {
    return AdminCommentsPagination(
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((comment) => AdminCommentItem.fromJson(comment))
              .toList() ??
          [],
      currentPage: json['current_page'] != null
          ? int.parse(json['current_page'].toString())
          : 1,
      totalPages: json['total_pages'] != null
          ? int.parse(json['total_pages'].toString())
          : 0,
      totalComments: json['total_comments'] != null
          ? int.parse(json['total_comments'].toString())
          : 0,
      perPage: json['per_page'] != null
          ? int.parse(json['per_page'].toString())
          : 20,
    );
  }
}

class AdminCommentStats {
  final int totalComments;
  final int activeComments;
  final int inactiveComments;
  final int totalUsers;

  AdminCommentStats({
    required this.totalComments,
    required this.activeComments,
    required this.inactiveComments,
    required this.totalUsers,
  });

  factory AdminCommentStats.fromJson(Map<String, dynamic> json) {
    return AdminCommentStats(
      totalComments: int.parse(json['total_comments']?.toString() ?? '0'),
      activeComments: int.parse(json['active_comments']?.toString() ?? '0'),
      inactiveComments: int.parse(json['inactive_comments']?.toString() ?? '0'),
      totalUsers: int.parse(json['total_users']?.toString() ?? '0'),
    );
  }
}
