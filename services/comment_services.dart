import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myunivrs/features/forum/models/comment.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/api/api_config.dart';

// Cache class to store comment counts with timestamps
class _CachedCount {
  final int count;
  final DateTime timestamp;
  _CachedCount(this.count, this.timestamp);
}

/// Universal service for handling all comment-related operations with caching
class UniversalCommentService {
  final Dio dio;
  final baseUrl = apiUrl;

  // Static cache for comment counts across all target types (30-second TTL)
  static final Map<String, _CachedCount> _commentCountCache = {};

  UniversalCommentService(this.dio);

  /// Get authentication token from shared preferences
  Future<String?> getToken() async {
    return await SharedPref.getToken();
  }

  /// Get comment count with caching (30-second cache TTL)
  Future<int> getCommentCount(
      String targetId, CommentTargetType targetType) async {
    // Create unique cache key combining targetId and targetType
    final cacheKey = '${targetType.value}_$targetId';

    // Check cache first
    final cachedData = _commentCountCache[cacheKey];
    final now = DateTime.now();

    // Use cache if available and less than 30 seconds old
    if (cachedData != null &&
        now.difference(cachedData.timestamp).inSeconds < 30) {
      print(
          "Using cached comment count for ${targetType.value} $targetId: ${cachedData.count}");
      return cachedData.count;
    }

    try {
      print("Fetching comment count for ${targetType.value}: $targetId");

      // Try to get count from dedicated API endpoint first
      final count = await _getCommentCountFromAPI(targetId, targetType);

      if (count != null) {
        // Update cache with API result
        _commentCountCache[cacheKey] = _CachedCount(count, now);
        return count;
      }

      // Fallback: Get all comments and count them manually
      final comments = await getComments(targetId, targetType, limit: 10000);
      final commentCount = comments.length;

      // Update cache with fallback result
      _commentCountCache[cacheKey] = _CachedCount(commentCount, now);

      print("Comment count for ${targetType.value} $targetId: $commentCount");
      return commentCount;
    } catch (e) {
      print(
          "Error getting comment count for ${targetType.value} $targetId: $e");
      return 0;
    }
  }

