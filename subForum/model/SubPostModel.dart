import 'package:myunivrs/features/forum/services/vote_tracking_service.dart';
import 'dart:convert';

class SubPostModel {
  final String? id;
  final String title;
  final String content;
  final Author author;
  final List<String> images;
  final int upvotes;
  final int downvotes;
  final VoteType userVote;
  final bool isPinned;
  final bool isClosed;
  final String status;
  final String category;
  final DateTime createdAt;

  final dynamic commentCount;

  SubPostModel({
    this.id,
    required this.title,
    required this.content,
    required this.author,
    this.images = const [],
    this.upvotes = 0,
    this.downvotes = 0,
    this.userVote = VoteType.none,
    this.isPinned = false,
    this.isClosed = false,
    this.status = 'active',
    required this.category,
    required this.createdAt,
    this.commentCount = 0,
  });

  factory SubPostModel.fromJson(Map<String, dynamic> json) {
    // Handle author field - it might be just an ID string or a full object
    late Author author;
    if (json['author'] is String) {
      author = Author(id: json['author']);
    } else if (json['author'] is Map<String, dynamic>) {
      author = Author.fromJson(json['author'] as Map<String, dynamic>);
    } else {
      author = Author(id: ''); // fallback, though this shouldn't happen
    }

    return SubPostModel(
      id: json['_id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      author: author,
      images: List<String>.from(json['images'] ?? []),
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
      userVote: _parseVoteType(json['userVote']),
      isPinned: json['isPinned'] as bool? ?? false,
      isClosed: json['isClosed'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      category: json['category'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      commentCount: json['commentCount'] ?? 0,
    );
  }

  static VoteType _parseVoteType(dynamic vote) {
    if (vote == 'upvote') return VoteType.upvote;
    if (vote == 'downvote') return VoteType.downvote;
    return VoteType.none;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'title': title,
      'content': content,
      'author': author.toJson(),
      'images': images,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'userVote': _convertVoteTypeToString(userVote),
      'isPinned': isPinned,
      'isClosed': isClosed,
      'status': status,
      'category': category,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      'commentCount': commentCount,
    };
  }

  static String _convertVoteTypeToString(VoteType vote) {
    switch (vote) {
      case VoteType.upvote:
        return 'upvote';
      case VoteType.downvote:
        return 'downvote';
      case VoteType.none:
      default:
        return 'none';
    }
  }

  int get commentCountValue {
    if (commentCount is int) return commentCount as int;
    if (commentCount is Map<String, dynamic>) {
      return (commentCount['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  @override
  String toString() => jsonEncode(toJson());
}

class Author {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? profileName;
  final String? institution;
  final String? profilePic;
  final String? email;

  Author({
    required this.id,
    this.firstName,
    this.lastName,
    this.profileName,
    this.institution,
    this.profilePic,
    this.email,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    String? profilePic;
    if (json['profilePic'] is String) {
      profilePic = json['profilePic'] as String?;
    } else if (json['profilePic'] is List &&
        (json['profilePic'] as List).isNotEmpty) {
      profilePic = (json['profilePic'] as List).first as String?;
    } else {
      profilePic = null; // Handle empty list or invalid data
    }
    return Author(
      id: json['_id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      profileName: json['profileName'] as String?,
      institution: json['institution'] as String?,
      profilePic: profilePic,
      email: json['email'] as String?,
    );
  }
  factory Author.fromId(String id) {
    return Author(id: id);
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (profileName != null) 'profileName': profileName,
      if (institution != null) 'institution': institution,
      if (profilePic != null) 'profilePic': profilePic,
      if (email != null) 'email': email,
    };
  }

  String get displayName {
    if (profileName != null && profileName!.isNotEmpty) return profileName!;
    if (firstName != null && firstName!.isNotEmpty) {
      return lastName != null && lastName!.isNotEmpty
          ? '$firstName $lastName'
          : firstName!;
    }
    return email?.split('@').first ?? 'Anonymous';
  }
}
