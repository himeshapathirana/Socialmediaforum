import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/app/app_images.dart';
import 'package:myunivrs/features/forum/screens/Forum_comment_page.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/services/vote_tracking_service.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:dio/dio.dart';
import '../models/post.dart';
import 'dart:math' as math;

class PostItem extends StatefulWidget {
  final Post post;
  final VoidCallback onDelete;

  const PostItem({super.key, required this.post, required this.onDelete});

  @override
  _PostItemState createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  int _upvotes = 0;
  int _downvotes = 0;
  bool _isUpvoted = false;
  bool _isDownvoted = false;
  bool isExpanded = false;
  bool isOverflowing = false;
  late ForumService _forumService;
  bool _isVoting = false;
  bool _isLoadingVoteStatus = true;

  @override
  void initState() {
    super.initState();
    _upvotes = widget.post.upvotes ?? 0;
    _downvotes = (widget.post.downvotes ?? 0).abs();
    _isUpvoted = false;
    _isDownvoted = false;
    _forumService = ForumService(Dio());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVoteStatus();
      _refreshPostData();
    });
  }

  // **ENHANCED VOTE STATUS INITIALIZATION**
  Future<void> _initializeVoteStatus() async {
    setState(() {
      _isLoadingVoteStatus = true;
    });

    try {
      // Check if we need to sync votes from API
      if (await EnhancedVoteTrackingService.needsSync()) {
        print("Syncing post item votes from API...");
        await EnhancedVoteTrackingService.syncUserVotesFromAPI();
      }

      // Load vote status from local storage
      final voteType =
          await EnhancedVoteTrackingService.getVoteStatus(widget.post.id);

      if (mounted) {
        setState(() {
          _isUpvoted = voteType == VoteType.upvote;
          _isDownvoted = voteType == VoteType.downvote;
          _isLoadingVoteStatus = false;
        });

        print(
            "Post Item ${widget.post.id} vote status: ${voteType.toString()}");
      }
    } catch (e) {
      print('Error initializing post item vote status: $e');
      if (mounted) {
        setState(() {
          _isLoadingVoteStatus = false;
        });
      }
    }
  }

  // **PERFECT UPVOTE FUNCTION WITH ENHANCED HIGHLIGHTING**
  void _toggleUpvote() async {
    if (_isVoting) return;

    final String? authToken = await SharedPref.getToken();
    if (authToken == null) {
      Fluttertoast.showToast(
        msg: 'Please log in to upvote.',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      print("=== POST ITEM UPVOTE REQUEST ===");
      print("Post ID: ${widget.post.id}");
      print("Current upvotes: $_upvotes");
      print("Current downvotes: $_downvotes");
      print("Is upvoted: $_isUpvoted");
      print("Is downvoted: $_isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': widget.post.id,
        'type': 'upvote',
        'targetType': 'ForumPost',
      };

      print("Request body: $requestBody");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print("Response data: $responseData");

        setState(() {
          if (_isUpvoted) {
            // Remove upvote
            _upvotes = _upvotes > 0 ? _upvotes - 1 : 0;
            _isUpvoted = false;
          } else {
            // Add upvote
            _upvotes++;
            _isUpvoted = true;
            // Remove downvote if exists
            if (_isDownvoted) {
              _downvotes = _downvotes > 0 ? _downvotes - 1 : 0;
              _isDownvoted = false;
            }
          }
        });

        // **ENHANCED: Save vote status locally**
        await EnhancedVoteTrackingService.saveVote(
            widget.post.id, _isUpvoted ? VoteType.upvote : VoteType.none);

        // Update backend with new vote counts
        try {
          await _forumService.updateVotes(
              widget.post.id, _upvotes, _isDownvoted ? -_downvotes : 0);
        } catch (updateError) {
          print(
              "Warning: Failed to update vote counts in backend: $updateError");
        }

        Fluttertoast.showToast(
          msg: _isUpvoted ? 'Post item upvoted!' : 'Upvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to upvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to upvote: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error upvoting post item: $e');
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  // **PERFECT DOWNVOTE FUNCTION WITH ENHANCED HIGHLIGHTING**
  void _toggleDownvote() async {
    if (_isVoting) return;

    final String? authToken = await SharedPref.getToken();
    if (authToken == null) {
      Fluttertoast.showToast(
        msg: 'Please log in to downvote.',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      print("=== POST ITEM DOWNVOTE REQUEST ===");
      print("Post ID: ${widget.post.id}");
      print("Current upvotes: $_upvotes");
      print("Current downvotes: $_downvotes");
      print("Is upvoted: $_isUpvoted");
      print("Is downvoted: $_isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': widget.post.id,
        'type': 'downvote',
        'targetType': 'ForumPost',
      };

      print("Request body: $requestBody");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print("Response data: $responseData");

        setState(() {
          if (_isDownvoted) {
            // Remove downvote
            _downvotes = _downvotes > 0 ? _downvotes - 1 : 0;
            _isDownvoted = false;
          } else {
            // Add downvote
            _downvotes++;
            _isDownvoted = true;
            // Remove upvote if exists
            if (_isUpvoted) {
              _upvotes = _upvotes > 0 ? _upvotes - 1 : 0;
              _isUpvoted = false;
            }
          }
        });

        // **ENHANCED: Save vote status locally**
        await EnhancedVoteTrackingService.saveVote(
            widget.post.id, _isDownvoted ? VoteType.downvote : VoteType.none);

        // Update backend with new vote counts
        try {
          await _forumService.updateVotes(
              widget.post.id, _upvotes, _isDownvoted ? -_downvotes : 0);
        } catch (updateError) {
          print(
              "Warning: Failed to update vote counts in backend: $updateError");
        }

        Fluttertoast.showToast(
          msg: _isDownvoted ? 'Post item downvoted!' : 'Downvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to downvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to downvote: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error downvoting post item: $e');
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  Future<void> _refreshPostData() async {
    try {
      final updatedPost = await _forumService.getUserPosts(widget.post.id);

      if (mounted) {
        setState(() {
          _upvotes = updatedPost.upvotes ?? 0;
          final serverDownvotes = updatedPost.downvotes ?? 0;
          _downvotes = serverDownvotes.abs();
        });
      }
    } catch (e) {
      print('Error refreshing post data: $e');
    }
  }

  void _navigateToComments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ForumPostCommentScreen(post: widget.post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 0.5),
          color: Theme.of(context).cardColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!, width: 0.5),
                bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
              ),
            ),
            child: Column(
              children: [
                // Post header and content
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author info and options
                            Row(
                              children: [
                                // Author avatar
                                CircleAvatar(
                                  backgroundImage: NetworkImage(widget
                                          .post.authorProfileImageUrl ??
                                      'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg?t=st=1725301260~exp=1725304860~hmac=3977e045bf3940139e558222bbeacf8b6bad2314598e51d3f0c61ab80b806904&w=740'),
                                  radius: 12,
                                ),
                                const SizedBox(width: 8),
                                // Author name
                                Text(
                                  widget.post.author,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 4),
                                // Post time
                                Text(
                                  '2h',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 10),
                                ),
                                const Spacer(),
                                // More options button
                                IconButton(
                                  icon: Transform.rotate(
                                    angle: 90 * math.pi / 180,
                                    child:
                                        const Icon(Icons.more_vert, size: 16),
                                  ),
                                  onPressed: () {},
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Post title
                            Text(
                              widget.post.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            // Post image (if available)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (widget.post.imageUrl != null &&
                                      widget.post.imageUrl!.isNotEmpty)
                                  ? Image.network(
                                      widget.post.imageUrl!,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      AppImages.imgEvent1,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            const SizedBox(height: 8),
                            // Post content with expandable text
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final textSpan = TextSpan(
                                  text: widget.post.content,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                );

                                final textPainter = TextPainter(
                                  text: textSpan,
                                  maxLines: 3,
                                  textDirection: TextDirection.ltr,
                                  ellipsis: '...',
                                );

                                textPainter.layout(
                                  minWidth: constraints.minWidth,
                                  maxWidth: constraints.maxWidth,
                                );

                                isOverflowing = textPainter.didExceedMaxLines;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Post content
                                    Text(
                                      widget.post.content,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      maxLines: isExpanded ? null : 3,
                                      overflow: isExpanded
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                    ),
                                    // Show more/less button
                                    if (isOverflowing)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                isExpanded = !isExpanded;
                                              });
                                            },
                                            child: Text(
                                              isExpanded
                                                  ? 'Show less ..'
                                                  : 'Show full post ..',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // **ENHANCED POST ACTIONS WITH PERFECT HIGHLIGHTING**
                Container(
                  constraints: const BoxConstraints(
                    minHeight: 36,
                    maxHeight: 36,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.0, vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Enhanced vote buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Enhanced Upvote button
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: _isUpvoted
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _isUpvoted
                                      ? Colors.green
                                      : Colors.grey.withOpacity(0.3),
                                  width: _isUpvoted ? 2 : 1,
                                ),
                              ),
                              child: TextButton.icon(
                                onPressed: (_isVoting || _isLoadingVoteStatus)
                                    ? null
                                    : _toggleUpvote,
                                icon: _isLoadingVoteStatus
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey),
                                        ),
                                      )
                                    : Icon(
                                        _isUpvoted
                                            ? Icons.arrow_upward
                                            : Icons.arrow_upward_outlined,
                                        color: _isUpvoted
                                            ? Colors.green
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                label: Text(
                                  '$_upvotes',
                                  style: TextStyle(
                                    color:
                                        _isUpvoted ? Colors.green : Colors.grey,
                                    fontWeight: _isUpvoted
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Enhanced Downvote button
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: _isDownvoted
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _isDownvoted
                                      ? Colors.red
                                      : Colors.grey.withOpacity(0.3),
                                  width: _isDownvoted ? 2 : 1,
                                ),
                              ),
                              child: TextButton.icon(
                                onPressed: (_isVoting || _isLoadingVoteStatus)
                                    ? null
                                    : _toggleDownvote,
                                icon: _isLoadingVoteStatus
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey),
                                        ),
                                      )
                                    : Icon(
                                        _isDownvoted
                                            ? Icons.arrow_downward
                                            : Icons.arrow_downward_outlined,
                                        color: _isDownvoted
                                            ? Colors.red
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                label: Text(
                                  '$_downvotes',
                                  style: TextStyle(
                                    color:
                                        _isDownvoted ? Colors.red : Colors.grey,
                                    fontWeight: _isDownvoted
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Comments button
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.mode_comment_outlined,
                                    size: 18),
                                onPressed: _navigateToComments,
                                padding: const EdgeInsets.all(0),
                                constraints: const BoxConstraints(),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '${widget.post.comments?.length ?? 0}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Share button
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share_rounded, size: 18),
                                onPressed: () {},
                                padding: const EdgeInsets.all(0),
                                constraints: const BoxConstraints(),
                              ),
                              GestureDetector(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    'Share',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}