  /// Get comment count from dedicated API endpoint (if available)
  Future<int?> _getCommentCountFromAPI(
      String targetId, CommentTargetType targetType) async {
    try {
      final String? authToken = await getToken();

      final Response response = await dio.get(
        '$baseUrl/comments/count',
        queryParameters: {
          'targetId': targetId,
          'targetType': targetType.value,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['count'] as int? ?? data['total'] as int?;
      }
    } catch (e) {
      print("API comment count endpoint not available, using fallback: $e");
    }
    return null;
  }

  /// Clear cache for a specific target
  void clearCommentCountCache(String targetId, CommentTargetType targetType) {
    final cacheKey = '${targetType.value}_$targetId';
    _commentCountCache.remove(cacheKey);
    print("Cleared comment count cache for ${targetType.value} $targetId");
  }

  /// Clear all comment count cache
  void clearAllCommentCountCache() {
    _commentCountCache.clear();
    print("Cleared all comment count cache");
  }

  /// Update cache when comments are modified
  void _updateCommentCountCache(
      String targetId, CommentTargetType targetType, int newCount) {
    final cacheKey = '${targetType.value}_$targetId';
    _commentCountCache[cacheKey] = _CachedCount(newCount, DateTime.now());
  }

  /// Create a new comment or reply
  Future<UniversalComment> createComment(
    String targetId,
    String content,
    CommentTargetType targetType, {
    String? parentCommentId,
  }) async {
    try {
      print("Creating comment for ${targetType.value}: $targetId");
      final String? authToken = await getToken();
      final String? userId = await SharedPref.getUserId();
      final String? userName = await SharedPref.getUserName();
      final String authorName = userName ?? 'Anonymous';

      // Prepare comment data
      final commentData = {
        'content': content,
        'targetId': targetId,
        'targetType': targetType.value,
      };

      // Add parent comment ID if this is a reply
      if (parentCommentId != null) {
        commentData['parentComment'] = parentCommentId;
      }

      print("Sending comment data: $commentData");

      final Response response = await dio.post(
        '$baseUrl/comments',
        data: commentData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print(
          "Create comment response: ${response.statusCode} - ${response.data}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;

        // Show success toast
        Fluttertoast.showToast(
          msg: parentCommentId != null
              ? "Reply added successfully!"
              : "Comment added successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // Clear cache since comment count has changed
        clearCommentCountCache(targetId, targetType);

        // Return new comment object
        return UniversalComment(
          id: data['_id'] as String? ?? '',
          content: data['content'] as String? ?? '',
          author: authorName,
          userId: userId ?? '',
          timestamp: data['createdAt'] != null
              ? Timestamp.fromDate(DateTime.parse(data['createdAt'] as String))
              : Timestamp.now(),
          profileImageUrl: null,
          upvotes: (data['upvotes'] as int?) ?? 0,
          downvotes: (data['downvotes'] as int?) ?? 0,
          targetId: targetId,
          targetType: targetType,
          parentCommentId: data['parentComment'] as String?,
          isReply: parentCommentId != null,
          replies: [],
        );
      } else {
        throw Exception('Failed to create comment: ${response.statusMessage}');
      }
    } catch (e) {
      print("Error creating comment: $e");
      Fluttertoast.showToast(
        msg: 'Failed to create comment: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      throw Exception('Failed to create comment: $e');
    }
  }

  /// Fetch all comments for a target with automatic pagination
  Future<List<UniversalComment>> getAllComments(
    String targetId,
    CommentTargetType targetType,
  ) async {
    try {
      print("=== FETCHING ALL COMMENTS FOR ${targetType.value}: $targetId ===");

      List<UniversalComment> allComments = [];
      int page = 1;
      int limit = 50;
      bool hasMore = true;
      int maxPages = 20; // Safety limit to prevent infinite loops
      int currentPage = 0;

      // Paginate through all comments
      while (hasMore && currentPage < maxPages) {
        try {
          print("Fetching page $page with limit $limit...");

          final pageComments = await getCommentsWithPagination(
            targetId,
            targetType,
            page,
            limit,
          );

          if (pageComments.isEmpty) {
            print("No more comments found on page $page");
            hasMore = false;
          } else {
            print("Found ${pageComments.length} comments on page $page");
            allComments.addAll(pageComments);

            // If we got fewer comments than the limit, we've reached the end
            if (pageComments.length < limit) {
              hasMore = false;
            }

            page++;
            currentPage++;
          }
        } catch (e) {
          print("Error fetching page $page: $e");

          // If first page fails, try fallback method
          if (page == 1) {
            print("Pagination failed, trying simple method with high limit...");
            return await getComments(targetId, targetType, limit: 10000);
          }

          break;
        }
      }

      print("=== FETCHED TOTAL ${allComments.length} COMMENTS ===");

      // Update cache with actual count
      _updateCommentCountCache(targetId, targetType, allComments.length);

      return allComments;
    } catch (e) {
      print("Error in getAllComments: $e");
      // Fallback to simple method
      return await getComments(targetId, targetType, limit: 10000);
    }
  }

  /// Get comments with pagination support
  Future<List<UniversalComment>> getCommentsWithPagination(
    String targetId,
    CommentTargetType targetType,
    int page,
    int limit,
  ) async {
    try {
      final String? authToken = await getToken();
      final String? currentUserId = await SharedPref.getUserId();

      final Response response = await dio.get(
        '$baseUrl/comments',
        queryParameters: {
          'targetId': targetId,
          'targetType': targetType.value,
          'page': page,
          'limit': limit,
          'sort': '-createdAt', // Sort by newest first
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> commentsData = response.data['comments'] ?? [];
        return _parseComments(
            commentsData, currentUserId, targetId, targetType);
      } else {
        throw Exception('Failed to get comments: ${response.statusMessage}');
      }
    } catch (e) {
      print("Error in getCommentsWithPagination: $e");
      throw e;
    }
  }

  /// Get comments with optional limit
  Future<List<UniversalComment>> getComments(
    String targetId,
    CommentTargetType targetType, {
    int? limit,
  }) async {
    try {
      final String? authToken = await getToken();
      final String? currentUserId = await SharedPref.getUserId();

      // Prepare query parameters
      Map<String, dynamic> queryParams = {
        'targetId': targetId,
        'targetType': targetType.value,
      };

      if (limit != null) {
        queryParams['limit'] = limit;
        print("Fetching comments with limit: $limit");
      } else {
        queryParams['limit'] = 1000; // Default high limit
        print("Fetching comments with default limit: 1000");
      }

      final Response response = await dio.get(
        '$baseUrl/comments',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("Get comments response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> commentsData = response.data['comments'] ?? [];
        final comments =
            _parseComments(commentsData, currentUserId, targetId, targetType);

        // Update cache with actual count
        _updateCommentCountCache(targetId, targetType, comments.length);

        return comments;
      } else {
        throw Exception('Failed to get comments: ${response.statusMessage}');
      }
    } catch (e) {
      print("Error getting comments: $e");
      throw Exception('Failed to get comments: $e');
    }
  }

  /// Parse raw comment data into UniversalComment objects
  List<UniversalComment> _parseComments(
    List<dynamic> commentsData,
    String? currentUserId,
    String targetId,
    CommentTargetType targetType,
  ) {
    final List<UniversalComment> comments = [];

    for (var commentData in commentsData) {
      try {
        String authorName = 'Anonymous';
        String authorId = '';
        String? profilePic;

        // Handle different author data formats
        if (commentData['author'] is String) {
          authorId = commentData['author'] as String;
          final isCurrentUser = currentUserId == authorId;
          authorName = isCurrentUser ? 'Me' : 'User';
        } else if (commentData['author'] is Map<String, dynamic>) {
          final authorData = commentData['author'] as Map<String, dynamic>;
          final firstName = authorData['firstName'] ?? '';
          final lastName = authorData['lastName'] ?? '';
          final profileName = authorData['profileName'] ?? '';

          // Use profile name if available, otherwise combine first and last name
          authorName = profileName.isNotEmpty
              ? profileName
              : '$firstName $lastName'.trim();
          authorId = authorData['_id'] ?? '';

          // Get profile picture if available
          profilePic = (authorData['profilePic'] as List?)?.isNotEmpty == true
              ? authorData['profilePic'][0]
              : null;

          // Mark current user's comments as "Me"
          final isCurrentUser = currentUserId == authorId;
          if (isCurrentUser) authorName = 'Me';
        }

        // Create UniversalComment object
        comments.add(UniversalComment(
          id: commentData['_id'] ?? '',
          content: commentData['content'] ?? '',
          author: authorName,
          userId: authorId,
          timestamp: commentData['createdAt'] != null
              ? Timestamp.fromDate(DateTime.parse(commentData['createdAt']))
              : Timestamp.now(),
          profileImageUrl: profilePic,
          upvotes: commentData['upvotes'] ?? 0,
          downvotes: commentData['downvotes'] ?? 0,
          targetId: targetId,
          targetType: targetType,
          isReply: commentData['parentComment'] != null,
          parentCommentId: commentData['parentComment'],
          isUpvoted: commentData['isUpvoted'] ?? false,
          isDownvoted: commentData['isDownvoted'] ?? false,
        ));
      } catch (e) {
        print("Error parsing comment: $e");
        continue; // Skip malformed comments
      }
    }

    return comments;
  }

  /// Update an existing comment
  Future<UniversalComment> updateComment({
    required String commentId,
    required String content,
    required String targetId,
    required CommentTargetType targetType,
    String? parentCommentId,
  }) async {
    try {
      print("Updating comment with ID: $commentId");
      final String? authToken = await getToken();

      // Prepare update data
      final commentData = {
        'content': content,
        'targetId': targetId,
        'targetType': targetType.value,
      };

      if (parentCommentId != null) {
        commentData['parentComment'] = parentCommentId;
      }

      final Response response = await dio.patch(
        '$baseUrl/comments/$commentId',
        data: commentData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        // Show success toast
        Fluttertoast.showToast(
          msg: "Comment updated successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        final data = response.data;
        final userId = await SharedPref.getUserId();
        final userName = await SharedPref.getUserName() ?? 'Me';

        // Return updated comment object
        return UniversalComment(
          id: data['_id'] as String,
          content: data['content'] as String,
          author: userName,
          userId: userId ?? '',
          timestamp: data['updatedAt'] != null
              ? Timestamp.fromDate(DateTime.parse(data['updatedAt']))
              : Timestamp.now(),
          profileImageUrl: null,
          upvotes: data['upvotes'] as int? ?? 0,
          downvotes: data['downvotes'] as int? ?? 0,
          targetId: data['targetId'] as String? ?? targetId,
          targetType: targetType,
          isReply: data['parentComment'] != null,
          parentCommentId: data['parentComment'] as String?,
          replies: [],
        );
      } else {
        throw Exception('Failed to update comment: ${response.statusMessage}');
      }
    } catch (e) {
      print("Error updating comment: $e");
      Fluttertoast.showToast(
        msg: "Failed to update comment",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      throw Exception('Failed to update comment: $e');
    }
  }

  /// Delete a comment by ID
  Future<void> deleteComment(String commentId) async {
    try {
      print("Deleting comment with ID: $commentId");
      final String? authToken = await getToken();

      final Response response = await dio.delete(
        '$baseUrl/comments/$commentId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        // Show success toast
        Fluttertoast.showToast(
          msg: "Comment deleted successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // Clear all comment count cache since we don't know which target this comment belonged to
        clearAllCommentCountCache();
      } else {
        throw Exception('Failed to delete comment: ${response.statusMessage}');
      }
    } catch (e) {
      print("Error deleting comment: $e");
      Fluttertoast.showToast(
        msg: "Failed to delete comment",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      throw Exception('Failed to delete comment: $e');
    }
  }

  /// Vote on a comment (upvote or downvote)
  Future<Map<String, dynamic>> voteComment(
    String commentId,
    bool isUpvote, {
    required int currentUpvotes,
    required int currentDownvotes,
    required bool currentIsUpvoted,
    required bool currentIsDownvoted,
  }) async {
    try {
      final String? authToken = await getToken();
      if (authToken == null) {
        throw Exception('Authentication required');
      }

      print("=== COMMENT ${isUpvote ? 'UPVOTE' : 'DOWNVOTE'} REQUEST ===");
      print("Comment ID: $commentId");

      final Uri url = Uri.parse('$baseUrl/vote');
      final requestBody = {
        'targetId': commentId,
        'type': isUpvote ? 'upvote' : 'downvote',
        'targetType': 'Comment',
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      print("Vote response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle empty response by calculating votes locally
        if (response.body.isEmpty || response.body.trim().isEmpty) {
          print("Empty response body, calculating votes locally");

          // Calculate new vote counts based on current state
          int newUpvotes = currentUpvotes;
          int newDownvotes = currentDownvotes;
          bool newIsUpvoted = currentIsUpvoted;
          bool newIsDownvoted = currentIsDownvoted;

          if (isUpvote) {
            if (currentIsUpvoted) {
              // Remove upvote
              newUpvotes = currentUpvotes > 0 ? currentUpvotes - 1 : 0;
              newIsUpvoted = false;
            } else {
              // Add upvote
              newUpvotes = currentUpvotes + 1;
              newIsUpvoted = true;
              // Remove downvote if exists
              if (currentIsDownvoted) {
                newDownvotes = currentDownvotes > 0 ? currentDownvotes - 1 : 0;
                newIsDownvoted = false;
              }
            }
          } else {
            if (currentIsDownvoted) {
              // Remove downvote
              newDownvotes = currentDownvotes > 0 ? currentDownvotes - 1 : 0;
              newIsDownvoted = false;
            } else {
              // Add downvote
              newDownvotes = currentDownvotes + 1;
              newIsDownvoted = true;
              // Remove upvote if exists
              if (currentIsUpvoted) {
                newUpvotes = currentUpvotes > 0 ? currentUpvotes - 1 : 0;
                newIsUpvoted = false;
              }
            }
          }

          return {
            'success': true,
            'upvotes': newUpvotes,
            'downvotes': newDownvotes,
            'isUpvoted': newIsUpvoted,
            'isDownvoted': newIsDownvoted,
          };
        } else {
          // Use response data if available
          final responseData = jsonDecode(response.body);
          return {
            'success': true,
            'upvotes': responseData['upvotes'] ?? 0,
            'downvotes': responseData['downvotes'] ?? 0,
            'isUpvoted': responseData['isUpvoted'] ?? false,
            'isDownvoted': responseData['isDownvoted'] ?? false,
          };
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to vote';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Error voting on comment: $e");
      throw Exception('Failed to vote on comment: $e');
    }
  }
}
