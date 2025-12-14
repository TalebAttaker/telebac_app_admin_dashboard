/// Live Reaction Model
/// Represents a reaction in a live stream

class LiveReaction {
  final String id;
  final String streamId;
  final String userId;
  final String reactionType; // like, love, clap, fire
  final DateTime createdAt;

  LiveReaction({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.reactionType,
    required this.createdAt,
  });

  factory LiveReaction.fromJson(Map<String, dynamic> json) {
    return LiveReaction(
      id: json['id'] as String,
      streamId: json['stream_id'] as String,
      userId: json['user_id'] as String,
      reactionType: json['reaction_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stream_id': streamId,
      'user_id': userId,
      'reaction_type': reactionType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper getter for emoji
  String get emoji {
    switch (reactionType) {
      case 'like':
        return '👍';
      case 'love':
        return '❤️';
      case 'clap':
        return '👏';
      case 'fire':
        return '🔥';
      default:
        return '👍';
    }
  }

  // Helper method to get reaction name
  String getName(String locale) {
    if (locale == 'ar') {
      switch (reactionType) {
        case 'like':
          return 'إعجاب';
        case 'love':
          return 'حب';
        case 'clap':
          return 'تصفيق';
        case 'fire':
          return 'نار';
        default:
          return reactionType;
      }
    } else {
      switch (reactionType) {
        case 'like':
          return 'J\'aime';
        case 'love':
          return 'Amour';
        case 'clap':
          return 'Applaudissement';
        case 'fire':
          return 'Feu';
        default:
          return reactionType;
      }
    }
  }
}

/// Reaction stats for a live stream
class LiveReactionStats {
  final Map<String, int> counts;

  LiveReactionStats({required this.counts});

  int get totalReactions {
    return counts.values.fold(0, (sum, count) => sum + count);
  }

  int getCount(String reactionType) {
    return counts[reactionType] ?? 0;
  }

  factory LiveReactionStats.fromJson(Map<String, dynamic> json) {
    return LiveReactionStats(
      counts: Map<String, int>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return counts;
  }
}
