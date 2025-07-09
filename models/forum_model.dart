class ForumModel {
  final String? id;
  final String? title;
  final String? content;
  final int? upvotes;
  final int? downvotes;
  final bool isPinned;
  final bool isClosed;
  final List<String>? images;
  final String? status;
  final int? commentCount;
  final Map<String, dynamic>? author;
  final DateTime? createdAt;
  final bool? isBookmarked; // Add this field for bookmarking status

  ForumModel({
    this.id,
    this.title,
    this.content,
    this.upvotes,
    this.downvotes,
    bool? isPinned,
    bool? isClosed,
    this.images,
    this.status,
    this.commentCount,
    this.author,
    String?
        imageUrl, // This parameter seems unused, consider removing if not needed.
    this.createdAt,
    this.isBookmarked, // Initialize in constructor
  })  : isPinned = isPinned ?? false,
        isClosed = isClosed ?? false;

  factory ForumModel.fromJson(Map<String, dynamic> json) {
    print("Processing forum post: ${json['_id']}");

    final commentCount = json['commentCount'];
    final int parsedCommentCount = commentCount != null
        ? (commentCount is int
            ? commentCount
            : int.tryParse(commentCount.toString()) ?? 0)
        : 0;

    final authorData = json['author'];
    Map<String, dynamic>? authorMap;

    if (authorData is Map<String, dynamic>) {
      authorMap = authorData;
    } else if (authorData is String) {
      authorMap = {
        '_id': authorData,
        'firstName': '',
        'lastName': '',
        'profilePic': [],
      };
    }

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(json['createdAt']);
      } catch (e) {
        print("Error parsing date: ${json['createdAt']}");
      }
    }

    return ForumModel(
      id: json['_id'],
      title: json["title"],
      content: json['content'],
      upvotes: json['upvotes'],
      downvotes: json['downvotes'],
      isPinned: json['isPinned'] ?? false,
      isClosed: json['isClosed'] ?? false,
      images:
          (json["images"] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      status: json['status'],
      commentCount: parsedCommentCount,
      author: authorMap,
      createdAt: createdAt,
      isBookmarked:
          json['isBookmarked'], // Ensure this is parsed if it exists in API
    );
  }

  get category => null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'isPinned': isPinned,
      'isClosed': isClosed,
      'images': images,
      'status': status,
      'commentCount': commentCount,
      'author': author,
      'createdAt': createdAt?.toIso8601String(),
      'isBookmarked': isBookmarked,
    };
  }

  /// Creates a new [ForumModel] instance with the specified changes.
  ForumModel copyWith({
    String? id,
    String? title,
    String? content,
    int? upvotes,
    int? downvotes,
    bool? isPinned,
    bool? isClosed,
    List<String>? images,
    String? status,
    int? commentCount,
    Map<String, dynamic>? author,
    DateTime? createdAt,
    bool? isBookmarked, // Add this parameter to copyWith
  }) {
    return ForumModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      isPinned: isPinned ?? this.isPinned,
      isClosed: isClosed ?? this.isClosed,
      images: images ?? this.images,
      status: status ?? this.status,
      commentCount: commentCount ?? this.commentCount,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      isBookmarked: isBookmarked ?? this.isBookmarked, // Assign the new value
    );
  }
}
