import 'package:flutter/material.dart';
import 'package:myunivrs/features/forum/controller/comment_controller.dart';
import 'package:myunivrs/features/forum/models/comment.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import './tagged_content.dart';

class UniversalCommentItem extends StatefulWidget {
  final UniversalComment comment;
  final Function(String) onReply;
  final Function(String)? onEdit;
  final Function(String)? onDelete;
  final Function(String)? onUpvote;
  final Function(String)? onDownvote;
  final int depth;

  const UniversalCommentItem({
    Key? key,
    required this.comment,
    required this.onReply,
    this.onEdit,
    this.onDelete,
    this.onUpvote,
    this.onDownvote,
    this.depth = 0,
  }) : super(key: key);

  @override
  State<UniversalCommentItem> createState() => _UniversalCommentItemState();
}

class _UniversalCommentItemState extends State<UniversalCommentItem> {
  bool _isCurrentUserComment = false;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUserComment();
  }

  Future<void> _checkIfCurrentUserComment() async {
    try {
      final userId = await SharedPref.getUserId();
      final isCurrentUser = (widget.comment.author == "Me") ||
          (userId != null && widget.comment.userId == userId);

      if (mounted) {
        setState(() {
          _isCurrentUserComment = isCurrentUser;
        });
      }
    } catch (e) {
      print("Error checking if comment belongs to current user: $e");
    }
  }

  String _getFormattedTime(Timestamp timestamp) {
    final now = DateTime.now();
    final commentTime = timestamp.toDate();
    final difference = now.difference(commentTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(commentTime);
    }
  }

  Future<void> _handleVote(bool isUpvote) async {
    if (_isVoting) return;

    setState(() {
      _isVoting = true;
    });

    try {
      if (isUpvote && widget.onUpvote != null) {
        await widget.onUpvote!(widget.comment.id);
      } else if (!isUpvote && widget.onDownvote != null) {
        await widget.onDownvote!(widget.comment.id);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedTime = _getFormattedTime(widget.comment.timestamp);
    final hasReplies =
        widget.comment.replies != null && widget.comment.replies!.isNotEmpty;
    final controller =
        Provider.of<UniversalCommentController>(context, listen: false);

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: widget.depth * 20.0,
        top: 8.0,
        bottom: 8.0,
        end: 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.depth > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child:
                  Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
            ),
          // Avatar and username aligned vertically
          Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.comment.profileImageUrl != null
                    ? NetworkImage(widget.comment.profileImageUrl!)
                    : null,
                child: widget.comment.profileImageUrl == null
                    ? Text(widget.comment.author.isNotEmpty
                        ? widget.comment.author[0]
                        : '?')
                    : null,
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Flexible main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username, time, and menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.comment.author,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (_isCurrentUserComment)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        padding: EdgeInsets.zero,
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                        onSelected: (String value) {
                          if (value == 'edit' && widget.onEdit != null) {
                            widget.onEdit!(widget.comment.id);
                          } else if (value == 'delete' &&
                              widget.onDelete != null) {
                            widget.onDelete!(widget.comment.id);
                          }
                        },
                      ),
                  ],
                ),
                // Comment text
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: TaggedContent(
                    content: widget.comment.content,
                    textStyle: theme.textTheme.bodyMedium,
                  ),
                ),
                // Actions row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    IconButton(
                      icon: Icon(Icons.thumb_up_alt_outlined,
                          size: 18, color: Colors.grey[700]),
                      onPressed: _isVoting ? null : () => _handleVote(true),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    Text('${widget.comment.upvotes}',
                        style: theme.textTheme.bodySmall),
                    IconButton(
                      icon: Icon(Icons.thumb_down_alt_outlined,
                          size: 18, color: Colors.grey[700]),
                      onPressed: _isVoting ? null : () => _handleVote(false),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    Text('${widget.comment.downvotes}',
                        style: theme.textTheme.bodySmall),
                    TextButton(
                      onPressed: () => widget.onReply(widget.comment.id),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.white, // Text color
                        backgroundColor: const Color.fromARGB(
                            109, 73, 138, 150), // Button background
                        textStyle: theme.textTheme.bodySmall,
                      ),
                      child: const Text('Reply'),
                    ),
                    if (hasReplies)
                      TextButton(
                        onPressed: () {
                          if (controller.isExpanded(widget.comment.id)) {
                            controller.collapseReplies(widget.comment.id);
                          } else {
                            controller.expandReplies(widget.comment.id);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: Colors.white,
                          backgroundColor:
                              const Color.fromARGB(111, 141, 147, 148),
                          textStyle: theme.textTheme.bodySmall,
                        ),
                        child: Text(
                          controller.isExpanded(widget.comment.id)
                              ? 'Hide Replies'
                              : 'See Replies',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
