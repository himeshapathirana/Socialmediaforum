import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/poll/models/pollModel.dart';
import 'package:myunivrs/features/forum/poll/widgets/EditPollScreen.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/features/forum/poll/widgets/PollComment.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myunivrs/app/app_images.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

class MyForumPollCard extends StatefulWidget {
  final Poll poll;
  final Function()? onPollUpdated;
  final Function(List<int>)? onVote;

  const MyForumPollCard({
    Key? key,
    required this.poll,
    this.onPollUpdated,
    this.onVote,
  }) : super(key: key);

  @override
  State<MyForumPollCard> createState() => _MyForumPollCardState();
}

class _MyForumPollCardState extends State<MyForumPollCard> {
  List<int> _selectedOptions = [];
  bool _isLoading = false;
  late Poll _currentPoll;
  late int _commentsCount;
  late bool isFavorited;
  late int upvotes;
  late int downvotes;
  late bool isUpvoted;
  late bool isDownvoted;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCommentCount();
    });
  }

  @override
  void didUpdateWidget(MyForumPollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.comments != widget.poll.comments) {
      setState(() {
        _commentsCount = widget.poll.comments;
      });
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
      final Uri url = Uri.parse('$apiUrl/forum-poll/my-forum-polls');
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
    final String? authToken = await SharedPref.getToken();
    if (authToken == null) {
      Fluttertoast.showToast(msg: 'Please log in to upvote.');
      return;
    }

    try {
      final Uri url = Uri.parse('$apiUrl/vote');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'targetId': _currentPoll.id,
          'type': 'upvote',
          "targetType": "ForumPoll"
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          if (isUpvoted) {
            upvotes--;
            isUpvoted = false;
          } else {
            upvotes++;
            isUpvoted = true;
            if (isDownvoted) {
              downvotes--;
              isDownvoted = false;
            }
          }
        });
        Fluttertoast.showToast(msg: "Upvoted successfully!");
      } else {
        Fluttertoast.showToast(msg: 'Failed to upvote');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error upvoting poll: $e');
    }
  }

  Future<void> _handleDownvote() async {
    final String? authToken = await SharedPref.getToken();
    if (authToken == null) {
      Fluttertoast.showToast(msg: 'Please log in to downvote.');
      return;
    }

    try {
      final Uri url = Uri.parse('$apiUrl/vote');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'targetId': _currentPoll.id,
          'type': 'downvote',
          "targetType": "ForumPoll"
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          if (isDownvoted) {
            downvotes--;
            isDownvoted = false;
          } else {
            downvotes++;
            isDownvoted = true;
            if (isUpvoted) {
              upvotes--;
              isUpvoted = false;
            }
          }
        });
        Fluttertoast.showToast(msg: "Downvoted successfully!");
      } else {
        Fluttertoast.showToast(msg: 'Failed to downvote');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error downvoting poll: $e');
    }
  }

  void _toggleFavorite() {
    setState(() {
      isFavorited = !isFavorited;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Poll ${isFavorited ? 'favorited' : 'unfavorited'}!'),
        duration: const Duration(seconds: 1),
      ),
    );
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
    if (dateTime == null) {
      return 'Just now';
    }

    try {
      DateTime now = DateTime.now();
      Duration difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        List<String> weekdays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        return weekdays[dateTime.weekday - 1];
      }
    } catch (e) {
      return 'Unknown';
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
                        color: Colors.transparent,
                        border: Border.all(
                          width: 0.5,
                          color: const Color.fromARGB(100, 158, 158, 158),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: _toggleFavorite,
                        icon: Icon(
                          isFavorited ? Icons.bookmark : Icons.bookmark_border,
                          color: isFavorited ? Colors.blue : Colors.grey[600],
                          size: 18,
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
                        if (value == 'edit') {
                          _navigateToEditPoll();
                        } else if (value == 'delete') {
                          _showDeleteDialog();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                width * 0.05, 0, width * 0.05, height * 0.015),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: width * 0.03, vertical: height * 0.007),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.poll,
                    size: 14,
                    color: Colors.purple,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Poll',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Column(
              children: _buildOptions(context),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: _buildVoteButton(),
          ),
          SizedBox(height: height * 0.015),
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
                    TextButton(
                      onPressed: _handleUpvote,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: width * 0.01),
                    TextButton(
                      onPressed: _handleDownvote,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: InkWell(
                    onTap: _navigateToComments,
                    borderRadius: BorderRadius.circular(8.0),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: width * 0.02, vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          SizedBox(width: width * 0.02),
                          Text(
                            'Comment',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          if (_commentsCount > 0) ...[
                            SizedBox(width: width * 0.02),
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
                          ],
                        ],
                      ),
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

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Poll'),
        content: const Text('Are you sure you want to delete this poll?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePoll();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePoll() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final forumService = ForumService(Dio());
      await forumService.deleteForumPoll(_currentPoll.id);

      if (mounted) {
        Fluttertoast.showToast(msg: "Poll deleted successfully");
        widget.onPollUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: "Failed to delete poll: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToEditPoll() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPollScreen(poll: _currentPoll),
      ),
    ).then((_) {
      _refreshPollData();
    });
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
