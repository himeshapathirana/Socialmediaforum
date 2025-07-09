import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/app/app_images.dart';
import 'package:myunivrs/features/forum/controller/forum_controller.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/services/vote_tracking_service.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';
import 'package:myunivrs/features/forum/subForum/screens/SubForumComment.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class SubForumPostCard extends StatefulWidget {
  final int index;
  final SubPostModel post;

  const SubForumPostCard({
    Key? key,
    required this.index,
    required this.post,
  }) : super(key: key);

  @override
  _SubForumPostCardState createState() => _SubForumPostCardState();
}

class _SubForumPostCardState extends State<SubForumPostCard> {
  late int upvotes;
  late int downvotes;
  late bool isUpvoted;
  late bool isDownvoted;
  late int commentsCount;
  late bool isSaved;
  late ForumService _forumService;
  late ForumController _forumController;
  bool _isVoting = false;
  bool _isLoadingVoteStatus = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    upvotes = widget.post.upvotes;
    downvotes = widget.post.downvotes.abs();
    commentsCount = widget.post.commentCount;
    isUpvoted = false;
    isDownvoted = false;
    isSaved = false;
    _forumService = ForumService(Dio());
    _forumController = Get.find<ForumController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVoteStatus();
      _refreshCommentCount();
      _loadSaveStatus();
    });
  }

  @override
  void didUpdateWidget(SubForumPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.upvotes != widget.post.upvotes ||
        oldWidget.post.downvotes != widget.post.downvotes) {
      setState(() {
        upvotes = widget.post.upvotes;
        downvotes = widget.post.downvotes.abs();
      });
    }
  }

  // Load save status
  Future<void> _loadSaveStatus() async {
    try {
      if (widget.post.id != null) {
        final isSavedStatus = _forumController.isItemSaved(widget.post.id!);
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

  // Toggle save function with API integration
  Future<void> _toggleSave() async {
    if (widget.post.id == null || widget.post.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save post: Missing post ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (isSaved) {
        await _forumController.forumService
            .unsavePost(postId: widget.post.id!, itemType: 'SubForumPost');
        _forumController.savedPostIds.remove(widget.post.id!);
      } else {
        await _forumController.forumService
            .savePost(postId: widget.post.id!, itemType: 'SubForumPost');
        _forumController.savedPostIds.add(widget.post.id!);
      }

      setState(() {
        isSaved = !isSaved;
      });

      _forumController.savedPostIds.refresh();
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

  // **COPIED FROM POLLCARD: Enhanced vote status initialization**
  Future<void> _initializeVoteStatus() async {
    if (!mounted) return;

    setState(() {
      _isLoadingVoteStatus = true;
    });

    try {
      if (await EnhancedVoteTrackingService.needsSync()) {
        print("Syncing subforum votes from API...");
        await EnhancedVoteTrackingService.syncUserVotesFromAPI();
      }

      final voteType =
          await EnhancedVoteTrackingService.getVoteStatus(widget.post.id!);

      if (mounted) {
        setState(() {
          isUpvoted = voteType == VoteType.upvote;
          isDownvoted = voteType == VoteType.downvote;
          _isLoadingVoteStatus = false;
        });

        print(
            "SubForum Post ${widget.post.id} vote status: ${voteType.toString()}");
      }
    } catch (e) {
      print('Error initializing subforum vote status: $e');
      if (mounted) {
        setState(() {
          _isLoadingVoteStatus = false;
        });
      }
    }
  }

  Future<void> _refreshCommentCount() async {
    try {
      final String? authToken = await SharedPref.getToken();
      if (authToken == null) return;

      final response = await http.get(
        Uri.parse('$apiUrl/comments'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> commentsData = responseData['comments'] ?? [];
        final postCommentsCount = commentsData
            .where((comment) =>
                comment['targetId'] == widget.post.id &&
                comment['targetType'] == 'SubForumPost')
            .length;

        if (mounted) {
          setState(() {
            commentsCount = postCommentsCount;
          });
        }
      }
    } catch (e) {
      print('Error refreshing comment count: $e');
    }
  }

  // **COPIED FROM POLLCARD: Perfect upvote function**
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
      print("=== SUBFORUM UPVOTE REQUEST ===");
      print("Post ID: ${widget.post.id}");
      print("Current upvotes: $upvotes");
      print("Current downvotes: $downvotes");
      print("Is upvoted: $isUpvoted");
      print("Is downvoted: $isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': widget.post.id,
        'type': 'upvote',
        'targetType': 'SubForumPost',
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

        // Save vote status locally
        await EnhancedVoteTrackingService.saveVote(
            widget.post.id!, isUpvoted ? VoteType.upvote : VoteType.none);

        Fluttertoast.showToast(
          msg: isUpvoted
              ? 'SubForum post upvoted successfully!'
              : 'SubForum post upvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to upvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to upvote subforum post: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error upvoting subforum post: $e');
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  // **COPIED FROM POLLCARD: Perfect downvote function**
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
      print("=== SUBFORUM DOWNVOTE REQUEST ===");
      print("Post ID: ${widget.post.id}");
      print("Current upvotes: $upvotes");
      print("Current downvotes: $downvotes");
      print("Is upvoted: $isUpvoted");
      print("Is downvoted: $isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': widget.post.id,
        'type': 'downvote',
        'targetType': 'SubForumPost',
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
            widget.post.id!, isDownvoted ? VoteType.downvote : VoteType.none);

        Fluttertoast.showToast(
          msg: isDownvoted
              ? 'SubForum post downvoted successfully!'
              : 'SubForum post downvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to downvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to downvote subforum post: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error downvoting subforum post: $e');
    } finally {
      setState(() {
        _isVoting = false;
      });
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
                  final message = 'Check out this SubForum Post:\n'
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
                  final link =
                      'https://yourdomain.com/subforum/${widget.post.id}';
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
                    'Check out this subforum post: ${widget.post.title}\n',
                    subject: 'SubForum Post',
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
          title: const Text('Report SubForum Post'),
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
      await _forumService.reportSubForumPost(
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

  void _navigateToComments(BuildContext context) {
    print("Navigating to comments for subforum post ID: ${widget.post.id}");
    if (widget.post.id == null || widget.post.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot navigate to comments: Missing post ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubForumPostCommentScreen(post: widget.post),
      ),
    ).then((_) {
      _refreshCommentCount();
    });
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Just now';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String _getAuthorName() {
    if (widget.post.author != null) {
      final firstName = widget.post.author.firstName?.toString() ?? '';
      final lastName = widget.post.author.lastName?.toString() ?? '';

      if (firstName.isEmpty && lastName.isEmpty) {
        return 'Anonymous User';
      }

      return '$firstName $lastName'.trim();
    }
    return 'Anonymous User';
  }

  String? _getAuthorProfilePic() {
    if (widget.post.author != null &&
        widget.post.author.profilePic != null &&
        widget.post.author.profilePic is List &&
        (widget.post.author.profilePic as List).isNotEmpty) {
      return widget.post.author.profilePic![0].toString();
    }
    return null;
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
          // Header with profile info and actions
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.04, vertical: height * 0.02),
            child: Row(
              children: [
                // Profile picture
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _getAuthorProfilePic() == null ||
                          _getAuthorProfilePic()!.isEmpty
                      ? Image.asset(
                          AppImages.imgPerson2,
                          width: width * 0.1,
                          height: width * 0.1,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          _getAuthorProfilePic()!,
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
                // Author name and timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getAuthorName(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(widget.post.createdAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(255, 113, 113, 113),
                          fontSize: 12,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Save button
                    Container(
                      width: width * 0.1,
                      height: height * 0.05,
                      decoration: BoxDecoration(
                        color: isSaved
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border.all(
                          width: isSaved ? 1.5 : 0.2,
                          color: isSaved
                              ? Colors.blue
                              : const Color.fromARGB(85, 158, 158, 158),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: _toggleSave,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            key: ValueKey(isSaved),
                            color: isSaved ? Colors.blue : Colors.grey,
                            size: isSaved ? 22 : 20,
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
              ],
            ),
          ),

          // Category badge
          if (widget.post.category != null && widget.post.category!.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.04),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.03,
                  vertical: height * 0.005,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  widget.post.category!,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          SizedBox(height: height * 0.01),

          // Post title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.04),
            child: Text(
              widget.post.title ?? 'Untitled',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ),

          // Post content
          // Post content with See More functionality
          if (widget.post.content != null && widget.post.content!.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.04,
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
                  if (widget.post.content!.length >
                      100) // Only show "See More" if content is long enough
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

          // Post image
          if (widget.post.images != null && widget.post.images!.isNotEmpty)
            Image.network(
              widget.post.images!.first,
              width: double.infinity,
              height: height * 0.25,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: height * 0.25,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 50,
                  ),
                );
              },
            ),

          // **COPIED FROM POLLCARD: Clean vote section with enhanced design**
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
                      // Clean SubForum Upvote Button
                      TextButton(
                        onPressed: (_isVoting || _isLoadingVoteStatus)
                            ? null
                            : _handleUpvote,
                        style: TextButton.styleFrom(
                          padding:
                              EdgeInsets.symmetric(horizontal: width * 0.02),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey),
                                ),
                              )
                            else if (_isVoting && isUpvoted)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green),
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
                                fontWeight: isUpvoted
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: width * 0.01),
                      // Clean SubForum Downvote Button
                      TextButton(
                        onPressed: (_isVoting || _isLoadingVoteStatus)
                            ? null
                            : _handleDownvote,
                        style: TextButton.styleFrom(
                          padding:
                              EdgeInsets.symmetric(horizontal: width * 0.02),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey),
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
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (commentsCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
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
                                '$commentsCount',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: width * 0.01),
                          ],
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          SizedBox(width: width * 0.01),
                          Text(
                            'Comment',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ]),
                      ))
                ],
              ))
        ],
      ),
    );
    ;
  }
}
