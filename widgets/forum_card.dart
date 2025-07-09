import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/app/app_images.dart';
import 'package:myunivrs/constants/colors.dart';
import 'package:myunivrs/features/forum/controller/comment_controller.dart';
import 'package:myunivrs/features/forum/controller/forum_controller.dart';
import 'package:myunivrs/features/forum/models/comment.dart';
import 'package:myunivrs/features/forum/models/post.dart';
import 'package:myunivrs/features/forum/screens/Forum_comment_page.dart';
import 'package:myunivrs/features/forum/services/comment_services.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/services/vote_tracking_service.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ForumCard extends StatefulWidget {
  final int? index;
  final String? profileImageURL;
  final String? profileName;
  final String postStatus;
  final String? postTitle;
  final String? postImageURL;
  final int likesCount;
  final int commentsCount;
  final String postId;
  final int upvotes;
  final int downvotes;

  const ForumCard({
    super.key,
    this.index,
    this.profileImageURL,
    this.profileName,
    required this.postStatus,
    this.postTitle,
    this.postImageURL,
    required this.likesCount,
    required this.commentsCount,
    required this.postId,
    this.upvotes = 0,
    this.downvotes = 0,
  });

  @override
  _ForumCardState createState() => _ForumCardState();
}

class _ForumCardState extends State<ForumCard> {
  late int _likesCount;
  late int _commentsCount;
  late int upvotes;
  late int downvotes;
  late bool isUpvoted;
  late bool isDownvoted;
  late bool _isLiked;
  late bool isSaved;
  late UniversalCommentService _commentService;
  late ForumService _forumService;
  late ForumController _forumController;
  bool _isVoting = false;
  bool _isLoadingVoteStatus = true;
  bool _isContentExpanded = false;
  final int _maxContentLength = 150;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.likesCount;
    _commentsCount = widget.commentsCount;
    upvotes = widget.upvotes;
    downvotes = widget.downvotes.abs();
    isUpvoted = false;
    isDownvoted = false;
    _isLiked = false;
    isSaved = false;
    _commentService = UniversalCommentService(Dio());
    _forumService = ForumService(Dio());
    _forumController = Get.find<ForumController>();

