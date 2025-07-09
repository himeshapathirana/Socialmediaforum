import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/features/forum/models/comment.dart';
import 'package:myunivrs/features/forum/services/comment_services.dart';

// Universal comment controller that handles all comment operations with state management
class UniversalCommentController with ChangeNotifier {
  final UniversalCommentService _commentService;
  final CommentTargetType targetType; // Type of target (post, article, etc.)

  // Core state variables
  List<UniversalComment> _comments = []; // Hierarchical comment tree
  bool _isLoading = false; // Loading state for UI feedback
  String? _error; // Error message for user display
  String? _editingCommentId; // ID of comment currently being edited
  String? _editingCommentParentId; // Parent ID for edit context
  int _retryCount = 0; // Current retry attempt count
  int _totalComments = 0; // Total number of comments (flat count)
  static const int maxRetries = 3; // Maximum retry attempts for failed requests
  final Set<String> _expandedComments =
      {}; // Set of expanded comment IDs for UI state

  // Constructor with dependency injection for comment service
  UniversalCommentController({
    required this.targetType,
    UniversalCommentService? commentService,
  }) : _commentService = commentService ?? UniversalCommentService(Dio());

  // Public getters for accessing private state
  List<UniversalComment> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get editingCommentId => _editingCommentId;
  int get totalComments => _totalComments;

  // Fetch comment count for a specific target without loading full comments
  Future<int> getCommentCount(String targetId) async {
    try {
      return await _commentService.getCommentCount(targetId, targetType);
    } catch (e) {
      print("Error getting comment count: $e");
      return 0; // Return 0 on error to prevent UI crashes
    }
  }

  // Clear cached comment count for fresh data fetch
  void clearCommentCountCache(String targetId) {
    _commentService.clearCommentCountCache(targetId, targetType);
  }

  // Set which comment is currently being edited (for inline editing)
  void setEditingComment(String? commentId, {String? parentId}) {
    _editingCommentId = commentId;
    _editingCommentParentId = parentId;
    notifyListeners(); // Notify UI to update edit state
  }

  // Convert hierarchical comment tree to flat list with indentation levels for UI rendering
  List<Map<String, dynamic>> getFlatComments() {
    List<Map<String, dynamic>> flatList = [];

    // Recursive function to flatten comment tree with level tracking
    void addComments(List<UniversalComment> comments, int level) {
      for (var comment in comments) {
        flatList.add({'comment': comment, 'level': level});
        // Only add replies if comment is expanded and has replies
        if (_expandedComments.contains(comment.id) &&
            comment.replies != null &&
            comment.replies!.isNotEmpty) {
          addComments(comment.replies!, level + 1);
        }
      }
    }

    addComments(_comments, 0); // Start from root level (0)
    return flatList;
  }

  // Expand replies for a specific comment (show nested comments)
  void expandReplies(String commentId) {
    _expandedComments.add(commentId);
    notifyListeners(); // Update UI to show expanded state
  }

  // Collapse replies for a specific comment (hide nested comments)
  void collapseReplies(String commentId) {
    _expandedComments.remove(commentId);
    notifyListeners(); // Update UI to show collapsed state
  }

  // Check if a comment's replies are currently expanded
  bool isExpanded(String commentId) {
    return _expandedComments.contains(commentId);
  }

  // Build hierarchical comment tree from flat comment list
  List<UniversalComment> _buildCommentTree(
      List<UniversalComment> flatComments) {
    try {
      print("Building comment tree from ${flatComments.length} comments");

      if (flatComments.isEmpty) return [];

      // Create lookup map for O(1) comment access by ID
      final Map<String, UniversalComment> commentMap = {};
      final List<UniversalComment> rootComments = [];

      // First pass: Create all comment objects with empty replies
      for (var comment in flatComments) {
        if (comment.id.isNotEmpty) {
          commentMap[comment.id] = comment.copyWith(replies: []);
        }
      }

      // Second pass: Build parent-child relationships
      for (var comment in flatComments) {
        if (comment.id.isEmpty) continue;

        if (comment.parentCommentId != null &&
            comment.parentCommentId!.isNotEmpty) {
          // This is a reply - add to parent's replies list
          final parent = commentMap[comment.parentCommentId!];
          if (parent != null && parent.replies != null) {
            parent.replies!.add(commentMap[comment.id]!);
          } else {
            // Parent not found - treat as root comment (orphaned reply)
            print(
                "Parent comment ${comment.parentCommentId} not found for comment ${comment.id}");
            rootComments.add(commentMap[comment.id]!);
          }
        } else {
          // This is a root comment
          rootComments.add(commentMap[comment.id]!);
        }
      }

      // Sort root comments by timestamp (newest first)
      rootComments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      // Sort all reply chains recursively (oldest first for replies)
      _sortRepliesRecursively(rootComments);

      print(
          "Successfully built tree with ${rootComments.length} root comments");
      return rootComments;
    } catch (e) {
      print("Error building comment tree: $e");
      // Fallback: return flat list as individual root comments
      return flatComments.map((c) => c.copyWith(replies: [])).toList();
    }
  }

