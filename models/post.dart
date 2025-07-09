import 'package:myunivrs/features/forum/models/comment.dart';
import 'package:myunivrs/features/forum/models/forum_model.dart';

class Post {
  final String id;
  final String title;
  final String content;
  final String author;
  final String? authorProfileImageUrl;
  final String? imageUrl;
  final List<UniversalComment> comments;
  final int? upvotes;
  final int? downvotes;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    this.authorProfileImageUrl,
    this.imageUrl,
    this.comments = const [],
    this.upvotes = 0,
    this.downvotes = 0,
  });

  // Add a factory constructor to convert a ForumModel to a Post
  factory Post.fromForumModel(ForumModel forum) {
    String authorName = 'Anonymous';
    String? profileImageUrl;

    if (forum.author != null) {
      final firstName = forum.author!['firstName'] ?? '';
      final lastName = forum.author!['lastName'] ?? '';
      final profileName = forum.author!['profileName'];

      if (profileName != null && profileName.isNotEmpty) {
        authorName = profileName;
      } else if (firstName.isNotEmpty || lastName.isNotEmpty) {
        authorName = '$firstName $lastName'.trim();
      }

      final profilePics = forum.author!['profilePic'];
      if (profilePics is List && profilePics.isNotEmpty) {
        profileImageUrl = profilePics[0];
      }
    }

    return Post(
      id: forum.id ?? '',
      title: forum.title ?? '',
      content: forum.content ?? '',
      author: authorName,
      authorProfileImageUrl: profileImageUrl,
      imageUrl: forum.images?.isNotEmpty == true ? forum.images![0] : null,
      comments: [],
      upvotes: forum.upvotes ?? 0,
      downvotes: forum.downvotes ?? 0,
    );
  }
}
