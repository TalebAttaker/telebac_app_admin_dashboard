/// Live Comment Model
/// Represents a comment in a live stream

class LiveComment {
  final String id;
  final String streamId;
  final String userId;
  final String message;
  final bool isPinned;
  final bool isDeleted;
  final DateTime createdAt;

  // Optional user profile data (from join)
  final Map<String, dynamic>? userProfile;

  LiveComment({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.message,
    this.isPinned = false,
    this.isDeleted = false,
    required this.createdAt,
    this.userProfile,
  });

  factory LiveComment.fromJson(Map<String, dynamic> json) {
    return LiveComment(
      id: json['id'] as String,
      streamId: json['stream_id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String,
      isPinned: json['is_pinned'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      userProfile: json['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stream_id': streamId,
      'user_id': userId,
      'message': message,
      'is_pinned': isPinned,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get userName {
    return userProfile?['full_name'] as String? ?? 'Unknown User';
  }

  String? get userAvatar {
    return userProfile?['avatar_url'] as String?;
  }

  LiveComment copyWith({
    String? id,
    String? streamId,
    String? userId,
    String? message,
    bool? isPinned,
    bool? isDeleted,
    DateTime? createdAt,
    Map<String, dynamic>? userProfile,
  }) {
    return LiveComment(
      id: id ?? this.id,
      streamId: streamId ?? this.streamId,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      userProfile: userProfile ?? this.userProfile,
    );
  }
}
