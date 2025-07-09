import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:intl/intl.dart';
import 'package:myunivrs/app/app_images.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/subForum/screens/SubForumPollComment.dart';
import 'package:myunivrs/features/forum/subForum/widgets/EditSubforumPoll.dart';

class MySubForumPollCard extends StatefulWidget {
  final SubPollModel poll;
  final Function()? onPollUpdated;
  final Function(List<int>)? onVote;

  const MySubForumPollCard({
    Key? key,
    required this.poll,
    this.onPollUpdated,
    this.onVote,
  }) : super(key: key);

  @override
  State<MySubForumPollCard> createState() => _MySubForumPollCardState();
}

class _MySubForumPollCardState extends State<MySubForumPollCard> {
  List<int> _selectedOptions = [];
  bool _isLoading = false;
  late SubPollModel _currentPoll;
  late bool isFavorited;
  late int upvotes;
  late int downvotes;
  late bool isUpvoted;
  late bool isDownvoted;
  bool isAuthor = false;
  late int commentsCount;
  late ForumService _forumService;

  @override
  void initState() {
    super.initState();
    _currentPoll = widget.poll;
    isFavorited = false;
    upvotes = widget.poll.upvotes;
    downvotes = widget.poll.downvotes;
    commentsCount = widget.poll.comments ?? 0;
    _forumService = ForumService(Dio());
    isUpvoted = false;
    isDownvoted = false;
    _refreshCommentCount();
    _checkIfAuthor();
  }

  Future<void> _checkIfAuthor() async {
    final currentUserId =
        await SharedPref.getUserId(); // Assuming this method exists
    if (currentUserId != null) {
      setState(() {
        isAuthor = currentUserId == _currentPoll.author.id;
      });
    }
  }

