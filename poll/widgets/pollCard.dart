import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/services/vote_tracking_service.dart';
import 'package:myunivrs/features/forum/poll/models/pollModel.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/features/forum/poll/widgets/PollComment.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myunivrs/app/app_images.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:myunivrs/features/forum/controller/forum_controller.dart';

class PollCard extends StatefulWidget {
  final Poll poll;
  final Function()? onPollUpdated;
  final Function(List<int>)? onVote;

  const PollCard({
    Key? key,
    required this.poll,
    this.onPollUpdated,
    this.onVote,
  }) : super(key: key);

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  List<int> _selectedOptions = [];
  bool _isLoading = false;
  bool _isVoting = false;
  late Poll _currentPoll;
  late int _commentsCount;
  late bool isFavorited;
  late int upvotes;
  late int downvotes;
  late bool isUpvoted;
  late bool isDownvoted;
  bool _isLoadingVoteStatus = true;
  late ForumController _forumController;

  @override
  void initState() {
    super.initState();
    _currentPoll = widget.poll;
    _commentsCount = widget.poll.comments;
    isFavorited = false;
    upvotes = widget.poll.upvotes;
    downvotes = widget.poll.downvotes;
    isUpvoted = false;
    isDownvoted = false;
    _forumController = Get.find<ForumController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVoteStatus();
      _refreshCommentCount();
      _loadFavoriteStatus();
    });
  }

  @override
  void didUpdateWidget(PollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.comments != widget.poll.comments) {
      setState(() {
        _commentsCount = widget.poll.comments;
      });
    }
    if (oldWidget.poll.upvotes != widget.poll.upvotes ||
        oldWidget.poll.downvotes != widget.poll.downvotes) {
      setState(() {
        upvotes = widget.poll.upvotes;
        downvotes = widget.poll.downvotes;
      });
    }
  }

  // **NEW: Load favorite status**
  Future<void> _loadFavoriteStatus() async {
    try {
      final isSaved = _forumController.isItemSaved(_currentPoll.id);
      if (mounted) {
        setState(() {
          isFavorited = isSaved;
        });
      }
    } catch (e) {
      print('Error loading favorite status: $e');
    }
  }

  // **NEW: Toggle favorite function with API integration**
  Future<void> _toggleFavorite() async {
    if (_currentPoll.id.isEmpty) {
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
        // Remove from favorites
        await _forumController.forumService
            .unsavePost(postId: _currentPoll.id, itemType: 'ForumPoll');
        _forumController.savedPostIds.remove(_currentPoll.id);
      } else {
        // Add to favorites
        await _forumController.forumService
            .savePost(postId: _currentPoll.id, itemType: 'ForumPoll');
        _forumController.savedPostIds.add(_currentPoll.id);
      }

      // Update local state
      setState(() {
        isFavorited = !isFavorited;
      });

      // Refresh saved posts list
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

  Future<void> _initializeVoteStatus() async {
    if (!mounted) return; // Add this check

    setState(() {
      _isLoadingVoteStatus = true;
    });

    try {
      if (!mounted) return;

      setState(() {
        _isLoadingVoteStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingVoteStatus = false;
      });
    }

    try {
      if (await EnhancedVoteTrackingService.needsSync()) {
        print("Syncing poll votes from API...");
        await EnhancedVoteTrackingService.syncUserVotesFromAPI();
      }

      final voteType =
          await EnhancedVoteTrackingService.getVoteStatus(_currentPoll.id);

      if (mounted) {
        setState(() {
          isUpvoted = voteType == VoteType.upvote;
          isDownvoted = voteType == VoteType.downvote;
          _isLoadingVoteStatus = false;
        });

        print("Poll ${_currentPoll.id} vote status: ${voteType.toString()}");
      }
    } catch (e) {
      print('Error initializing poll vote status: $e');
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
        final pollCommentsCount = commentsData
            .where((comment) =>
                comment['targetId'] == _currentPoll.id &&
                comment['targetType'] == 'ForumPoll')
            .length;

        if (mounted) {
          setState(() {
            _commentsCount = pollCommentsCount;
          });
        }
      }
    } catch (e) {
      print('Error refreshing comment count: $e');
    }
  }

  Future<void> _sendVote() async {
    if (_selectedOptions.isEmpty) {
      Fluttertoast.showToast(msg: 'Please select at least one option to vote.');
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

      final requestBody = jsonEncode({
        "poll": _currentPoll.id,
        "selectedOptions": _selectedOptions,
        "pollType": "ForumPoll",
      });

      final response = await http.post(
        Uri.parse('$apiUrl/poll-vote'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Fluttertoast.showToast(msg: "Vote submitted successfully!");
        await _refreshPollData();
        widget.onVote?.call(_selectedOptions);
        setState(() {
          _selectedOptions.clear();
        });
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
        Fluttertoast.showToast(msg: errorMessage);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error voting: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPollData() async {
    final String? authToken = await SharedPref.getToken();
    if (authToken == null || authToken.isEmpty) {
      Fluttertoast.showToast(
          msg: 'Authentication token is missing. Please log in.');
      return;
    }

    try {
      final Uri url = Uri.parse('$apiUrl/forum-poll/all-forum-polls');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> pollsJson = responseData['polls'] ?? [];
        final updatedPollJson = pollsJson.firstWhere(
          (pollJson) => pollJson['_id'] == _currentPoll.id,
          orElse: () => null,
        );

        if (updatedPollJson != null) {
          setState(() {
            _currentPoll = Poll.fromJson(updatedPollJson);
            _commentsCount = _currentPoll.comments;
            upvotes = _currentPoll.upvotes;
            downvotes = _currentPoll.downvotes;
          });
          widget.onPollUpdated?.call();
        } else {
          Fluttertoast.showToast(
              msg: "Could not find the updated poll in the list.");
        }
      } else {
        Fluttertoast.showToast(
            msg: 'Failed to refresh poll data: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error refreshing poll data: $e');
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
      print("=== POLL UPVOTE REQUEST ===");
      print("Poll ID: ${_currentPoll.id}");
      print("Current upvotes: $upvotes");
      print("Current downvotes: $downvotes");
      print("Is upvoted: $isUpvoted");
      print("Is downvoted: $isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': _currentPoll.id,
        'type': 'upvote',
        'targetType': 'ForumPoll',
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

        await EnhancedVoteTrackingService.saveVote(
            _currentPoll.id, isUpvoted ? VoteType.upvote : VoteType.none);

        Fluttertoast.showToast(
          msg:
              isUpvoted ? 'Poll upvoted successfully!' : 'Poll upvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to upvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to upvote poll: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error upvoting poll: $e');
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
      print("=== POLL DOWNVOTE REQUEST ===");
      print("Poll ID: ${_currentPoll.id}");
      print("Current upvotes: $upvotes");
      print("Current downvotes: $downvotes");
      print("Is upvoted: $isUpvoted");
      print("Is downvoted: $isDownvoted");

      final Uri url = Uri.parse('$apiUrl/vote');
      final requestBody = {
        'targetId': _currentPoll.id,
        'type': 'downvote',
        'targetType': 'ForumPoll',
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

        await EnhancedVoteTrackingService.saveVote(
            _currentPoll.id, isDownvoted ? VoteType.downvote : VoteType.none);

        Fluttertoast.showToast(
          msg: isDownvoted
              ? 'Poll downvoted successfully!'
              : 'Poll downvote removed!',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to downvote';
        print("Error: $errorMessage");

        Fluttertoast.showToast(
          msg: 'Failed to downvote poll: $errorMessage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error downvoting poll: $e');
    } finally {
      setState(() {
        _isVoting = false;
      });
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
                  final message = 'Check out this Poll:\n'
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
                  final link = 'https://yourdomain.com/poll/${_currentPoll.id}';
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
                    'Check out this poll: ${_currentPoll.question}\n',
                    subject: 'Poll',
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
          title: const Text('Report Poll'),
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
      await forumService.reportPoll(
        pollId: _currentPoll.id,
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
        builder: (context) => ForumPollCommentScreen(poll: _currentPoll),
      ),
    ).then((_) {
      _refreshPollData();
      _refreshCommentCount();
    });
  }

  String _formatTime(DateTime? dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime!);

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
    if (_currentPoll.author['profileName'] != null &&
        _currentPoll.author['profileName'].toString().isNotEmpty) {
      return _currentPoll.author['profileName'].toString();
    }

    final firstName = _currentPoll.author['firstName']?.toString() ?? '';
    final lastName = _currentPoll.author['lastName']?.toString() ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      return 'Anonymous User';
    }

    return '$firstName $lastName'.trim();
  }

  String? _getAuthorProfilePic() {
    if (_currentPoll.author['profilePic'] != null &&
        _currentPoll.author['profilePic'] is List &&
        (_currentPoll.author['profilePic'] as List).isNotEmpty) {
      return _currentPoll.author['profilePic'][0].toString();
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
                          _showReportDialog(context);
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: _buildVoteButton(),
          ),
          SizedBox(height: height * 0.015),

          // Total Votes
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Row(
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
          ),

          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.03, vertical: height * 0.01),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Clean Poll Upvote Button
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
                    // Clean Poll Downvote Button
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
                InkWell(
                  onTap: _navigateToComments,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: width * 0.02, vertical: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_commentsCount > 0) ...[
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
                      ],
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

  Widget _buildVoteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isLoading || _selectedOptions.isEmpty)
            ? null
            : () {
                _sendVote();
              },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          backgroundColor: Theme.of(context).primaryColor,
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
            : const Text(
                'Submit Vote',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  List<Widget> _buildOptions(BuildContext context) {
    List<Widget> widgets = [];
    for (int i = 0; i < _currentPoll.options.length; i++) {
      final isSelected = _selectedOptions.contains(i);
      final OptionStat? stat = i < _currentPoll.optionStats.length
          ? _currentPoll.optionStats[i]
          : null;
      final double votePercentage = stat?.percentage ?? 0;
      final bool showResultsVisuals = _currentPoll.totalVotes > 0 || isSelected;

      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12.0),
          child: Stack(
            children: [
              if (showResultsVisuals && _currentPoll.totalVotes > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: votePercentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                    width: 1.5,
                  ),
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
                          ),
                        ),
                      ),
                      if (_currentPoll.totalVotes > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${votePercentage.toStringAsFixed(0)}%',
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
                  onChanged: _isLoading
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
