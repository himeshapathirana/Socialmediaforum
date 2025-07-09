class SubPollModel {
  final String? id;
  final String question;
  final List<String> options;
  final Author author;
  final bool allowMultipleAnswers;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int upvotes;
  final int downvotes;
  final int comments;
  final int totalVotes;
  final List<OptionStat> optionStats;
  final bool isClosed;
  final bool isPinned;
  final String status;

  SubPollModel({
    this.id,
    required this.question,
    required this.options,
    required this.author,
    required this.allowMultipleAnswers,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    required this.upvotes,
    required this.downvotes,
    required this.comments,
    required this.totalVotes,
    required this.optionStats,
    this.isClosed = false,
    this.isPinned = false,
    this.status = 'active',
  });

  factory SubPollModel.fromJson(Map<String, dynamic> json) {
    try {
      // Parse options (unchanged)
      final options =
          (json['options'] as List?)?.map((item) => item.toString()).toList() ??
              [];

      // Parse author (unchanged)
      final author = Author.fromJson(json['author'] ?? {});

      // Parse option stats (unchanged)
      final optionStats = (json['optionStats'] as List?)
              ?.map((item) => OptionStat.fromJson(item))
              .toList() ??
          [];

      return SubPollModel(
        id: json['_id']?.toString(),
        question: json['question']?.toString() ?? '',
        options: options,
        author: author,
        allowMultipleAnswers: json['allowMultipleAnswers'] == true,
        category: json['category']?.toString(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
        downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
        totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
        optionStats: optionStats,
        isClosed: json['isClosed'] == true,
        isPinned: json['isPinned'] == true,
        status: json['status']?.toString() ?? 'active',
      );
    } catch (e, stackTrace) {
      print('[SubPollModel] Error parsing JSON: $e');
      print(stackTrace);
      rethrow;
    }
  }

  // toJson remains unchanged
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'question': question,
      'options': options,
      'author': author.toJson(),
      'allowMultipleAnswers': allowMultipleAnswers,
      if (category != null) 'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'comments': comments,
      'totalVotes': totalVotes,
      'optionStats': optionStats.map((stat) => stat.toJson()).toList(),
      'isClosed': isClosed,
      'isPinned': isPinned,
      'status': status,
    };
  }
}

class Author {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? profileName;
  final String? institution;
  final String? email;
  final String? phoneNumber;
  final String? profilePic;
  final bool isAdmin;

  Author({
    required this.id,
    this.firstName,
    this.lastName,
    this.profileName,
    this.institution,
    this.email,
    this.phoneNumber,
    this.profilePic,
    required this.isAdmin,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['_id']?.toString() ?? '',
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      profileName: json['profileName']?.toString(),
      institution: json['institution']?.toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      profilePic: json['profilePic']?.toString(),
      isAdmin: json['isAdmin'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (profileName != null) 'profileName': profileName,
      if (institution != null) 'institution': institution,
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (profilePic != null) 'profilePic': profilePic,
      'isAdmin': isAdmin,
    };
  }
}

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
      option: json['option']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option': option,
      'count': count,
      'percentage': percentage,
    };
  }
}