  // Recursively sort replies within each comment thread (oldest replies first)
  void _sortRepliesRecursively(List<UniversalComment> comments) {
    for (var comment in comments) {
      if (comment.replies != null && comment.replies!.isNotEmpty) {
        comment.replies!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _sortRepliesRecursively(
            comment.replies!); // Recursively sort nested replies
      }
    }
  }

  // Load all comments for a specific target with retry logic
  Future<void> loadComments(String targetId) async {
    if (_isLoading) return; // Prevent concurrent loading

    _setLoading(true);
    _error = null;

    try {
      print("Loading ALL comments for ${targetType.value}: $targetId");

      List<UniversalComment> fetchedComments;

      try {
        // Primary method: Try to get all comments at once
        fetchedComments =
            await _commentService.getAllComments(targetId, targetType);
        print(
            "Successfully fetched ${fetchedComments.length} comments using getAllComments");
      } catch (e) {
        // Fallback method: Use paginated method with high limit
        print("getAllComments failed, trying simple method: $e");
        fetchedComments = await _commentService
            .getComments(targetId, targetType, limit: 10000);
        print(
            "Successfully fetched ${fetchedComments.length} comments using getComments with high limit");
      }

      // Build comment tree and update state
      _comments = _buildCommentTree(fetchedComments);
      _totalComments = fetchedComments.length;
      _retryCount = 0; // Reset retry count on success

      print(
          "Successfully processed ${_comments.length} root comments with total ${_totalComments} comments");
    } catch (e) {
      // Handle error with retry logic
      _error =
          'Failed to load comments. ${_retryCount < maxRetries ? "Please try again." : ""}';
      print("Error loading comments: $e");

      if (_retryCount < maxRetries) {
        _retryCount++;
        print("Retrying... attempt $_retryCount of $maxRetries");
        await Future.delayed(
            Duration(seconds: 1 * _retryCount)); // Exponential backoff
        return loadComments(targetId); // Recursive retry
      }
    } finally {
      _setLoading(false);
    }
  }

