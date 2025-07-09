// screens/forum_search_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:myunivrs/features/forum/controller/SearchController.dart';
import 'package:myunivrs/features/forum/models/forum_model.dart';
import 'package:myunivrs/features/forum/widgets/forum_card.dart';
import 'package:myunivrs/features/forum/poll/models/pollModel.dart';
import 'package:myunivrs/features/forum/poll/widgets/pollCard.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';
import 'package:myunivrs/features/forum/subForum/widgets/SubForumPollCard.dart';
import 'package:myunivrs/features/forum/subForum/widgets/SubForumPostCard.dart';

class ForumSearchScreen extends StatefulWidget {
  final List<dynamic> allItems;
  final String searchQuery;

  const ForumSearchScreen({
    super.key,
    required this.allItems,
    required this.searchQuery,
  });

  @override
  State<ForumSearchScreen> createState() => _ForumSearchScreenState();
}

class _ForumSearchScreenState extends State<ForumSearchScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _textController = TextEditingController(text: widget.searchQuery);

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ForumSearchController searchController = Get.put(
      ForumSearchController(),
      tag: 'forumSearch',
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: theme.primaryColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _textController,
            autofocus: true,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Search posts, polls, and discussions...',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                size: 22,
              ),
              suffixIcon: Obx(() => searchController.searchQuery.isNotEmpty
                  ? Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        onPressed: () {
                          _textController.clear();
                          searchController.clearSearch();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    )
                  : const SizedBox.shrink()),
            ),
            onChanged: (query) {
              searchController.setSearchQuery(query);
              searchController.searchFeed(widget.allItems);
            },
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Obx(() {
            if (searchController.isSearching) {
              return _buildLoadingWidget(isDark);
            }

            if (searchController.searchQuery.isEmpty) {
              return _buildEmptySearchWidget(isDark);
            }

            if (searchController.searchResults.isEmpty) {
              return _buildNoResultsWidget(
                  searchController.searchQuery, isDark);
            }

            return _buildSearchResults(searchController, isDark);
          }),
        ),
      ),
    );
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

  Widget _buildSearchResults(
      ForumSearchController searchController, bool isDark) {
    return Column(
      children: [
        // Add category chips here
        _buildCategoryChips(searchController, isDark),

        // Existing results header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.filter_list_rounded, size: 18),
              SizedBox(width: 8),
              Text('${searchController.searchResults.length} results'),
              Spacer(),
              if (searchController.selectedCategories.isNotEmpty)
                Text(
                  'in ${searchController.selectedCategories.join(', ')}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
        // Results list
        Expanded(
          child: ListView.separated(
            itemCount: searchController.searchResults.length,
            itemBuilder: (context, index) {
              final item = searchController.searchResults[index];
              return _buildSearchResultItem(item, index);
            },
            separatorBuilder: (context, index) => Divider(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(
      ForumSearchController searchController, bool isDark) {
    final categories = [
      'General',
      'Academics',
      'Events',
      'Announcements',
      'Discussions',
      'Campus Life',
      'Sports & Recreation',
      'Lost & Found',
      'IT Help',
      'Research',
      'Student Organizations',
      'Careers',
      'Off-Topic',
      'Suggestions & Feedback',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          final isSelected =
              searchController.selectedCategories.contains(category);
          return GestureDetector(
            onTap: () {
              searchController.toggleCategory(category);
              searchController.searchFeed(widget.allItems);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchResultItem(dynamic item, int index) {
    if (item is ForumModel) {
      String profilePic = "";
      if (item.author?['profilePic'] is List &&
          (item.author?['profilePic'] as List).isNotEmpty) {
        profilePic = item.author?['profilePic'][0];
      }

      String postImage = "";
      if (item.images != null && item.images!.isNotEmpty) {
        postImage = item.images![0];
      }

      return ForumCard(
        index: index,
        profileImageURL: profilePic,
        profileName:
            "${item.author?['firstName'] ?? ''} ${item.author?['lastName'] ?? ''}"
                .trim(),
        postStatus:
            item.createdAt != null ? _formatDate(item.createdAt!) : "Latest",
        postTitle: item.title ?? "Untitled",
        postImageURL: postImage,
        likesCount: item.upvotes ?? 0,
        commentsCount: item.commentCount ?? 0,
        postId: item.id ?? '',
        upvotes: item.upvotes ?? 0,
        downvotes: item.downvotes ?? 0,
      );
    } else if (item is Poll) {
      return PollCard(
        poll: item,
        onVote: (selectedIndices) {
          // Handle vote if needed
        },
      );
    } else if (item is SubPostModel) {
      return SubForumPostCard(
        index: index,
        post: item,
      );
    } else if (item is SubPollModel) {
      return SubForumPollCard(
        poll: item,
        onVote: (selectedIndices) {
          // Handle vote if needed
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingWidget(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Searching...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchWidget(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 48,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start your search',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter keywords to find posts, polls,\nand discussions that interest you',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

Widget _buildNoResultsWidget(String query, bool isDark) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color.fromARGB(0, 66, 66, 66)
                  : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