  Future<void> _refreshCommentCount() async {
    try {
      final String? authToken = await SharedPref.getToken();
      if (authToken == null) return;

      final response = await Dio().get(
        '$apiUrl/comments',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        final List<dynamic> commentsData = responseData['comments'] ?? [];
        final pollCommentsCount = commentsData
            .where((comment) =>
                comment['targetId'] == widget.poll.id &&
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
      // Set a default value if there's an error
      if (mounted) {
        setState(() {
          commentsCount = widget.poll.comments ?? 0;
        });
      }
    }
  }

  // Add this method to navigate to comments
  void _navigateToComments(BuildContext context) {
    if (_currentPoll.id == null || _currentPoll.id!.isEmpty) {
      Fluttertoast.showToast(
          msg: 'Cannot navigate to comments: Missing poll ID');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubForumPollCommentScreen(poll: _currentPoll),
      ),
    ).then((_) {
      _refreshCommentCount(); // Refresh count when returning from comments
    });
  }

  Future<void> _sendVote() async {
    if (_selectedOptions.isEmpty) {
      Fluttertoast.showToast(msg: 'Please select at least one option to vote.');
      return;
    }

    if (_currentPoll.id == null) {
      Fluttertoast.showToast(msg: 'Error: Poll ID is missing');
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

      final response = await Dio().post(
        '$apiUrl/sub-forum-poll/vote',
        data: {
          "pollId": _currentPoll.id!,
          "selectedOptions": _selectedOptions,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
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
        if (response.data != null && response.data['message'] != null) {
          errorMessage += '\n${response.data['message']}';
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

    if (_currentPoll.id == null) {
      Fluttertoast.showToast(msg: 'Error: Poll ID is missing');
      return;
    }

    try {
      final response = await Dio().get(
        '$apiUrl/sub-forum-poll/${_currentPoll.id}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentPoll = SubPollModel.fromJson(response.data['poll']);
          upvotes = _currentPoll.upvotes;
          downvotes = _currentPoll.downvotes;
        });
        widget.onPollUpdated?.call();
      } else {
        Fluttertoast.showToast(msg: "Failed to refresh poll data");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error refreshing poll data: $e');
    }
  }

  Future<void> _handleUpvote() async {
    if (_currentPoll.id == null) {
      Fluttertoast.showToast(msg: 'Error: Poll ID is missing');
      return;
    }

    final String? authToken = await SharedPref.getToken();
    if (authToken == null) {
      Fluttertoast.showToast(msg: 'Please log in to upvote.');
      return;
    }

    try {
      final response = await Dio().post(
        '$apiUrl/sub-forum-poll/upvote',
        data: {
          'pollId': _currentPoll.id!,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
          },
        ),
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
    if (_currentPoll.id == null) {
      Fluttertoast.showToast(msg: 'Error: Poll ID is missing');
      return;
    }

    final String? authToken = await SharedPref.getToken();
    if (authToken == null) {
      Fluttertoast.showToast(msg: 'Please log in to downvote.');
      return;
    }

    try {
      final response = await Dio().post(
        '$apiUrl/sub-forum-poll/downvote',
        data: {
          'pollId': _currentPoll.id!,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
          },
        ),
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

  Future<void> _deletePoll() async {
    try {
      final forumService = ForumService(Dio());
      await forumService.deleteSubForumPoll(_currentPoll.id!);
      widget.onPollUpdated?.call();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to delete poll: $e');
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

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'Just now';

    try {
      final now = DateTime.now().toUtc();
      final utcDate = dateTime.toUtc();
      var difference = now.difference(utcDate);

      // If difference is negative (server time ahead of device)
      if (difference.isNegative) {
        debugPrint('Negative difference detected. Using absolute value.');
        difference = difference.abs();

        // If discrepancy is more than 1 hour, assume device time is wrong
        if (difference.inHours > 1) {
          return 'Recently';
        }
      }

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(dateTime.toLocal());
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return '';
    }
  }

  void checkTimeSync() async {
    final deviceTime = DateTime.now().toUtc();
    try {
      final response = await Dio().get('https://worldtimeapi.org/api/ip');
      final networkTime = DateTime.parse(response.data['utc_datetime']);
      final difference = deviceTime.difference(networkTime).abs();

      if (difference.inMinutes > 5) {
        debugPrint(
            'WARNING: Device time is off by ${difference.inMinutes} minutes');
        // Consider showing a warning to user
      }
    } catch (e) {
      debugPrint('Could not verify time sync: $e');
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
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: width * 0.05, vertical: height * 0.02),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _currentPoll.author.profilePic == null
                      ? Image.asset(
                          AppImages.imgPerson2,
                          width: width * 0.12,
                          height: width * 0.12,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          _currentPoll.author.profilePic!,
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
                    if (isAuthor)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditSubForumPoll(poll: _currentPoll),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _refreshPollData();
                                widget.onPollUpdated?.call();
                              }
                            });
                          } else if (value == 'delete') {
                            _deletePoll();
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
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
            child: Row(
              children: [
                if (_currentPoll.category != null &&
                    _currentPoll.category!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: width * 0.03, vertical: height * 0.007),
                    margin: EdgeInsets.only(right: width * 0.02),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _currentPoll.category!,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: width * 0.03, vertical: height * 0.007),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 39, 181, 206)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.poll,
                        size: 14,
                        color: const Color.fromARGB(255, 37, 196, 207),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Poll',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 35, 196, 218),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Text(
              _currentPoll.question,
              style: TextStyle(
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
          if (!_currentPoll.isClosed)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.05),
              child: _buildVoteButton(),
            ),
          SizedBox(height: height * 0.015),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: width * 0.03, vertical: height * 0.007),
                  decoration: BoxDecoration(
                    color: _currentPoll.isClosed
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _currentPoll.isClosed ? 'Closed' : 'Active',
                    style: TextStyle(
                      color: _currentPoll.isClosed ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.how_to_vote_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${_currentPoll.totalVotes} votes',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                InkWell(
                  onTap: () => _navigateToComments(context),
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: width * 0.02, vertical: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((commentsCount ?? 0) > 0) ...[
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

  Widget _buildVoteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isLoading || _selectedOptions.isEmpty) ? null : _sendVote,
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
