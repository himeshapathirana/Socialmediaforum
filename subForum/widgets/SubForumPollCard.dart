import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/services/vote_tracking_service.dart';
import 'package:myunivrs/features/forum/controller/forum_controller.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:myunivrs/features/forum/subForum/screens/SubForumPollComment.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:myunivrs/app/app_images.dart';
import 'package:myunivrs/api/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SubForumPollCard extends StatefulWidget {
  final SubPollModel poll;
  final Function()? onPollUpdated;
  final Function(List<int>)? onVote;

  const SubForumPollCard({
    Key? key,
    required this.poll,
    this.onPollUpdated,
    this.onVote,
  }) : super(key: key);

  @override
  State<SubForumPollCard> createState() => _SubForumPollCardState();
}

class _SubForumPollCardState extends State<SubForumPollCard> {
  List<int> _selectedOptions = [];
  bool _isLoading = false;
  bool _isVoting = false;
  late SubPollModel _currentPoll;
  late bool isFavorited;
  late int upvotes;
  late int downvotes;
  late bool isUpvoted;
  late bool isDownvoted;
  late int commentsCount;
  bool _isLoadingVoteStatus = true;
  late ForumController _forumController;

  @override
  void initState() {
    super.initState();
    _currentPoll = widget.poll;
    isFavorited = false;
    upvotes = widget.poll.upvotes;
    downvotes = widget.poll.downvotes.abs();
    isUpvoted = false;
    isDownvoted = false;
    commentsCount = widget.poll.comments;
    _forumController = Get.find<ForumController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVoteStatus();
      _refreshCommentCount();
      _loadFavoriteStatus();
    });
  }

  @override
  void didUpdateWidget(SubForumPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll != widget.poll) {
      setState(() {
        _currentPoll = widget.poll;
        upvotes = widget.poll.upvotes;
        downvotes = widget.poll.downvotes.abs();
        commentsCount = widget.poll.comments;
      });
    }
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      if (_currentPoll.id != null) {
        final isSaved = _forumController.isItemSaved(_currentPoll.id!);
        if (mounted) {
          setState(() {
            isFavorited = isSaved;
          });
        }
      }
    } catch (e) {
      print('Error loading favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentPoll.id == null || _currentPoll.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save poll: Missing poll ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      if (isFavorited) {
        await _forumController.forumService
            .unsavePost(postId: _currentPoll.id!, itemType: 'SubForumPoll');
        _forumController.savedPostIds.remove(_currentPoll.id!);
      } else {
        await _forumController.forumService
            .savePost(postId: _currentPoll.id!, itemType: 'SubForumPoll');
        _forumController.savedPostIds.add(_currentPoll.id!);
      }

      setState(() {
        isFavorited = !isFavorited;
      });

      _forumController.savedPostIds.refresh();
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update favorites'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // **COPIED FROM SUBFORUMPOSTCARD: Enhanced vote status initialization**
  Future<void> _initializeVoteStatus() async {
    setState(() {
      _isLoadingVoteStatus = true;
    });

    try {
      if (await EnhancedVoteTrackingService.needsSync()) {
        print("Syncing subforum poll votes from API...");
        await EnhancedVoteTrackingService.syncUserVotesFromAPI();
      }

      final voteType =
          await EnhancedVoteTrackingService.getVoteStatus(_currentPoll.id!);

      if (mounted) {
        setState(() {
          isUpvoted = voteType == VoteType.upvote;
          isDownvoted = voteType == VoteType.downvote;
          _isLoadingVoteStatus = false;
        });

        print(
            "SubForum Poll ${_currentPoll.id} vote status: ${voteType.toString()}");
      }
    } catch (e) {
      print('Error initializing subforum poll vote status: $e');
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
      if (authToken == null || _currentPoll.id == null) return;

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
        final pollCommentsCount = commentsData
            .where((comment) =>
                comment['targetId'] == _currentPoll.id &&
                comment['targetType'] == 'SubForumPoll')
            .length;

        if (mounted) {
          setState(() {
            commentsCount = pollCommentsCount;
          });
        }
      }
    } catch (e) {
      print('Error refreshing comment count: $e');
    }
  }

  // **COPIED FROM SUBFORUMPOSTCARD: Perfect upvote function**
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
      print("=== SUBFORUM POLL UPVOTE REQUEST ===");
      print("Poll ID: ${_currentPoll.id}");
      print("Current upvotes: $upvotes");
      print("Current downvotes: $downvotes");
      print("Is upvoted: $isUpvoted");
      print("Is downvoted: $isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': _currentPoll.id,
        'type': 'upvote',
        'targetType': 'SubForumPoll',
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
            _currentPoll.id!, isUpvoted ? VoteType.upvote : VoteType.none);

        Fluttertoast.showToast(
          msg: isUpvoted
              ? 'SubForum poll upvoted successfully!'
              : 'SubForum poll upvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to upvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to upvote subforum poll: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error upvoting subforum poll: $e');
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  // **COPIED FROM SUBFORUMPOSTCARD: Perfect downvote function**
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
      print("=== SUBFORUM POLL DOWNVOTE REQUEST ===");
      print("Poll ID: ${_currentPoll.id}");
      print("Current upvotes: $upvotes");
      print("Current downvotes: $downvotes");
      print("Is upvoted: $isUpvoted");
      print("Is downvoted: $isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': _currentPoll.id,
        'type': 'downvote',
        'targetType': 'SubForumPoll',
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
            _currentPoll.id!, isDownvoted ? VoteType.downvote : VoteType.none);

        Fluttertoast.showToast(
          msg: isDownvoted
              ? 'SubForum poll downvoted successfully!'
              : 'SubForum poll downvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to downvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to downvote subforum poll: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error downvoting subforum poll: $e');
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  // **FIXED VOTE FUNCTION WITH PROPER VALIDATION AND REFRESH**
  Future<void> _sendVote() async {
    if (_selectedOptions.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please select at least one option to vote.',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (_currentPoll.id == null) {
      Fluttertoast.showToast(
        msg: 'Error: Poll ID is missing',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String? authToken = await SharedPref.getToken();
      if (authToken == null) {
        throw Exception('Authentication token is missing');
      }

      // Store selected options before clearing
      final List<int> votedOptions = List.from(_selectedOptions);

      final requestBody = jsonEncode({
        "poll": _currentPoll.id!,
        "selectedOptions": votedOptions,
        "pollType": "SubForumPoll",
      });

      print("Sending SubForum poll vote request:");
      print("URL: $apiUrl/poll-vote");
      print("Body: $requestBody");
      print("Selected options: $votedOptions");

      final response = await http.post(
        Uri.parse('$apiUrl/poll-vote'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: requestBody,
      );

      print("Vote response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Show success message
        Fluttertoast.showToast(
          msg: "SubForum poll vote submitted successfully!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // Clear selections immediately to prevent double voting
        setState(() {
          _selectedOptions.clear();
        });

        // Wait a bit before refreshing to allow backend to process
        await Future.delayed(const Duration(milliseconds: 500));

        // Refresh the poll data
        await _forumController.getSubForumPolls();

        // Find and update the current poll from the refreshed list
        final updatedPolls = _forumController.subForumPolls;
        final updatedPoll = updatedPolls.firstWhere(
          (poll) => poll.id == _currentPoll.id,
          orElse: () => _currentPoll,
        );

        if (mounted) {
          setState(() {
            _currentPoll = updatedPoll;
          });

          print("Poll updated - Total votes: ${_currentPoll.totalVotes}");
          print(
              "Option stats: ${_currentPoll.optionStats.map((stat) => '${stat.option}: ${stat.count} (${stat.percentage}%)').join(', ')}");
        }

        // Call callbacks
        widget.onVote?.call(votedOptions);
        widget.onPollUpdated?.call();
      } else {
        String errorMessage = 'Failed to vote: ${response.statusCode}';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          if (errorData.containsKey('message')) {
            errorMessage += '\n${errorData['message']}';
          }
        } catch (e) {
          errorMessage += '\n${response.body}';
        }
        Fluttertoast.showToast(
          msg: errorMessage,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error voting on SubForum poll: $e');
      Fluttertoast.showToast(
        msg: 'Error voting: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                  final message = 'Check out this SubForum Poll:\n'
                      '📊 ${_currentPoll.question}\n';
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
                      'https://myunivrs.com/subforum-poll/${_currentPoll.id}';
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
                    'Check out this subforum poll: ${_currentPoll.question}\n',
                    subject: 'SubForum Poll',
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: const Text('Report Poll',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReportDialog() async {
    String? selectedReason;
    final TextEditingController otherReasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report SubForum Poll'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Please select a reason for reporting this poll:'),
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
      await forumService.reportSubForumPoll(
        pollId: _currentPoll.id!,
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
        builder: (context) => SubForumPollCommentScreen(poll: _currentPoll),
      ),
    ).then((_) {
      _forumController.getSubForumPolls();
      _refreshCommentCount();
    });
  }

  String _formatTime(DateTime dateTime) {
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
    if (_currentPoll.author.profileName != null &&
        _currentPoll.author.profileName!.isNotEmpty) {
      return _currentPoll.author.profileName!;
    }

    final firstName = _currentPoll.author.firstName ?? '';
    final lastName = _currentPoll.author.lastName ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      return 'Anonymous User';
    }

    return '$firstName $lastName'.trim();
  }

  String? _getAuthorProfilePic() {
    if (_currentPoll.author.profilePic != null &&
        _currentPoll.author.profilePic!.isNotEmpty) {
      return _currentPoll.author.profilePic![0];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

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
          // Header Section
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.05, vertical: height * 0.02),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _getAuthorProfilePic() == null ||
                          _getAuthorProfilePic()!.isEmpty
                      ? Image.asset(
                          AppImages.imgPerson2,
                          width: width * 0.12,
                          height: width * 0.12,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          _getAuthorProfilePic()!,
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
                        _getAuthorName(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: height * 0.003),
                      Text(
                        _formatTime(_currentPoll.createdAt),
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
                        color: isFavorited
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border.all(
                          width: isFavorited ? 1.5 : 0.5,
                          color: isFavorited
                              ? Colors.blue
                              : const Color.fromARGB(100, 158, 158, 158),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: _toggleFavorite,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            isFavorited
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            key: ValueKey(isFavorited),
                            color: isFavorited ? Colors.blue : Colors.grey[600],
                            size: isFavorited ? 20 : 18,
                          ),
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
                        if (value == 'share') {
                          _showShareOptions();
                        } else if (value == 'report') {
                          _showReportDialog();
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
                  ],
                ),
              ],
            ),
          ),

          // Category and Poll Badge
          Padding(
            padding: EdgeInsets.fromLTRB(
                width * 0.05, 0, width * 0.05, height * 0.015),
            child: Row(
              children: [
                if (_currentPoll.category != null &&
                    _currentPoll.category!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: width * 0.03, vertical: height * 0.007),
                    margin: EdgeInsets.only(right: width * 0.02),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 1, 213, 250)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _currentPoll.category!,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 99, 99, 99),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Poll Question
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Text(
              _currentPoll.question,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
          SizedBox(height: height * 0.015),

          // Poll Options
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Column(
              children: _buildOptions(context),
            ),
          ),

          // Vote Button
          if (!_currentPoll.isClosed)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.05),
              child: _buildVoteButton(),
            ),
          SizedBox(height: height * 0.015),

          // Total Votes and Status
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.how_to_vote_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Total votes: ${_currentPoll.totalVotes}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: width * 0.03, vertical: height * 0.005),
                  decoration: BoxDecoration(
                    color: _currentPoll.isClosed
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentPoll.isClosed ? 'Closed' : 'Active',
                    style: TextStyle(
                      color: _currentPoll.isClosed ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // **COPIED FROM SUBFORUMPOSTCARD: Clean vote section with enhanced design**
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
                      // Clean SubForum Poll Upvote Button
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
                              ColorFiltered(
                                colorFilter: ColorFilter.mode(
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
                      // Clean SubForum Poll Downvote Button
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
                              ColorFiltered(
                                colorFilter: ColorFilter.mode(
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
                      onTap: _navigateToComments,
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
  }

  // **ENHANCED VOTE BUTTON WITH BETTER VALIDATION**
  Widget _buildVoteButton() {
    final bool hasSelections = _selectedOptions.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isLoading || !hasSelections) ? null : _sendVote,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          backgroundColor:
              hasSelections ? Theme.of(context).primaryColor : Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                hasSelections
                    ? 'Submit Vote (${_selectedOptions.length} selected)'
                    : 'Select an option to vote',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  // **ENHANCED OPTIONS WITH BETTER VISUAL FEEDBACK**
  List<Widget> _buildOptions(BuildContext context) {
    List<Widget> widgets = [];
    for (int i = 0; i < _currentPoll.options.length; i++) {
      final isSelected = _selectedOptions.contains(i);
      final OptionStat? stat = i < _currentPoll.optionStats.length
          ? _currentPoll.optionStats[i]
          : null;
      final double votePercentage = stat?.percentage ?? 0;
      final int voteCount = stat?.count ?? 0;
      final bool showResults = _currentPoll.totalVotes > 0;

      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12.0),
          child: Stack(
            children: [
              // Progress bar background
              if (showResults && votePercentage > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: votePercentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: CheckboxListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _currentPoll.options[i],
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 14,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (showResults)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${votePercentage.toStringAsFixed(1)}% ($voteCount)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  value: isSelected,
                  onChanged: (_isLoading || _currentPoll.isClosed)
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              if (_currentPoll.allowMultipleAnswers) {
                                _selectedOptions.add(i);
                              } else {
                                _selectedOptions = [i];
                              }
                            } else {
                              _selectedOptions.remove(i);
                            }
                          });
                          print("Selected options: $_selectedOptions");
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 4.0,
                  ),
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}
