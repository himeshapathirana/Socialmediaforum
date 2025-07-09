// forum_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myunivrs/features/forum/controller/forum_controller.dart';
import 'package:myunivrs/features/forum/models/forum_model.dart';
import 'package:myunivrs/features/forum/screens/SearchScreen.dart';
import 'package:myunivrs/features/forum/screens/forum_create_screen.dart';
import 'package:myunivrs/features/forum/widgets/forum_card.dart';
import 'package:myunivrs/features/housing/widgets/shimmer_housing_card.dart';
import 'package:myunivrs/features/forum/widgets/my_forum_card.dart';
import 'package:myunivrs/features/forum/poll/models/pollModel.dart';
import 'package:myunivrs/features/forum/poll/widgets/MyPollCard.dart';
import 'package:myunivrs/features/forum/poll/widgets/pollCard.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';
import 'package:myunivrs/features/forum/subForum/widgets/MySubForumPollCard.dart';
import 'package:myunivrs/features/forum/subForum/widgets/MySubforumPostCard.dart';
import 'package:myunivrs/features/forum/subForum/widgets/SubForumPollCard.dart';
import 'package:myunivrs/features/forum/subForum/widgets/SubForumPostCard.dart';
import 'dart:async';

import '../../../core/styles/colors.dart';
import '../../../core/utils/custom_button.dart';

class ForumScreen extends StatefulWidget {
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

enum _FeedItemType { poll, subForumPoll, subForumPost, post }

class _FeedItem {
  final _FeedItemType type;
  final dynamic data;
  final DateTime createdAt;

  _FeedItem({
    required this.type,
    required this.data,
    required this.createdAt,
  });
}

class _ForumItem {
  final ForumModel? post;
  final Poll? poll;
  final SubPostModel? subPost;
  final SubPollModel? subPoll;

  _ForumItem.post(this.post)
      : poll = null,
        subPost = null,
        subPoll = null;

  _ForumItem.poll(this.poll)
      : post = null,
        subPost = null,
        subPoll = null;

  _ForumItem.subPost(this.subPost)
      : post = null,
        poll = null,
        subPoll = null;

  _ForumItem.subPoll(this.subPoll)
      : post = null,
        poll = null,
        subPost = null;

