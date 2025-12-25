class Comment {
  final int id;
  final int userId;
  final String songType;
  final String songId;
  final String songTitle;
  final String artistName;
  final String commentText;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String fullName;
  final String? avatar;
  final String? email;

  Comment({
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
    this.email,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: int.parse(json['id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      songType: json['song_type'].toString(),
      songId: json['song_id'].toString(),
      songTitle: json['song_title'].toString(),
      artistName: json['artist_name'].toString(),
      commentText: json['comment_text'].toString(),
      isActive: json['is_active'] == '1' || json['is_active'] == true,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
      fullName: json['full_name'].toString(),
      avatar: json['avatar'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'song_type': songType,
      'song_id': songId,
      'song_title': songTitle,
      'artist_name': artistName,
      'comment_text': commentText,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'full_name': fullName,
      'avatar': avatar,
      'email': email,
    };
  }

  // Helper method to format relative time
  String getRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  // Check if current user can edit this comment
  bool canEdit(int? currentUserId) {
    return currentUserId == userId;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CommentsPagination {
  final List<Comment> comments;
  final int currentPage;
  final int totalPages;
  final int totalComments;
  final int perPage;

  CommentsPagination({
    required this.comments,
    required this.currentPage,
    required this.totalPages,
    required this.totalComments,
    required this.perPage,
  });

  factory CommentsPagination.fromJson(Map<String, dynamic> json) {
    return CommentsPagination(
      comments: (json['comments'] as List)
          .map((comment) => Comment.fromJson(comment))
          .toList(),
      currentPage: int.parse(json['pagination']['current_page'].toString()),
      totalPages: int.parse(json['pagination']['total_pages'].toString()),
      totalComments: int.parse(json['pagination']['total_comments'].toString()),
      perPage: int.parse(json['pagination']['per_page'].toString()),
    );
  }

  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
}

class CommentStats {
  final int totalComments;
  final int commentsToday;
  final int commentsThisWeek;
  final List<TopCommentedSong> topCommentedSongs;

  CommentStats({
    required this.totalComments,
    required this.commentsToday,
    required this.commentsThisWeek,
    required this.topCommentedSongs,
  });

  factory CommentStats.fromJson(Map<String, dynamic> json) {
    return CommentStats(
      totalComments: int.parse(json['total_comments'].toString()),
      commentsToday: int.parse(json['comments_today'].toString()),
      commentsThisWeek: int.parse(json['comments_this_week'].toString()),
      topCommentedSongs: (json['top_commented_songs'] as List)
          .map((song) => TopCommentedSong.fromJson(song))
          .toList(),
    );
  }
}

class TopCommentedSong {
  final String songTitle;
  final String artistName;
  final String songType;
  final String songId;
  final int commentCount;

  TopCommentedSong({
    required this.songTitle,
    required this.artistName,
    required this.songType,
    required this.songId,
    required this.commentCount,
  });

  factory TopCommentedSong.fromJson(Map<String, dynamic> json) {
    return TopCommentedSong(
      songTitle: json['song_title'].toString(),
      artistName: json['artist_name'].toString(),
      songType: json['song_type'].toString(),
      songId: json['song_id'].toString(),
      commentCount: int.parse(json['comment_count'].toString()),
    );
  }
}

class AdminCommentsPagination {
  final List<AdminComment> comments;
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
              ?.map((comment) => AdminComment.fromJson(comment))
              .toList() ??
          [],
      currentPage: int.parse(json['current_page'].toString()),
      totalPages: int.parse(json['total_pages'].toString()),
      totalComments: int.parse(json['total_comments'].toString()),
      perPage: int.parse(json['per_page'].toString()),
    );
  }
}

class AdminComment {
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
  final String userFullName;
  final String? userAvatar;

  AdminComment({
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
    required this.userFullName,
    this.userAvatar,
  });

  // Convenient getters for backward compatibility
  String get fullName => userFullName;
  String? get avatar => userAvatar;

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

  factory AdminComment.fromJson(Map<String, dynamic> json) {
    return AdminComment(
      id: int.parse(json['id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      songType: json['song_type'].toString(),
      songId: json['song_id'].toString(),
      songTitle: json['song_title'].toString(),
      artistName: json['artist_name'].toString(),
      commentText: json['comment_text'].toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at'].toString(),
      updatedAt: json['updated_at'].toString(),
      userFullName: json['full_name'].toString(),
      userAvatar: json['avatar']?.toString(),
    );
  }
}
