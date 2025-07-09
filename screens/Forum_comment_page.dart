import 'package:flutter/material.dart';
import 'package:myunivrs/features/forum/controller/comment_controller.dart';
import 'package:myunivrs/features/forum/models/comment.dart';
import 'package:myunivrs/features/forum/models/post.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myunivrs/features/forum/models/taggable_user.dart';
import 'package:myunivrs/services/user_service.dart';
import 'package:myunivrs/shared/shared_pref.dart';

import '../widgets/comment_item.dart';

// Model to track tagged user positions in text for @ mentions
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

// Main screen for viewing and managing forum post comments
class ForumPostCommentScreen extends StatefulWidget {
  final Post post;

  const ForumPostCommentScreen({Key? key, required this.post})
      : super(key: key);

  @override
  _ForumPostCommentScreenState createState() => _ForumPostCommentScreenState();
}

class _ForumPostCommentScreenState extends State<ForumPostCommentScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isTyping = false;
  String? _replyToCommentId; // Track which comment is being replied to
  String? _editingCommentId; // Track which comment is being edited

  // User tagging (@mention) functionality variables
  bool _showUserSuggestions = false;
  String _currentTagQuery = '';
  int _tagStartIndex = -1;
  List<TaggableUser> _tagSuggestions = [];
  bool _isLoadingUsers = false;
  final UserService _userService = UserService(Dio());

  final List<TaggedUserPosition> _taggedUsers =
      []; // Store tagged user positions

  late UniversalCommentController _commentController;

  @override
  void initState() {
    super.initState();
    // Initialize comment controller for forum posts
    _commentController =
        UniversalCommentController(targetType: CommentTargetType.forumPost);

    // Load comments after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
    });

    // Listen for text input changes to handle @ mentions
    _inputController.addListener(_handleInputChange);
  }

  @override
  void dispose() {
    _inputController.removeListener(_handleInputChange);
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // Handle text input changes to detect @ mentions
  void _handleInputChange() {
    final text = _inputController.text;
    final selection = _inputController.selection;

    if (!selection.isValid || selection.start != selection.end) return;

    // Update typing state
    setState(() {
      _isTyping = text.trim().isNotEmpty;
    });

    // Check for @ mentions
    final beforeCursor = text.substring(0, selection.start);
    final atIndex = beforeCursor.lastIndexOf('@');

    if (atIndex >= 0 && (atIndex == 0 || beforeCursor[atIndex - 1] == ' ')) {
      final afterAt = beforeCursor.substring(atIndex + 1);

      // Check if there's a space after @ (which would end the mention)
      if (!afterAt.contains(' ')) {
        setState(() {
          _showUserSuggestions = true;
          _currentTagQuery = afterAt;
          _tagStartIndex = atIndex;
        });
        _searchUsers(afterAt);
        return;
      }
    }

    // Hide suggestions if not in mention mode
    if (_showUserSuggestions) {
      setState(() {
        _showUserSuggestions = false;
        _currentTagQuery = '';
        _tagStartIndex = -1;
      });
    }
  }

  // Search for users to tag based on query
  Future<void> _searchUsers(String query) async {
    if (_isLoadingUsers) return;

    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final result = await _userService.getAllUsers(
        search: query,
        limit: 5,
      );

      setState(() {
        _tagSuggestions = (result['users'] as List)
            .map((user) => TaggableUser.fromJson(user.toJson()))
            .toList();
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _tagSuggestions = [];
        _isLoadingUsers = false;
      });
    }
  }

  // Handle user selection from @ mention suggestions
  void _selectUserTag(TaggableUser user) {
    if (_tagStartIndex < 0) return;

    final text = _inputController.text;
    final beforeTag = text.substring(0, _tagStartIndex);
    final afterTag = text.substring(_inputController.selection.start);

    // Create the display text with just the user's name
    final displayText = '$beforeTag${user.displayName} $afterTag';

    // Store the tagged user with correct positions
    final taggedUser = TaggedUserPosition(
      userId: user.id,
      name: user.displayName,
      startPos: _tagStartIndex,
      endPos: _tagStartIndex + user.displayName.length,
    );

    // Remove any existing tag at the same position
    _taggedUsers.removeWhere((tag) => tag.startPos == _tagStartIndex);
    _taggedUsers.add(taggedUser);

    setState(() {
      _showUserSuggestions = false;
      _currentTagQuery = '';
      _tagStartIndex = -1;
      _isTyping = displayText.trim().isNotEmpty;
    });

    // Calculate the new cursor position
    final newCursorPosition = _tagStartIndex + user.displayName.length + 1;

    // Update text field with display text and position cursor correctly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputController.value = TextEditingValue(
        text: displayText,
        selection: TextSelection.collapsed(
          offset: newCursorPosition,
        ),
      );
      _inputFocusNode.requestFocus();
    });

    // Update text field with display text and position cursor after the mention
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputController.value = TextEditingValue(
        text: displayText,
        selection: TextSelection.collapsed(
          offset: _tagStartIndex + user.displayName.length + 1,
        ),
      );
      _inputFocusNode.requestFocus();
    });
  }

  // Load comments for the current forum post
  Future<void> _loadComments() async {
    print("Loading comments for forum post ID: ${widget.post.id}");
    if (widget.post.id.isEmpty) {
      _showSnackBar('Cannot load comments: Invalid post ID', isError: true);
      return;
    }

    try {
      await _commentController.loadComments(widget.post.id);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error loading comments: $e");
      _showSnackBar('Error loading comments: ${e.toString().split('\n')[0]}',
          isError: true);
    }
  }

  // Submit comment, reply, or edit based on current state
  Future<void> _submitInput() async {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty) return;

    try {
      // Convert display text to @userName format for backend
      String finalContent = _convertToTaggedContent(inputText);

      // Debug prints to verify the format
      print('=== SUBMISSION DEBUG ===');
      print('Original text: $inputText');
      print('Final content: $finalContent');
      print(
          'Tagged users: ${_taggedUsers.map((u) => '${u.name}(${u.userId})').join(', ')}');
      print('========================');

      if (_editingCommentId != null) {
        // Update existing comment
        final success = await _commentController.updateComment(
          _editingCommentId!,
          finalContent,
        );
        if (success != null) {
          _clearInput();
          await _refreshComments();
        }
      } else if (_replyToCommentId != null) {
        // Create reply to existing comment
        final newComment = await _commentController.createComment(
          widget.post.id,
          finalContent,
          parentCommentId: _replyToCommentId,
        );
        if (newComment != null) {
          _clearInput();
          await _refreshComments();
        }
      } else {
        // Create new top-level comment
        final newComment = await _commentController.createComment(
            widget.post.id, finalContent);
        if (newComment != null) {
          _clearInput();
          await _refreshComments();
        }
      }
    } catch (e) {
      print('Error submitting input: $e');
    }
  }

  // Clear input field and reset all states
  void _clearInput() {
    _inputController.clear();
    setState(() {
      _isTyping = false;
      _replyToCommentId = null;
      _editingCommentId = null;
      _taggedUsers.clear();
      _showUserSuggestions = false;
      _currentTagQuery = '';
      _tagStartIndex = -1;
    });
  }

  // Refresh comments list from server
  Future<void> _refreshComments() async {
    try {
      await _commentController.loadComments(widget.post.id);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error refreshing comments: $e');
    }
  }

  // Convert display text to @userName format for backend
  String _convertToTaggedContent(String displayText) {
    if (_taggedUsers.isEmpty) {
      return displayText;
    }

    String result = displayText;

    // Sort tags by position in reverse order to maintain correct indices
    final sortedTags = List<TaggedUserPosition>.from(_taggedUsers);
    sortedTags.sort((a, b) => b.startPos.compareTo(a.startPos));

    for (var tag in sortedTags) {
      // Find the actual position of the user's name in current text
      final tagText = tag.name;
      final tagIndex = result.indexOf(
          tagText, tag.startPos >= result.length ? 0 : tag.startPos);

      if (tagIndex >= 0) {
        // Replace the display name with @userName format for backend
        result = result.substring(0, tagIndex) +
            '@${tag.name}' +
            result.substring(tagIndex + tagText.length);
      }
    }

    return result;
  }

  // Start reply mode for a specific comment
  void _startReply(String commentId) {
    setState(() {
      _replyToCommentId = commentId;
      _editingCommentId = null;
    });
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  // Start edit mode for a specific comment
  void _startEdit(String commentId, String currentContent) {
    setState(() {
      _editingCommentId = commentId;
      _replyToCommentId = null;
    });
    _inputController.text = currentContent;
    _inputFocusNode.requestFocus();
  }

  // Cancel current reply or edit action
  void _cancelAction() {
    _clearInput();
  }

  // Show confirmation dialog before deleting comment
  void _showDeleteConfirmation(BuildContext context, String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text(
            'Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await _commentController.deleteComment(commentId);
              if (success) {
                await _refreshComments();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Show snackbar message to user
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Format timestamp to human-readable relative time
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider.value(
      value: _commentController,
      child: GestureDetector(
        // Hide user suggestions when tapping outside
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_showUserSuggestions) {
            setState(() {
              _showUserSuggestions = false;
            });
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            backgroundColor: theme.appBarTheme.backgroundColor,
            // Dynamic title based on current action
            title: _editingCommentId != null
                ? const Text('Edit Comment')
                : _replyToCommentId != null
                    ? const Text('Reply to Comment')
                    : const Text('Comments'),
            actions: [
              // Show cancel button when editing or replying
              if (_editingCommentId != null || _replyToCommentId != null)
                TextButton(
                  onPressed: _cancelAction,
                  child:
                      const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Main content area with comments list
                    Expanded(
                      child: Consumer<UniversalCommentController>(
                        builder: (context, controller, child) {
                          // Show loading indicator when first loading
                          if (controller.isLoading &&
                              controller.comments.isEmpty) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          // Show error message if loading failed
                          if (controller.error != null &&
                              controller.comments.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Error: ${controller.error}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => controller
                                        .retryLoadComments(widget.post.id),
                                    child: const Text('Retry'),
                                  )
                                ],
                              ),
                            );
                          }

                          // Get flattened list of comments with nesting levels
                          final flatComments = controller.getFlatComments();

                          return RefreshIndicator(
                            onRefresh: _refreshComments,
                            child: CustomScrollView(
                              slivers: [
                                // Original post display
                                SliverToBoxAdapter(
                                  child: _buildPostItem(),
                                ),
                                // Comments header with count
                                SliverToBoxAdapter(
                                  child: Container(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${controller.totalComments} Comments',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        // Show loading indicator when refreshing
                                        if (controller.isLoading)
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Empty state message
                                if (flatComments.isEmpty)
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Center(
                                        child: Text(
                                          'No comments yet. Be the first to comment!',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  // Comments list with threading/nesting
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final item = flatComments[index];
                                        final comment =
                                            item['comment'] as UniversalComment;
                                        final level = item['level'] as int;

                                        // Calculate visual indentation for nested comments
                                        const baseIndent = 12.0;
                                        const maxVisualIndent = 8;
                                        final visualLevel =
                                            level > maxVisualIndent
                                                ? maxVisualIndent
                                                : level;
                                        final indentAmount =
                                            baseIndent * visualLevel;

                                        return Container(
                                          key: ValueKey(comment.id),
                                          margin: EdgeInsets.only(
                                              left: indentAmount),
                                          child: Column(
                                            children: [
                                              // Thread line separator for nested comments
                                              if (level > 0)
                                                Container(
                                                  height: 1,
                                                  margin: EdgeInsets.only(
                                                    left: 16,
                                                    right:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.3,
                                                  ),
                                                  color: Colors.grey
                                                      .withOpacity(0.3),
                                                ),
                                              // Individual comment item
                                              UniversalCommentItem(
                                                comment: comment,
                                                onReply: (id) =>
                                                    _startReply(id),
                                                onEdit: (id) => _startEdit(
                                                    id, comment.content),
                                                onDelete: (id) =>
                                                    _showDeleteConfirmation(
                                                        context, id),
                                                onUpvote: (id) => controller
                                                    .voteComment(id, true),
                                                onDownvote: (id) => controller
                                                    .voteComment(id, false),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      childCount: flatComments.length,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Comment input field at bottom
                    _buildInputField(theme),
                  ],
                ),
                // User suggestions overlay for @ mentions
                if (_showUserSuggestions)
                  Positioned(
                    bottom: 70,
                    left: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _isLoadingUsers
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _tagSuggestions.isEmpty
                              ? const ListTile(
                                  title: Text('No users found',
                                      style: TextStyle(color: Colors.grey)),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _tagSuggestions.length,
                                  itemBuilder: (context, index) {
                                    final user = _tagSuggestions[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: user.profilePicUrl !=
                                                null
                                            ? NetworkImage(user.profilePicUrl!)
                                            : null,
                                        child: user.profilePicUrl == null
                                            ? Text(user.displayName[0])
                                            : null,
                                      ),
                                      title: Text(user.displayName),
                                      onTap: () => _selectUserTag(user),
                                    );
                                  },
                                ),
                    ),
                  ),
              ],
            ),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
      ),
    );
  }

  // Build the original forum post display at top of comments
  Widget _buildPostItem() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post title
            Text(
              widget.post.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),

            // Post content with ellipsis for long text
            if (widget.post.content.isNotEmpty)
              Text(
                widget.post.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),

            // Post image if available
            if (widget.post.imageUrl != null &&
                widget.post.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.post.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 50),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),

            // Post author information
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: widget.post.authorProfileImageUrl != null
                      ? NetworkImage(widget.post.authorProfileImageUrl!)
                      : null,
                  child: widget.post.authorProfileImageUrl == null
                      ? Text(widget.post.author.isNotEmpty
                          ? widget.post.author[0].toUpperCase()
                          : 'A')
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.author,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        'Post Author',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build comment input field with reply/edit indicators
  Widget _buildInputField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action indicator bar for reply/edit mode
          if (_replyToCommentId != null || _editingCommentId != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _editingCommentId != null ? Icons.edit : Icons.reply,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _editingCommentId != null
                        ? 'Editing comment'
                        : 'Replying to comment',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelAction,
                    child:
                        Icon(Icons.close, size: 16, color: theme.primaryColor),
                  ),
                ],
              ),
            ),
          // Input field with send button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  decoration: InputDecoration(
                    // Dynamic hint text based on current mode
                    hintText: _editingCommentId != null
                        ? 'Edit comment'
                        : _replyToCommentId != null
                            ? 'Add reply'
                            : 'Add comment',
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 12.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    // @ symbol icon to indicate mention functionality
                    suffixIcon:
                        const Icon(Icons.alternate_email, color: Colors.grey),
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                ),
              ),
              const SizedBox(width: 8),
              // Dynamic action button based on current mode
              if (_editingCommentId != null)
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: _submitInput,
                )
              else if (_isTyping)
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _submitInput,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