  bool get isPost => post != null;
  bool get isPoll => poll != null;
  bool get isSubPost => subPost != null;
  bool get isSubPoll => subPoll != null;
}

class _ForumScreenState extends State<ForumScreen> with WidgetsBindingObserver {
  final ForumController _forumController = Get.find();
  late Widget eventContent;
  late String selectedEventButton;
  final ScrollController _scrollController = ScrollController();
  int currentPage = 1;
  final int itemsPerPage = 10;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  // Auto-reload functionality
  Timer? _autoReloadTimer;
  static const Duration _autoReloadInterval = Duration(minutes: 2);
  bool _isAppInForeground = true;

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPosts();
    _forumController.getPolls();
    _forumController.getSubForumPolls();
    _forumController.getSubForumPosts();
    _forumController.loadAllSavedItems();
    _scrollController.addListener(_onScroll);
    _startAutoReload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        _startAutoReload();
        _performAutoReload();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _isAppInForeground = false;
        _stopAutoReload();
        break;
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        _stopAutoReload();
        break;
    }
  }

  void _startAutoReload() {
    if (_isAppInForeground) {
      _stopAutoReload();
      _autoReloadTimer = Timer.periodic(_autoReloadInterval, (timer) {
        if (_isAppInForeground && mounted) {
          _performAutoReload();
        }
      });
    }
  }

  void _stopAutoReload() {
    _autoReloadTimer?.cancel();
    _autoReloadTimer = null;
  }

  Future<void> _performAutoReload() async {
    if (!mounted || !_isAppInForeground) return;

    try {
      if (selectedEventButton == 'content1') {
        await _performTabRefresh('content1');
      } else if (selectedEventButton == 'content2') {
        await _performTabRefresh('content2');
      } else if (selectedEventButton == 'content3') {
        await _performTabRefresh('content3');
      }
    } catch (e) {
      print('Auto-reload error: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_forumController.hasMore.value) {
        currentPage++;
        _loadPosts();
      }
    }
  }

  Future<void> _loadPosts() async {
    await _forumController.getPosts(currentPage, itemsPerPage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    selectedEventButton = 'content1';
    eventContent = _allForum(context);
  }

  void changeEventContent(String contentId, BuildContext context) {
    setState(() {
      selectedEventButton = contentId;
      if (contentId == 'content1') {
        _performTabRefresh('content1');
        eventContent = _allForum(context);
      } else if (contentId == 'content2') {
        _performTabRefresh('content2');
        eventContent = _manageForum(context);
      } else if (contentId == 'content3') {
        _performTabRefresh('content3');
        eventContent = _bookmarkedForum(context);
      }
    });
  }

  Widget _allForum(BuildContext context) {
    return Obx(() {
      final allItems = <_FeedItem>[];

      allItems.addAll(_forumController.polls.map((poll) => _FeedItem(
            type: _FeedItemType.poll,
            data: poll,
            createdAt: poll.createdAt ?? DateTime.now(),
          )));

      allItems.addAll(_forumController.subForumPolls.map((poll) => _FeedItem(
            type: _FeedItemType.subForumPoll,
            data: poll,
            createdAt: poll.createdAt ?? DateTime.now(),
          )));

      allItems.addAll(_forumController.subForumPosts.map((post) => _FeedItem(
            type: _FeedItemType.subForumPost,
            data: post,
            createdAt: post.createdAt ?? DateTime.now(),
          )));

      allItems.addAll(_forumController.items.map((post) => _FeedItem(
            type: _FeedItemType.post,
            data: post,
            createdAt: post.createdAt ?? DateTime.now(),
          )));

      allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return RefreshIndicator(
        onRefresh: () async {
          currentPage = 1;
          await _forumController.refreshData();
          await _forumController.getPolls();
          await _forumController.getSubForumPosts();
          await _forumController.getSubForumPolls();
          _startAutoReload();
        },
        child:
            _forumController.isLoading.value && _forumController.items.isEmpty
                ? ListView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) => const ShimmerHousingCard(),
                  )
                : _forumController.isError.value
                    ? _buildErrorWidget()
                    : allItems.isEmpty
                        ? _buildEmptyWidget()
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: allItems.length +
                                (_forumController.hasMore.value ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= allItems.length) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final item = allItems[index];

                              switch (item.type) {
                                case _FeedItemType.poll:
                                  final poll = item.data;
                                  return PollCard(
                                    poll: poll,
                                    onVote: (selectedIndices) {
                                      _forumController.voteOnPoll(
                                        pollId: poll.id,
                                        selectedOptionIndices: selectedIndices,
                                      );
                                    },
                                  );

                                case _FeedItemType.subForumPoll:
                                  final subPoll = item.data;
                                  return SubForumPollCard(
                                    poll: subPoll,
                                    onVote: (selectedIndices) {
                                      _forumController.voteOnSubForumPoll(
                                        pollId: subPoll.id!,
                                        selectedOptionIndices: selectedIndices,
                                      );
                                    },
                                  );

                                case _FeedItemType.subForumPost:
                                  final post = item.data;
                                  return SubForumPostCard(
                                    index: index,
                                    post: post,
                                  );

                                case _FeedItemType.post:
                                  final post = item.data;

                                  String profilePic = "";
                                  if (post.author?['profilePic'] is List &&
                                      (post.author?['profilePic'] as List)
                                          .isNotEmpty) {
                                    profilePic = post.author?['profilePic'][0];
                                  }

                                  String postImage = "";
                                  if (post.images != null &&
                                      post.images!.isNotEmpty) {
                                    postImage = post.images![0];
                                  }

                                  String postStatus = "Latest";
                                  if (post.createdAt != null) {
                                    postStatus = _formatDate(post.createdAt!);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ForumCard(
                                      index: index,
                                      profileImageURL: profilePic,
                                      profileName:
                                          "${post.author?['firstName'] ?? ''} ${post.author?['lastName'] ?? ''}"
                                              .trim(),
                                      postStatus: postStatus,
                                      postTitle: post.title ?? "Untitled",
                                      postImageURL: postImage,
                                      likesCount: post.upvotes ?? 0,
                                      commentsCount: post.commentCount ?? 0,
                                      postId: post.id ?? '',
                                      upvotes: post.upvotes ?? 0,
                                      downvotes: post.downvotes ?? 0,
                                    ),
                                  );
                              }
                            },
                          ),
      );
    });
  }

  Widget _manageForum(BuildContext context) {
    return Obx(() {
      final isLoadingPosts = _forumController.isLoading.value &&
          _forumController.userItems.isEmpty;
      final isLoadingPolls = _forumController.isLoadingMyForumPolls.value &&
          _forumController.myForumPolls.isEmpty;
      final isLoadingSubPosts =
          _forumController.isLoadingMySubForumPosts.value &&
              _forumController.mySubForumPosts.isEmpty;
      final isLoadingSubPolls =
          _forumController.isLoadingMySubForumPolls.value &&
              _forumController.mySubForumPolls.isEmpty;

      if (isLoadingPosts ||
          isLoadingPolls ||
          isLoadingSubPosts ||
          isLoadingSubPolls) {
        return ListView.builder(
          itemCount: 4,
          itemBuilder: (context, index) => const ShimmerHousingCard(),
        );
      }

      if (_forumController.isError.value) {
        return _buildErrorWidget();
      }

      if (_forumController.userItems.isEmpty &&
          _forumController.myForumPolls.isEmpty &&
          _forumController.mySubForumPosts.isEmpty &&
          _forumController.mySubForumPolls.isEmpty) {
        return _buildEmptyManageWidget();
      }

      final allItems = <_ForumItem>[];

      allItems.addAll(
          _forumController.userItems.map((post) => _ForumItem.post(post)));

      allItems.addAll(
          _forumController.myForumPolls.map((poll) => _ForumItem.poll(poll)));

      allItems.addAll(_forumController.mySubForumPosts
          .map((subPost) => _ForumItem.subPost(subPost)));

      allItems.addAll(_forumController.mySubForumPolls
          .map((subPoll) => _ForumItem.subPoll(subPoll)));

      allItems.sort((a, b) {
        final aDate = a.isPost
            ? a.post!.createdAt
            : (a.isPoll
                ? a.poll!.createdAt
                : (a.isSubPost ? a.subPost!.createdAt : a.subPoll!.createdAt));
        final bDate = b.isPost
            ? b.post!.createdAt
            : (b.isPoll
                ? b.poll!.createdAt
                : (b.isSubPost ? b.subPost!.createdAt : b.subPoll!.createdAt));
        return bDate?.compareTo(aDate ?? DateTime.now()) ?? 0;
      });

      return RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _forumController.getMyPosts(),
            _forumController.getMyForumPolls(),
            _forumController.getOwnSubForumPosts(),
            _forumController.getMySubForumPolls(),
          ]);
          _startAutoReload();
        },
        child: ListView.builder(
          itemCount: allItems.length,
          itemBuilder: (context, index) {
            final item = allItems[index];

            if (item.isPost) {
              final post = item.post!;
              return MyForumCard(
                index: index,
                postId: post.id ?? '',
                profileImageURL: post.author?['profilePic']
                        ?.firstWhere(
                          (pic) => pic != null,
                          orElse: () => '',
                        )
                        ?.toString() ??
                    '',
                profileName:
                    "${post.author?['firstName'] ?? ''} ${post.author?['lastName'] ?? ''}"
                        .trim(),
                postStatus: post.createdAt != null
                    ? _formatDate(post.createdAt!)
                    : "Latest",
                postTitle: post.title ?? "Untitled",
                postImageURL:
                    post.images?.isNotEmpty == true ? post.images!.first : "",
                likesCount: post.upvotes ?? 0,
                commentsCount: post.commentCount is int
                    ? post.commentCount as int
                    : (post.commentCount is Map
                        ? (post.commentCount as Map<String, dynamic>)['count']
                                as int? ??
                            0
                        : 0),
              );
            } else if (item.isPoll) {
              final poll = item.poll!;
              return MyForumPollCard(
                poll: poll,
                onPollUpdated: _forumController.getMyForumPolls,
                onVote: (selectedOptions) {
                  _forumController.voteOnPoll(
                    pollId: poll.id!,
                    selectedOptionIndices: selectedOptions,
                  );
                },
              );
            } else if (item.isSubPost) {
              final subPost = item.subPost!;
              return MySubforumPostCard(
                index: index,
                post: subPost,
                commentsCount: subPost.commentCountValue,
              );
            } else {
              final subPoll = item.subPoll!;
              return MySubForumPollCard(
                poll: subPoll,
                onPollUpdated: _forumController.getMySubForumPolls,
                onVote: (selectedOptions) {
                  _forumController.voteOnSubForumPoll(
                    pollId: subPoll.id!,
                    selectedOptionIndices: selectedOptions,
                  );
                },
              );
            }
          },
        ),
      );
    });
  }

  // **ENHANCED BOOKMARKED FORUM WITH PROPER SAVED ITEMS DISPLAY**
  Widget _bookmarkedForum(BuildContext context) {
    return Obx(() {
      return RefreshIndicator(
        onRefresh: () async {
          await _forumController.loadAllSavedItems();
          _startAutoReload();
        },
        child: _forumController.isLoading.value
            ? ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => const ShimmerHousingCard(),
              )
            : _forumController.isError.value
                ? _buildErrorWidget()
                : _buildSavedItemsList(),
      );
    });
  }

  // **NEW METHOD TO BUILD SAVED ITEMS LIST WITH PROPER SORTING AND DISPLAY**
  Widget _buildSavedItemsList() {
    // Get all saved items in chronological order (same as All Forums tab)
    List<dynamic> allSavedItems = [];

    // 1. Add saved forum polls first
    final savedForumPolls = _forumController.polls
        .where((poll) => _forumController.isItemSaved(poll.id))
        .toList();
    allSavedItems.addAll(savedForumPolls);

    // 2. Add saved subforum polls
    final savedSubForumPolls = _forumController.subForumPolls
        .where((poll) => _forumController.isItemSaved(poll.id ?? ''))
        .toList();
    allSavedItems.addAll(savedSubForumPolls);

    // 3. Add saved subforum posts
    final savedSubForumPosts = _forumController.subForumPosts
        .where((post) => _forumController.isItemSaved(post.id ?? ''))
        .toList();
    allSavedItems.addAll(savedSubForumPosts);

    // 4. Add saved forum posts
    final savedForumPosts = _forumController.items
        .where((post) => _forumController.isItemSaved(post.id ?? ''))
        .toList();
    allSavedItems.addAll(savedForumPosts);

    if (allSavedItems.isEmpty) {
      return _buildEmptyBookmarkedWidget();
    }

    // Sort by creation date (newest first)
    allSavedItems.sort((a, b) {
      DateTime? aDate;
      DateTime? bDate;

      if (a is Poll) {
        aDate = a.createdAt;
      } else if (a is SubPollModel) {
        aDate = a.createdAt;
      } else if (a is SubPostModel) {
        aDate = a.createdAt;
      } else if (a is ForumModel) {
        aDate = a.createdAt;
      }

      if (b is Poll) {
        bDate = b.createdAt;
      } else if (b is SubPollModel) {
        bDate = b.createdAt;
      } else if (b is SubPostModel) {
        bDate = b.createdAt;
      } else if (b is ForumModel) {
        bDate = b.createdAt;
      }

      return (bDate ?? DateTime.now()).compareTo(aDate ?? DateTime.now());
    });

    return ListView.builder(
      itemCount: allSavedItems.length,
      itemBuilder: (context, index) {
        final item = allSavedItems[index];

        // Render based on item type - same as All Forums tab
        if (item is Poll) {
          return PollCard(
            poll: item,
            onVote: (selectedIndices) {
              _forumController.voteOnPoll(
                pollId: item.id,
                selectedOptionIndices: selectedIndices,
              );
            },
          );
        } else if (item is SubPollModel) {
          return SubForumPollCard(
            poll: item,
            onVote: (selectedIndices) {
              _forumController.voteOnSubForumPoll(
                pollId: item.id!,
                selectedOptionIndices: selectedIndices,
              );
            },
          );
        } else if (item is SubPostModel) {
          return SubForumPostCard(
            index: index,
            post: item,
          );
        } else if (item is ForumModel) {
          String profilePic = "";
          if (item.author?['profilePic'] is List &&
              (item.author?['profilePic'] as List).isNotEmpty) {
            profilePic = item.author?['profilePic'][0];
          }

          String postImage = "";
          if (item.images != null && item.images!.isNotEmpty) {
            postImage = item.images![0];
          }

          String postStatus = "Latest";
          if (item.createdAt != null) {
            postStatus = _formatDate(item.createdAt!);
          }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ForumCard(
              index: index,
              profileImageURL: profilePic,
              profileName:
                  "${item.author?['firstName'] ?? ''} ${item.author?['lastName'] ?? ''}"
                      .trim(),
              postStatus: postStatus,
              postTitle: item.title ?? "Untitled",
              postImageURL: postImage,
              likesCount: item.upvotes ?? 0,
              commentsCount: item.commentCount ?? 0,
              postId: item.id ?? '',
              upvotes: item.upvotes ?? 0,
              downvotes: item.downvotes ?? 0,
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Error loading posts'),
          ElevatedButton(
            onPressed: () {
              _loadPosts();
              _startAutoReload();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No posts or polls available'),
          ElevatedButton(
            onPressed: () {
              _loadPosts();
              _startAutoReload();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyManageWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('You haven\'t created any posts yet'),
          ElevatedButton(
            onPressed: () => Get.to(() => ForumCreation()),
            child: const Text('Create a Post'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBookmarkedWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('You haven\'t saved any posts yet'),
          ElevatedButton(
            onPressed: () => changeEventContent('content1', context),
            child: const Text('Browse Posts'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: lightColorScheme.primary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: width * 0.05),
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              child: Row(
                children: [
                  CustomButton(
                    containercolor: selectedEventButton == 'content1'
                        ? lightColorScheme.primary
                        : Colors.grey[200]!,
                    textcolor: selectedEventButton == 'content1'
                        ? Colors.white
                        : Colors.black,
                    text: "All Forums",
                    onPressed: () {
                      if (selectedEventButton != 'content1') {
                        changeEventContent('content1', context);
                      } else {
                        // If already on this tab, force refresh
                        _performTabRefresh('content1');
                      }
                    },
                    selected: selectedEventButton == 'content1',
                  ),
                  SizedBox(width: width * 0.05),
                  CustomButton(
                    containercolor: selectedEventButton == 'content2'
                        ? lightColorScheme.primary
                        : Colors.grey[200]!,
                    textcolor: selectedEventButton == 'content2'
                        ? Colors.white
                        : Colors.black,
                    text: "Manage",
                    onPressed: () => changeEventContent('content2', context),
                    selected: selectedEventButton == 'content2',
                  ),
                  SizedBox(width: width * 0.05),
                  CustomButton(
                    containercolor: selectedEventButton == 'content3'
                        ? lightColorScheme.primary
                        : Colors.grey[200]!,
                    textcolor: selectedEventButton == 'content3'
                        ? Colors.white
                        : Colors.black,
                    text: "Saved",
                    onPressed: () => changeEventContent('content3', context),
                    selected: selectedEventButton == 'content3',
                  ),
                  SizedBox(width: width * 0.05),
                ],
              ),
            ),
          ),
          // Add the search bar here
          if (_showSearch)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search ...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    borderSide: BorderSide(
                        color: const Color.fromARGB(255, 90, 167, 230),
                        width: 2.0),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleSearch,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                ),
                onChanged: (query) {
                  // Implement search as you type
                },
                onSubmitted: (query) {
                  if (query.isNotEmpty) {
                    _openSearchScreen(query);
                  }
                },
              ),
            ),
          // Add the search button if not showing search bar
          if (!_showSearch)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _toggleSearch,
                ),
              ),
            ),
          Expanded(child: eventContent),
        ],
      ),
    );
  }

  void _handleTabChange(String contentId, BuildContext context) {
    setState(() {
      selectedEventButton = contentId;
      _stopAutoReload();
      _startAutoReload();
      _performTabRefresh(contentId);

      if (contentId == 'content1') {
        eventContent = _allForum(context);
      } else if (contentId == 'content2') {
        eventContent = _manageForum(context);
      } else if (contentId == 'content3') {
        eventContent = _bookmarkedForum(context);
      }
    });
  }

  Future<void> _performTabRefresh(String contentId) async {
    try {
      if (contentId == 'content1') {
        currentPage = 1;
        await Future.wait([
          _forumController.refreshData(),
          _forumController.getPolls(),
          _forumController.getSubForumPosts(),
          _forumController.getSubForumPolls(),
        ]);
      } else if (contentId == 'content2') {
        await Future.wait([
          _forumController.getMyPosts(),
          _forumController.getMyForumPolls(),
          _forumController.getOwnSubForumPosts(),
          _forumController.getMySubForumPolls(),
        ]);
      } else if (contentId == 'content3') {
        await _forumController.loadAllSavedItems();
      }
      // Force UI update after refresh
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Tab refresh error: $e');
      // You might want to show an error message to the user
    }
  }

  void _openSearchScreen(String query) {
    final allItems = <dynamic>[];
    allItems.addAll(_forumController.items);
    allItems.addAll(_forumController.polls);
    allItems.addAll(_forumController.subForumPosts);
    allItems.addAll(_forumController.subForumPolls);

    Get.to(() => ForumSearchScreen(allItems: allItems, searchQuery: query));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoReload();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dateTime) {
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
}
