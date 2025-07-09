import 'package:flutter/material.dart';
import 'package:myunivrs/features/forum/controller/comment_controller.dart';
import 'package:myunivrs/features/forum/models/comment.dart';
import 'package:myunivrs/features/forum/widgets/comment_item.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myunivrs/features/forum/poll/models/pollModel.dart';
import 'package:myunivrs/features/forum/models/taggable_user.dart';
import 'package:myunivrs/services/user_service.dart';
import 'package:myunivrs/shared/shared_pref.dart';

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

class ForumPollCommentScreen extends StatefulWidget {
  final Poll poll;

  const ForumPollCommentScreen({Key? key, required this.poll})
      : super(key: key);

  @override
  _ForumPollCommentScreenState createState() => _ForumPollCommentScreenState();
}

class _ForumPollCommentScreenState extends State<ForumPollCommentScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isTyping = false;
  String? _replyToCommentId;
  String? _editingCommentId;

  // User tagging functionality
  bool _showUserSuggestions = false;
  String _currentTagQuery = '';
  int _tagStartIndex = -1;
  List<TaggableUser> _tagSuggestions = [];
  bool _isLoadingUsers = false;
  final UserService _userService = UserService(Dio());

  final List<TaggedUserPosition> _taggedUsers = [];

  late UniversalCommentController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController =
        UniversalCommentController(targetType: CommentTargetType.forumPoll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
    });

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

    //  text field with display text and position cursor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputController.value = TextEditingValue(
        text: displayText,
        selection: TextSelection.collapsed(
          offset: newCursorPosition,
        ),
      );
      _inputFocusNode.requestFocus();
    });
  }

  Future<void> _loadComments() async {
    print("Loading comments for poll ID: ${widget.poll.id}");
    if (widget.poll.id.isEmpty) {
      return;
    }

    try {
      await _commentController.loadComments(widget.poll.id);
      if (mounted) setState(() {});
    } catch (e) {
      print("Error loading comments: $e");
      _showSnackBar('Error loading comments: ${e.toString().split('\n')[0]}',
          isError: true);
    }
  }

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
        final success = await _commentController.updateComment(
            _editingCommentId!, finalContent);
        if (success != null) {
          _clearInput();
          await _refreshComments();
        }
      } else if (_replyToCommentId != null) {
        final newComment = await _commentController.createComment(
          widget.poll.id,
          finalContent,
          parentCommentId: _replyToCommentId,
        );
        if (newComment != null) {
          _clearInput();
          await _refreshComments();
        }
      } else {
        final newComment = await _commentController.createComment(
            widget.poll.id, finalContent);
        if (newComment != null) {
          _clearInput();
          await _refreshComments();
        }
      }
    } catch (e) {
      print('Error submitting input: $e');
    }
  }

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

  Future<void> _refreshComments() async {
    try {
      await _commentController.loadComments(widget.poll.id);
      if (mounted) setState(() {});
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

  void _startReply(String commentId) {
    setState(() {
      _replyToCommentId = commentId;
      _editingCommentId = null;
    });
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  void _startEdit(String commentId, String currentContent) {
    setState(() {
      _editingCommentId = commentId;
      _replyToCommentId = null;
    });
    _inputController.text = currentContent;
    _inputFocusNode.requestFocus();
  }

  void _cancelAction() {
    _clearInput();
  }

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
              if (success) await _refreshComments();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

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

  // Helper method to get poll author info
  String _getPollAuthor() {
    if (widget.poll.author != null) {
      if (widget.poll.author is Map<String, dynamic>) {
        final authorData = widget.poll.author as Map<String, dynamic>;
        final firstName = authorData['firstName'] ?? '';
        final lastName = authorData['lastName'] ?? '';
        final profileName = authorData['profileName'] ?? '';
        return profileName.isNotEmpty
            ? profileName
            : '$firstName $lastName'.trim();
      } else if (widget.poll.author is String) {
        return widget.poll.author as String;
      }
    }
    return 'Anonymous';
  }

  String? _getPollAuthorProfileImage() {
    if (widget.poll.author != null &&
        widget.poll.author is Map<String, dynamic>) {
      final authorData = widget.poll.author as Map<String, dynamic>;
      final profilePics = authorData['profilePic'];
      if (profilePics is List && profilePics.isNotEmpty) {
        return profilePics[0];
      }
    }
    return null;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown time';

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
              onPressed: () => Navigator.of(context).pop(),
            ),
            backgroundColor: theme.appBarTheme.backgroundColor,
            title: _editingCommentId != null
                ? const Text('Edit Comment')
                : _replyToCommentId != null
                    ? const Text('Reply to Comment')
                    : const Text('Comments'),
            actions: [
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
                    Expanded(
                      child: Consumer<UniversalCommentController>(
                        builder: (context, controller, child) {
                          if (controller.isLoading &&
                              controller.comments.isEmpty) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
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
                                        .retryLoadComments(widget.poll.id),
                                    child: const Text('Retry'),
                                  )
                                ],
                              ),
                            );
                          }

                          final flatComments = controller.getFlatComments();

                          return RefreshIndicator(
                            onRefresh: _refreshComments,
                            child: CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(child: _buildPollItem()),
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
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final item = flatComments[index];
                                        final comment =
                                            item['comment'] as UniversalComment;
                                        final level = item['level'] as int;

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
                    _buildInputField(theme),
                  ],
                ),
                if (_showUserSuggestions) _buildUserSuggestions(theme),
              ],
            ),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
      ),
    );
  }

  // buildPollItem with author details
  Widget _buildPollItem() {
    final authorName = _getPollAuthor();
    final authorProfileImage = _getPollAuthorProfileImage();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poll question
            Text(
              widget.poll.question,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),

            // Poll options
            ...widget.poll.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final stat = index < widget.poll.optionStats.length
                  ? widget.poll.optionStats[index]
                  : null;
              final percentage = stat?.percentage ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(option),
                            Text('${percentage.toStringAsFixed(0)}%'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 12),

            // Total votes
            Text(
              'Total votes: ${widget.poll.totalVotes}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 12),

            // Author details section
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: authorProfileImage != null
                      ? NetworkImage(authorProfileImage)
                      : null,
                  child: authorProfileImage == null
                      ? Text(authorName.isNotEmpty
                          ? authorName[0].toUpperCase()
                          : 'A')
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        _formatTimestamp(widget.poll.createdAt),
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

  Widget _buildUserSuggestions(ThemeData theme) {
    return Positioned(
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
                          backgroundImage: user.profilePicUrl != null
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
    );
  }

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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  decoration: InputDecoration(
                    hintText: _editingCommentId != null
                        ? 'Edit comment'
                        : _replyToCommentId != null
                            ? 'Add reply'
                            : 'Add comment',
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 12.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    suffixIcon:
                        const Icon(Icons.alternate_email, color: Colors.grey),
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                ),
              ),
              const SizedBox(width: 8),
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
