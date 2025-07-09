import 'package:cloud_firestore/cloud_firestore.dart';

enum CommentTargetType {
  forumPost('ForumPost'),
  forumPoll('ForumPoll'),
  subForumPost('SubForumPost'),
  subForumPoll('SubForumPoll');

  const CommentTargetType(this.value);
  final String value;
}

class UniversalComment {
  final String id;
  final String content;
  final String author;
  final String userId;
  final Timestamp timestamp;
  final String? profileImageUrl;
  final int upvotes;
  final int downvotes;
  final String targetId;
  final CommentTargetType targetType;
  final bool isReply;
  final String? parentCommentId;
  final List<UniversalComment>? replies;
  final bool isUpvoted;
  final bool isDownvoted;

  UniversalComment({
    required this.id,
    required this.content,
    required this.author,
    required this.userId,
    required this.timestamp,
    this.profileImageUrl,
    required this.upvotes,
    required this.downvotes,
    required this.targetId,
    required this.targetType,
    required this.isReply,
    this.parentCommentId,
    this.replies,
    this.isUpvoted = false,
    this.isDownvoted = false,
  });

  factory UniversalComment.fromJson(
      Map<String, dynamic> json, CommentTargetType targetType) {
    String authorName = 'Anonymous';
    String authorId = '';
    String? profilePic;

    if (json['author'] is String) {
      authorId = json['author'] as String;
      authorName = 'User';
    } else if (json['author'] is Map<String, dynamic>) {
      final authorData = json['author'] as Map<String, dynamic>;
      final firstName = authorData['firstName'] ?? '';
      final lastName = authorData['lastName'] ?? '';
      final profileName = authorData['profileName'] ?? '';
      authorName =
          profileName.isNotEmpty ? profileName : '$firstName $lastName'.trim();
      authorId = authorData['_id'] ?? '';
      profilePic = (authorData['profilePic'] as List?)?.isNotEmpty == true
          ? authorData['profilePic'][0]
          : null;
    }

    return UniversalComment(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      author: authorName,
      userId: authorId,
      timestamp: json['createdAt'] != null
          ? Timestamp.fromDate(DateTime.parse(json['createdAt']))
          : Timestamp.now(),
      profileImageUrl: profilePic,
      upvotes: json['upvotes'] ?? 0,
      downvotes: json['downvotes'] ?? 0,
      targetId: json['targetId'] ?? '',
      targetType: targetType,
      isReply: json['parentComment'] != null,
      parentCommentId: json['parentComment'],
      replies: [],
      isUpvoted: json['isUpvoted'] ?? false,
      isDownvoted: json['isDownvoted'] ?? false,
    );
  }

  UniversalComment copyWith({
    List<UniversalComment>? replies,
    int? upvotes,
    int? downvotes,
    bool? isUpvoted,
    bool? isDownvoted,
  }) {
    return UniversalComment(
      id: id,
      content: content,
      author: author,
      userId: userId,
      timestamp: timestamp,
      profileImageUrl: profileImageUrl,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      targetId: targetId,
      targetType: targetType,
      isReply: isReply,
      parentCommentId: parentCommentId,
      replies: replies ?? this.replies,
      isUpvoted: isUpvoted ?? this.isUpvoted,
      isDownvoted: isDownvoted ?? this.isDownvoted,
    );
  }
}

class TaggedUserPosition {
  final String userId;
  final String name;
  final int startPos;
  final int endPos;

  TaggedUserPosition({
    required this.userId,
    required this.name,
    required this.startPos,
    required this.endPos,
  });
}
