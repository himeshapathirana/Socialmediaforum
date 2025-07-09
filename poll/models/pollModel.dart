class OptionStat {
  final String option;
  final int count;
  final double percentage;

  OptionStat({
    required this.option,
    required this.count,
    required this.percentage,
  });

  factory OptionStat.fromJson(Map<String, dynamic> json) {
    return OptionStat(
      option: json['option'] as String,
      count: json['count'] as int,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class Poll {
  final String id;
  final String question;
  final List<String> options;
  final Map<String, dynamic> author;
  final bool allowMultipleAnswers;
  final int upvotes;
  final int downvotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalVotes;
  final List<OptionStat> optionStats;
  final int comments; // Renamed from 'comments' for consistency with ForumModel
  final String? type; // Added to match the structure in your feed
  final List<int>?
      userSelectedOptions; // To track user's votes on the client side

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.author,
    required this.allowMultipleAnswers,
    required this.upvotes,
    required this.downvotes,
    required this.createdAt,
    required this.updatedAt,
    required this.totalVotes,
    required this.optionStats,
    required this.comments, // Updated name here
    this.type, // Added to constructor
    this.userSelectedOptions, // Added to constructor
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    // Handle author data if it's a map or a string ID
    Map<String, dynamic> authorData;
    if (json['author'] is Map<String, dynamic>) {
      authorData = json['author'] as Map<String, dynamic>;
    } else {
      // If author is just an ID string or null, create a minimal map
      authorData = {'_id': json['author'] as String? ?? ''};
    }

    // Parse createdAt and updatedAt with null checks
    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(json['createdAt'] as String);
    } catch (e) {
      print("Error parsing Poll createdAt: ${json['createdAt']} - $e");
    }

    DateTime? updatedAt;
    try {
      updatedAt = DateTime.parse(json['updatedAt'] as String);
    } catch (e) {
      print("Error parsing Poll updatedAt: ${json['updatedAt']} - $e");
    }

    return Poll(
      id: json['_id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] ?? []),
      author: authorData,
      allowMultipleAnswers: json['allowMultipleAnswers'] as bool? ?? false,
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      createdAt:
          createdAt ?? DateTime.now(), // Provide a fallback if parsing fails
      updatedAt:
          updatedAt ?? DateTime.now(), // Provide a fallback if parsing fails
      totalVotes: json['totalVotes'] as int? ?? 0,
      optionStats: (json['optionStats'] as List<dynamic>?)
              ?.map((e) => OptionStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      comments: json['commentCount'] as int? ??
          0, // Used commentCount for consistency
      type: json['type'] as String?,
      userSelectedOptions: (json['userSelectedOptions'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  get authorName => null;

  get authorProfileImage => null;

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'question': question,
      'options': options,
      'author': author,
      'allowMultipleAnswers': allowMultipleAnswers,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'totalVotes': totalVotes,
      'optionStats': optionStats
          .map((stat) => {
                'option': stat.option,
                'count': stat.count,
                'percentage': stat.percentage
              })
          .toList(),
      'commentCount': comments, // Consistent name
      'type': type,
      'userSelectedOptions': userSelectedOptions,
    };
  }

  /// Creates a new [Poll] instance with the specified changes.
  Poll copyWith({
    String? id,
    String? question,
    List<String>? options,
    Map<String, dynamic>? author,
    bool? allowMultipleAnswers,
    int? upvotes,
    int? downvotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalVotes,
    List<OptionStat>? optionStats,
    int? commentCount, // Updated name here
    String? type,
    List<int>? userSelectedOptions,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      author: author ?? this.author,
      allowMultipleAnswers: allowMultipleAnswers ?? this.allowMultipleAnswers,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalVotes: totalVotes ?? this.totalVotes,
      optionStats: optionStats ?? this.optionStats,
      comments: commentCount ?? this.comments, // Updated name here
      type: type ?? this.type,
      userSelectedOptions: userSelectedOptions ?? this.userSelectedOptions,
    );
  }
}