  // Create a new comment (either root comment or reply)
  Future<UniversalComment?> createComment(
    String targetId,
    String content, {
    String? parentCommentId, // Null for root comments, ID for replies
  }) async {
    if (content.trim().isEmpty) return null; // Validate content

    _setLoading(true);
    try {
      // Create comment via service
      final newComment = await _commentService.createComment(
        targetId,
        content,
        targetType,
        parentCommentId: parentCommentId,
      );

      // Reload comments to get updated tree structure
      await loadComments(targetId);

      // Auto-expand parent comment if this is a reply
      if (newComment.parentCommentId != null) {
        expandReplies(newComment.parentCommentId!);
      }

      _error = null;
      return newComment;
    } catch (e) {
      _error = e.toString();
      print("Error creating comment: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing comment's content
  Future<UniversalComment?> updateComment(
      String commentId, String content) async {
    if (content.trim().isEmpty) return null; // Validate content

    _setLoading(true);
    try {
      UniversalComment? commentToUpdate;
      String? parentId = _editingCommentParentId;
      String? targetId;

      // Find the comment to update in the tree structure
      void findComment(List<UniversalComment> comments) {
        for (var comment in comments) {
          if (comment.id == commentId) {
            commentToUpdate = comment;
            targetId = comment.targetId;
            return;
          }
          if (comment.replies != null) {
            findComment(comment.replies!); // Search recursively in replies
          }
        }
      }

      findComment(_comments);

      if (commentToUpdate == null) {
        throw Exception('Comment not found');
      }

      // Update comment via service
      final updatedComment = await _commentService.updateComment(
        commentId: commentId,
        content: content,
        targetId: commentToUpdate!.targetId,
        targetType: targetType,
        parentCommentId: commentToUpdate!.parentCommentId,
      );

      // Reload comments and clear editing state
      await loadComments(commentToUpdate!.targetId);
      _editingCommentId = null;
      _editingCommentParentId = null;
      _error = null;
      return updatedComment;
    } catch (e) {
      _error = e.toString();
      print("Error updating comment: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a comment and reload the comment tree
  Future<bool> deleteComment(String commentId) async {
    _setLoading(true);
    try {
      String? targetId;

      // Find target ID for reloading after deletion
      void findTargetId(List<UniversalComment> comments) {
        for (var comment in comments) {
          if (comment.id == commentId) {
            targetId = comment.targetId;
            return;
          }
          if (comment.replies != null) {
            findTargetId(comment.replies!); // Search recursively
          }
        }
      }

      findTargetId(_comments);

      // Delete comment via service
      await _commentService.deleteComment(commentId);

      // Reload comments if target ID was found
      if (targetId != null) {
        await loadComments(targetId!);
      }

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      print("Error deleting comment: $e");
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Handle upvote/downvote actions with optimistic UI updates
  Future<bool> voteComment(String commentId, bool isUpvote) async {
    try {
      print("Voting on comment: $commentId, isUpvote: $isUpvote");

      UniversalComment? targetComment;

      // Find the comment to vote on in the tree structure
      void findComment(List<UniversalComment> comments) {
        for (var comment in comments) {
          if (comment.id == commentId) {
            targetComment = comment;
            return;
          }
          if (comment.replies != null) {
            findComment(comment.replies!); // Search recursively
          }
        }
      }

      findComment(_comments);

      if (targetComment == null) {
        throw Exception('Comment not found');
      }

      // Store previous vote states for toast message logic
      final bool previousIsUpvoted = targetComment!.isUpvoted;
      final bool previousIsDownvoted = targetComment!.isDownvoted;

      // Send vote request to service with current state
      final result = await _commentService.voteComment(
        commentId,
        isUpvote,
        currentUpvotes: targetComment!.upvotes,
        currentDownvotes: targetComment!.downvotes,
        currentIsUpvoted: targetComment!.isUpvoted,
        currentIsDownvoted: targetComment!.isDownvoted,
      );

      if (result['success'] == true) {
        // Update local state immediately for responsive UI
        _updateCommentVotes(
          commentId,
          result['upvotes'] ?? 0,
          result['downvotes'] ?? 0,
          result['isUpvoted'] ?? false,
          result['isDownvoted'] ?? false,
        );

        // Show appropriate toast message based on vote action
        String toastMessage;
        if (isUpvote) {
          // For upvote button press
          if (!previousIsUpvoted && result['isUpvoted']) {
            toastMessage = 'Comment upvoted!';
          } else if (previousIsUpvoted && !result['isUpvoted']) {
            toastMessage = 'Upvote removed!';
          } else {
            toastMessage = 'Comment upvoted!'; // Fallback
          }
        } else {
          // For downvote button press
          if (!previousIsDownvoted && result['isDownvoted']) {
            toastMessage = 'Comment downvoted!';
          } else if (previousIsDownvoted && !result['isDownvoted']) {
            toastMessage = 'Downvote removed!';
          } else {
            toastMessage = 'Comment downvoted!'; // Fallback
          }
        }

        // Show success toast
        Fluttertoast.showToast(
          msg: toastMessage,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        notifyListeners(); // Update UI immediately

        // Refresh data from server after short delay
        final targetId = targetComment!.targetId;
        await Future.delayed(Duration(milliseconds: 500));
        await loadComments(targetId);

        return true;
      }

      return false;
    } catch (e) {
      _error = e.toString();
      print("Error voting on comment: $e");

      // Show error toast
      Fluttertoast.showToast(
        msg: 'Failed to vote on comment',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      return false;
    }
  }

  // Update vote counts and states for a specific comment in the tree
  void _updateCommentVotes(
    String commentId,
    int upvotes,
    int downvotes,
    bool isUpvoted,
    bool isDownvoted,
  ) {
    // Recursively search and update comment in tree structure
    void updateInList(List<UniversalComment> comments) {
      for (int i = 0; i < comments.length; i++) {
        if (comments[i].id == commentId) {
          // Found target comment - update with new vote data
          comments[i] = comments[i].copyWith(
            upvotes: upvotes,
            downvotes: downvotes,
            isUpvoted: isUpvoted,
            isDownvoted: isDownvoted,
          );
          return;
        }
        if (comments[i].replies != null) {
          updateInList(comments[i].replies!); // Search in replies
        }
      }
    }

    updateInList(_comments);
  }

  // Set loading state and notify listeners for UI updates
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Clear error state for user retry actions
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Reset retry count and attempt to reload comments
  Future<void> retryLoadComments(String targetId) async {
    _retryCount = 0; // Reset retry counter
    await loadComments(targetId);
  }
}
