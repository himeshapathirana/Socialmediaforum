import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';
import 'package:myunivrs/features/forum/subForum/screens/SubForumComment.dart';
import 'package:myunivrs/features/forum/subForum/screens/SubForumPollComment.dart';
import 'package:myunivrs/features/forum/subForum/widgets/EditSupforumPost.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myunivrs/app/app_images.dart';
import 'package:dio/dio.dart';

class MySubforumPostCard extends StatefulWidget {
  final int index;
  final SubPostModel post;

  const MySubforumPostCard({
    Key? key,
    required this.index,
    required this.post,
    required int commentsCount,
  }) : super(key: key);

  @override
  _MySubforumPostCardState createState() => _MySubforumPostCardState();
}

class _MySubforumPostCardState extends State<MySubforumPostCard> {
  late int upvotes;
  late int downvotes;
  late bool isUpvoted;
  late bool isDownvoted;
  late int commentsCount;
  late bool isSaved;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    upvotes = widget.post.upvotes;
    downvotes = widget.post.downvotes.abs();
    commentsCount = widget.post.commentCount is int
        ? widget.post.commentCount
        : (widget.post.commentCount as Map<String, dynamic>)['count'] ?? 0;
    isUpvoted = false;
    isDownvoted = false;
    isSaved = false;
  }

  void _toggleUpvote() {
    setState(() {
      if (isUpvoted) {
        upvotes--;
        isUpvoted = false;
      } else {
        upvotes++;
        isUpvoted = true;
        if (isDownvoted) {
          downvotes--;
          isDownvoted = false;
        }
      }
    });
  }

  void _toggleDownvote() {
    setState(() {
      if (isDownvoted) {
        downvotes--;
        isDownvoted = false;
      } else {
        downvotes++;
        isDownvoted = true;
        if (isUpvoted) {
          upvotes--;
          isUpvoted = false;
        }
      }
    });
  }

  void _toggleSave() {
    setState(() {
      isSaved = !isSaved;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Post ${isSaved ? 'saved' : 'unsaved'}!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _showShareOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('Share on WhatsApp'),
                onTap: () async {
                  final message = 'Check out this Post:\n'
                      '📌 ${widget.post.title}\n';
                  try {
                    final whatsappUrl =
                        "whatsapp://send?text=${Uri.encodeComponent(message)}";
                    await launchUrl(
                      Uri.parse(whatsappUrl),
                      mode: LaunchMode.externalApplication,
                    );
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open WhatsApp'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Link'),
                onTap: () {
                  final link = 'https://myunivrs.com/post/${widget.post.id}';
                  Clipboard.setData(ClipboardData(text: link));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('More Options'),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(
                    'Check out this post: ${widget.post.title}\n',
                    subject: 'Sub-Forum Post',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    String? selectedReason;
    final TextEditingController otherReasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Post'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Please select a reason for reporting this post:'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      hint: const Text('Select a reason'),
                      items: const [
                        DropdownMenuItem(
                            value: 'spam', child: Text('Spam or misleading')),
                        DropdownMenuItem(
                            value: 'inappropriate',
                            child: Text('Inappropriate content')),
                        DropdownMenuItem(
                            value: 'harassment',
                            child: Text('Harassment or bullying')),
                        DropdownMenuItem(
                            value: 'other', child: Text('Other reason')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value;
                        });
                      },
                    ),
                    if (selectedReason == 'other')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: TextField(
                          controller: otherReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Please specify',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = selectedReason == 'other'
                    ? otherReasonController.text.trim()
                    : selectedReason;
                if (reason == null || reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please select a reason or specify other reason'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                await _submitReport(reason);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      final forumService = ForumService(Dio());
      await forumService.reportSubForumPost(
        postId: widget.post.id!,
        reason: reason,
        note: null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubForumPostCommentScreen(post: widget.post),
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.isNegative) {
        return 'Just now';
      }

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return '$minutes min${minutes == 1 ? '' : 's'} ago';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours hour${hours == 1 ? '' : 's'} ago';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return '$days day${days == 1 ? '' : 's'} ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks week${weeks == 1 ? '' : 's'} ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '$months month${months == 1 ? '' : 's'} ago';
      } else {
        return DateFormat('MMM d, y').format(dateTime);
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return 'Unknown';
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    try {
      final forumService = ForumService(Dio());
      await forumService.deleteSubForumPost(widget.post.id!);

      if (mounted) {
        Fluttertoast.showToast(msg: "Post deleted successfully");
        // You might want to add a callback here to refresh the parent widget
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: "Failed to delete post: ${e.toString()}");
      }
    }
  }

  void _navigateToEditPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSubForumPostScreen(post: widget.post),
      ),
    ).then((_) {
      // Refresh data if needed
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: width * 0.04,
        vertical: height * 0.01,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.05, vertical: height * 0.02),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.post.author.profilePic == null ||
                          widget.post.author.profilePic!.isEmpty
                      ? Image.asset(
                          AppImages.imgPerson2,
                          width: width * 0.12,
                          height: width * 0.12,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          widget.post.author.profilePic!,
                          width: width * 0.12,
                          height: width * 0.12,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              AppImages.imgPerson2,
                              width: width * 0.12,
                              height: width * 0.12,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                ),
                SizedBox(width: width * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.author.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: height * 0.003),
                      Text(
                        _formatTime(widget.post.createdAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          color: Color.fromARGB(255, 113, 113, 113),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: width * 0.1,
                      height: height * 0.045,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          width: 0.5,
                          color: const Color.fromARGB(100, 158, 158, 158),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: _toggleSave,
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.blue : Colors.grey[600],
                          size: 18,
                        ),
                      ),
                    ),
                    SizedBox(width: width * 0.025),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _navigateToEditPost();
                        } else if (value == 'delete') {
                          _showDeleteDialog();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                width * 0.05, 0, width * 0.05, height * 0.015),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: width * 0.03, vertical: height * 0.007),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                widget.post.category,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Text(
              widget.post.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: height * 0.01),

          // Added content section with See More functionality
          if (widget.post.content != null && widget.post.content!.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.05,
                vertical: height * 0.01,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.content!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color.fromARGB(255, 80, 80, 80),
                    ),
                    maxLines: _isExpanded ? null : 3,
                    overflow:
                        _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
                  ),
                  if (widget.post.content!.length > 100)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Text(
                        _isExpanded ? 'See Less' : 'See More',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          SizedBox(height: height * 0.01),
          widget.post.images.isEmpty
              ? Container()
              : Container(
                  margin: EdgeInsets.symmetric(horizontal: width * 0.05),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.post.images.first,
                      width: double.infinity,
                      height: height * 0.25,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: height * 0.25,
                          color: Colors.grey[300],
                          child: Icon(Icons.broken_image,
                              size: 50, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.03, vertical: height * 0.01),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: _toggleUpvote,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ImageFiltered(
                            imageFilter: ColorFilter.mode(
                              isUpvoted ? Colors.green : Colors.grey[600]!,
                              BlendMode.srcIn,
                            ),
                            child: Image.asset(
                              AppImages.thumbsUp,
                              width: 20,
                              height: 20,
                            ),
                          ),
                          SizedBox(width: width * 0.01),
                          Text(
                            '$upvotes',
                            style: TextStyle(
                              color:
                                  isUpvoted ? Colors.green : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: width * 0.01),
                    TextButton(
                      onPressed: _toggleDownvote,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ImageFiltered(
                            imageFilter: ColorFilter.mode(
                              isDownvoted ? Colors.red : Colors.grey[600]!,
                              BlendMode.srcIn,
                            ),
                            child: Image.asset(
                              AppImages.thumbsDown,
                              width: 20,
                              height: 20,
                            ),
                          ),
                          SizedBox(width: width * 0.01),
                          Text(
                            '$downvotes',
                            style: TextStyle(
                              color:
                                  isDownvoted ? Colors.red : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _navigateToComments,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                      alignment: Alignment.centerLeft,
                    ),
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    label: Text(
                      commentsCount > 0
                          ? "$commentsCount ${commentsCount == 1 ? 'Comment' : 'Comments'}"
                          : "No comments",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: height * 0.01),
        ],
      ),
    );
  }
}