    // Initialize vote status immediately
    _initializeVoteStatus();
    _refreshCommentCount();
    _loadSaveStatus();
  }

  @override
  void didUpdateWidget(ForumCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.upvotes != widget.upvotes ||
        oldWidget.downvotes != widget.downvotes) {
      setState(() {
        upvotes = widget.upvotes;
        downvotes = widget.downvotes.abs();
      });
      // Re-initialize vote status when widget updates
      _initializeVoteStatus();
    }
  }

  Future<void> _initializeVoteStatus() async {
    if (!mounted) return;

    try {
      // Force sync if needed
      if (await EnhancedVoteTrackingService.needsSync()) {
        print("Syncing forum votes from API...");
        await EnhancedVoteTrackingService.syncUserVotesFromAPI();
      }

      final voteType =
          await EnhancedVoteTrackingService.getVoteStatus(widget.postId);

      print("=== VOTE STATUS DEBUG ===");
      print("Post ID: ${widget.postId}");
      print("Vote Type from service: ${voteType.toString()}");

      if (mounted) {
        setState(() {
          isUpvoted = voteType == VoteType.upvote;
          isDownvoted = voteType == VoteType.downvote;
          _isLoadingVoteStatus = false;
        });

        print(
            "Updated state - isUpvoted: $isUpvoted, isDownvoted: $isDownvoted");
        print("========================");
      }
    } catch (e) {
      print('Error initializing forum vote status: $e');
      if (mounted) {
        setState(() {
          _isLoadingVoteStatus = false;
        });
      }
    }
  }

  Future<void> _loadSaveStatus() async {
    try {
      if (widget.postId.isNotEmpty) {
        final isSavedStatus = _forumController.isItemSaved(widget.postId);
        if (mounted) {
          setState(() {
            isSaved = isSavedStatus;
          });
        }
      }
    } catch (e) {
      print('Error loading save status: $e');
    }
  }

  Future<void> _toggleSave() async {
    if (widget.postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save post: Missing post ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _forumController.toggleSaveItem(widget.postId, 'ForumPost');

      setState(() {
        isSaved = _forumController.isItemSaved(widget.postId);
      });
    } catch (e) {
      print('Error toggling save: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update favorites'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleUpvote() async {
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
      print("=== FORUM POST UPVOTE REQUEST ===");
      print("Post ID: ${widget.postId}");
      print("Current state - upvotes: $upvotes, isUpvoted: $isUpvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': widget.postId,
        'type': 'upvote',
        'targetType': 'ForumPost',
      };

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
        // Update state first
        setState(() {
          if (isUpvoted) {
            // Remove upvote
            upvotes = upvotes > 0 ? upvotes - 1 : 0;
            isUpvoted = false;
          } else {
            // Add upvote
            upvotes++;
            isUpvoted = true;
            // Remove downvote if exists
            if (isDownvoted) {
              downvotes = downvotes > 0 ? downvotes - 1 : 0;
              isDownvoted = false;
            }
          }
        });

        // Save vote status locally AFTER state update
        await EnhancedVoteTrackingService.saveVote(
            widget.postId, isUpvoted ? VoteType.upvote : VoteType.none);

        print("After upvote - isUpvoted: $isUpvoted, upvotes: $upvotes");

        Fluttertoast.showToast(
          msg: isUpvoted
              ? 'Forum post upvoted successfully!'
              : 'Forum post upvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // Force UI rebuild
        if (mounted) {
          setState(() {});
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to upvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to upvote forum post: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error upvoting forum post: $e');
      Fluttertoast.showToast(
        msg: 'Network error. Please try again.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  Future<void> _handleDownvote() async {
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
      print("=== FORUM POST DOWNVOTE REQUEST ===");
      print("Post ID: ${widget.postId}");
      print("Current state - downvotes: $downvotes, isDownvoted: $isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': widget.postId,
        'type': 'downvote',
        'targetType': 'ForumPost',
      };

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
        setState(() {
          if (isDownvoted) {
            // Remove downvote
            downvotes = downvotes > 0 ? downvotes - 1 : 0;
            isDownvoted = false;
          } else {
            // Add downvote
            downvotes++;
            isDownvoted = true;
            // Remove upvote if exists
            if (isUpvoted) {
              upvotes = upvotes > 0 ? upvotes - 1 : 0;
              isUpvoted = false;
            }
          }
        });

        // Save vote status locally
        await EnhancedVoteTrackingService.saveVote(
            widget.postId, isDownvoted ? VoteType.downvote : VoteType.none);

        print(
            "After downvote - isDownvoted: $isDownvoted, downvotes: $downvotes");

        Fluttertoast.showToast(
          msg: isDownvoted
              ? 'Forum post downvoted successfully!'
              : 'Forum post downvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // Force UI rebuild
        if (mounted) {
          setState(() {});
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to downvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to downvote forum post: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error downvoting forum post: $e');
      Fluttertoast.showToast(
        msg: 'Network error. Please try again.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  Future<void> _refreshCommentCount() async {
    try {
      final int count = await _commentService.getCommentCount(
          widget.postId, CommentTargetType.forumPost);
      if (mounted) {
        setState(() {
          _commentsCount = count;
        });
      }
    } catch (e) {
      print("Error refreshing comment count: $e");
    }
  }

  Future<void> _showShareOptions(BuildContext context) async {
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
                  final message = 'Check out this Forum Post:\n'
                      '📌 ${widget.postTitle}\n';
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
                  final link = 'https://yourdomain.com/forum/${widget.postId}';
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
                    'Check out this forum post: ${widget.postTitle}\n',
                    subject: 'Forum Post',
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: const Text('Report Post',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context);
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
          title: const Text('Report Forum Post'),
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
      await _forumService.reportPost(
        postId: widget.postId,
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

  void _navigateToComments(BuildContext context) {
    print("Navigating to comments for forum post ID: ${widget.postId}");
    if (widget.postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot navigate to comments: Missing post ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final post = Post(
      id: widget.postId,
      title: widget.postTitle ?? '',
      content: '',
      imageUrl:
          widget.postImageURL?.isNotEmpty == true ? widget.postImageURL : null,
      author: widget.profileName ?? 'Anonymous',
      authorProfileImageUrl: widget.profileImageURL,
      comments: [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForumPostCommentScreen(post: post),
      ),
    ).then((_) {
      _refreshCommentCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    final content = widget.postTitle ?? 'Untitled';
    final isContentLong = content.length > _maxContentLength;
    final displayedContent = _isContentExpanded || !isContentLong
        ? content
        : '${content.substring(0, _maxContentLength)}...';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: width * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: widget.index != 0 ? height * 0.0007 : 0,
            color: const Color.fromARGB(83, 158, 158, 158),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.05, vertical: height * 0.02),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: widget.profileImageURL == null ||
                          widget.profileImageURL == ""
                      ? Image.asset(
                          AppImages.imgPerson2,
                          width: width * 0.1,
                          height: width * 0.1,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          widget.profileImageURL!,
                          width: width * 0.1,
                          height: width * 0.1,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              AppImages.imgPerson2,
                              width: width * 0.1,
                              height: width * 0.1,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                ),
                SizedBox(width: width * 0.04),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profileName ?? 'Anonymous',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      widget.postStatus,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(255, 113, 113, 113),
                          fontSize: 12,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Save button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: width * 0.1,
                          height: height * 0.05,
                          decoration: BoxDecoration(
                            color: isSaved
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSaved
                                  ? const Color.fromARGB(255, 88, 170, 238)
                                  : Colors.grey.shade300,
                              width: isSaved ? 1.5 : 1.0,
                            ),
                          ),
                          child: IconButton(
                            onPressed: _toggleSave,
                            splashRadius: 20,
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                isSaved
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                key: ValueKey(isSaved),
                                color: isSaved
                                    ? const Color.fromARGB(255, 85, 158, 218)
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: width * 0.02),
                        Container(
                          width: width * 0.1,
                          height: height * 0.05,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              width: 0.2,
                              color: const Color.fromARGB(85, 158, 158, 158),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'report') {
                                _showReportDialog(context);
                              } else if (value == 'share') {
                                _showShareOptions(context);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem<String>(
                                value: 'share',
                                child: Text('Share'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'report',
                                child: Text('Report',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayedContent,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                if (isContentLong)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isContentExpanded = !_isContentExpanded;
                      });
                    },
                    child: Text(
                      _isContentExpanded ? 'See Less' : 'See More',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 125, 125, 126),
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                SizedBox(height: height * 0.01),
              ],
            ),
          ),
          SizedBox(height: height * 0.01),
          widget.postImageURL == null || widget.postImageURL == ""
              ? const SizedBox.shrink()
              : Image.network(
                  widget.postImageURL!,
                  width: double.infinity,
                  height: height * 0.3,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: height * 0.3,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 50,
                      ),
                    );
                  },
                ),
          // **FIXED VOTE SECTION WITH PROPER STATE MANAGEMENT**
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.03,
              vertical: height * 0.01,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Debug container (remove after testing)
                    if (false) // Set to true for debugging
                      Container(
                        padding: EdgeInsets.all(4),
                        color: Colors.yellow.withOpacity(0.3),
                        child: Text(
                          'UP:$isUpvoted DOWN:$isDownvoted LOAD:$_isLoadingVoteStatus',
                          style: TextStyle(fontSize: 8),
                        ),
                      ),
                    // Clean Forum Upvote Button
                    TextButton(
                      onPressed: (_isVoting || _isLoadingVoteStatus)
                          ? null
                          : _handleUpvote,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoadingVoteStatus)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            )
                          else if (_isVoting && isUpvoted)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            )
                          else
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
                              fontWeight:
                                  isUpvoted ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: width * 0.01),
                    // Clean Forum Downvote Button
                    TextButton(
                      onPressed: (_isVoting || _isLoadingVoteStatus)
                          ? null
                          : _handleDownvote,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoadingVoteStatus)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            )
                          else if (_isVoting && isDownvoted)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            )
                          else
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
                              fontWeight: isDownvoted
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Comment Button
                InkWell(
                  onTap: () => _navigateToComments(context),
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: width * 0.02, vertical: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.grey[600], size: 18),
                        SizedBox(width: width * 0.02),
                        if (_commentsCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '$_commentsCount',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: width * 0.01),
                        ],
                        Text(
                          'Comment',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
