import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:myunivrs/features/forum/models/forum_model.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/poll/models/pollModel.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';

class ForumController extends GetxController {
  final ForumService forumService;

  // Main forum polls and loading state
  final RxList<Poll> polls = <Poll>[].obs;
  final RxBool isLoadingPolls = false.obs;

  // Feed refresh control
  final RxBool _shouldRefreshFeed = false.obs;

  // Saved posts management
  final RxList<String> savedPostIds = <String>[].obs;
  final RxBool isLoadingSavedPosts = false.obs;

  // SubForum polls management
  final RxList<SubPollModel> subForumPolls = <SubPollModel>[].obs;
  final RxBool isLoadingSubForumPolls = false.obs;

  // SubForum posts management
  var subForumPosts = <SubPostModel>[].obs;
  var isLoadingSubForumPosts = false.obs;

  ForumController({required this.forumService});

  // Main forum data containers
  RxList items = [].obs; // All forum posts
  RxList userItems = [].obs; // Current user's posts
  RxList<String> imgitems = <String>[].obs; // Image URLs
  RxList<ForumModel> savedItems = <ForumModel>[].obs; // Bookmarked posts

  // Global loading states
  RxBool isLoading = false.obs;
  RxBool isError = false.obs;
  RxBool isSelect = true.obs;
  RxBool hasMore = true.obs; // Pagination control

  @override
  void onInit() {
    super.onInit();
  }

  // Trigger feed refresh flag
  void setShouldRefresh() {
    _shouldRefreshFeed.value = true;
  }

  // Reset feed refresh flag
  void resetRefreshFlag() {
    _shouldRefreshFeed.value = false;
  }

  // Refresh all forum data at once
  Future<void> refreshData() async {
    try {
      hasMore(true);
      await Future.wait([
        getPosts(1, 10),
        getPolls(),
        getSubForumPosts(),
        getSubForumPolls(),
        loadAllSavedItems(),
      ]);
    } catch (e) {
      print("Error refreshing data: $e");
      isError(true);
    }
  }

  // Fetch all sub-forum polls
  Future<void> getSubForumPolls() async {
    try {
      isLoadingSubForumPolls(true);
      print("Fetching sub-forum polls...");

      final List<SubPollModel> response = await forumService.getSubForumPolls();

      print("Received response: ${response.length} sub-forum polls");
      print(
          "First poll (if any): ${response.isNotEmpty ? response[0].question : 'No polls'}");

      subForumPolls.assignAll(response);
      print("SubForum polls assigned successfully");
    } catch (e) {
      print("Error getting sub-forum polls: $e");
    } finally {
      isLoadingSubForumPolls(false);
      print("SubForum polls loading state set to false");
    }
  }

  // Submit vote for sub-forum poll
  Future<void> voteOnSubForumPoll({
    required String pollId,
    required List<int> selectedOptionIndices,
  }) async {
    try {
      isLoadingSubForumPolls(true);
      await forumService.voteOnSubForumPoll(
        pollId: pollId,
        selectedOptionIndices: selectedOptionIndices,
      );
      await getSubForumPolls(); // Refresh after voting
    } catch (e) {
      print("Error voting on sub-forum poll: $e");
    } finally {
      isLoadingSubForumPolls(false);
    }
  }

  // Fetch all sub-forum posts
  Future<void> getSubForumPosts() async {
    try {
      isLoadingSubForumPosts(true);
      print("Fetching sub-forum posts...");

      final List<SubPostModel> response = await forumService.getSubForumPosts();

      print("Received response: ${response.length} posts");
      print(
          "First post (if any): ${response.isNotEmpty ? response[0].title : 'No posts'}");

      subForumPosts.assignAll(response);
      print("Posts assigned successfully");
    } catch (e) {
      print("Error getting sub-forum posts: $e");
      Fluttertoast.showToast(msg: "Failed to load sub-forum posts");
    } finally {
      isLoadingSubForumPosts(false);
      print("Loading state set to false");
    }
  }

  // Get specific user post by ID
  Future<void> getUserPost(String postId) async {
    try {
      isLoading.value = true;
      await forumService.getUserPosts(postId);
    } catch (e) {
      isError.value = true;
    } finally {
      isLoading.value = false;
      isError.value = false;
    }
  }

  // Fetch paginated forum posts
  Future<void> getPosts(int page, int limit) async {
    try {
      isLoading(true);
      isError(false);
      final posts = await forumService.getPosts(page, limit);

      if (page == 1) {
        items.clear(); // Clear for fresh load
      }

      _processPosts(posts);
      items.addAll(posts);

      print("Posts loaded in controller: ${items.length}");
      hasMore(posts.length >= limit); // Check if more posts available
    } catch (e) {
      print("Error in getPosts controller: $e");
      isError(true);
    } finally {
      isLoading(false);
    }
  }

  // Create new forum post with optional images
  Future<void> createPost(ForumModel post, List<File>? images) async {
    try {
      isLoading(true);
      await forumService.createPost(post, images);
    } catch (e) {
      isError(true);
    } finally {
      isLoading(false);
      isError(false);
      setShouldRefresh(); // Trigger feed refresh
    }
  }

  // Delete forum post by ID
  void deletePost(String postId) async {
    try {
      isLoading(true);
      await forumService.deletePost(postId);
    } catch (e) {
      isError(true);
    } finally {
      isLoading(false);
    }
  }

  // Fetch current user's forum posts
  Future<void> getMyPosts() async {
    try {
      print("=== Starting getMyPosts in Controller ===");
      isLoading(true);
      isError(false);

      final posts = await forumService.getMyPosts();
      print("Posts received in controller: ${posts.length}");

      userItems.clear();
      userItems.addAll(posts);

      print("UserItems updated, new length: ${userItems.length}");
    } catch (e, stackTrace) {
      print("=== Error in Controller getMyPosts ===");
      print("Error Type: ${e.runtimeType}");
      print("Error Message: $e");
      print("Stack Trace: $stackTrace");
      isError(true);
    } finally {
      isLoading(false);
    }
  }

  // Get detailed view of specific post
  Future<ForumModel?> getPostDetails(String postId) async {
    try {
      isLoading(true);
      isError(false);

      print("Fetching post details for ID: $postId");
      final ForumModel post = await forumService.getUserPosts(postId);

      print("Successfully retrieved post details");
      return post;
    } catch (e) {
      print("Error fetching post details: $e");
      isError(true);

      if (e.toString().contains('Authentication failed')) {
        Get.back();
        Get.snackbar(
          'Session Expired',
          'Please log in again',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return null;
      }
      Get.snackbar(
        'Error',
        'Failed to fetch post details',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return null;
    } finally {
      isLoading(false);
    }
  }

  // Update existing forum post with new content/images
  Future<ForumModel?> updatePost(
      ForumModel forum, String postId, List<File>? newImages) async {
    try {
      isLoading(true);
      isError(false);

      print("Controller: Updating forum post with ID: $postId");
      final ForumModel updatedPost =
          await forumService.updatePost(forum, postId, newImages);

      _updateItemInLists(updatedPost); // Update local lists

      Fluttertoast.showToast(
        msg: "Forum post updated successfully",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      return updatedPost;
    } catch (e) {
      print("Error in controller updatePost: $e");
      isError(true);
      Fluttertoast.showToast(
        msg: "Failed to update post: ${e.toString()}",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return null;
    } finally {
      isLoading(false);
      isError(false);
      setShouldRefresh(); // Trigger feed refresh
    }
  }

  // Fetch all available polls
  Future<void> getPolls() async {
    try {
      isLoadingPolls(true);
      final polls = await forumService.getAllPolls();
      this.polls.assignAll(polls);
    } catch (e) {
      print("Error getting polls: $e");
      Fluttertoast.showToast(msg: "Failed to load polls");
    } finally {
      isLoadingPolls(false);
    }
  }

  // Submit vote for main forum poll
  Future<void> voteOnPoll({
    required String pollId,
    required List<int> selectedOptionIndices,
  }) async {
    try {
      isLoadingPolls(true);
      await forumService.voteOnPoll(
        pollId: pollId,
        selectedOptionIndices: selectedOptionIndices,
      );
      await getPolls(); // Refresh polls after voting
    } catch (e) {
      print("Error voting on poll: $e");
    } finally {
      isLoadingPolls(false);
    }
  }

  // Update post in all local lists after modification
  void _updateItemInLists(ForumModel updatedPost) {
    // Update in main items list
    for (int i = 0; i < items.length; i++) {
      if (items[i].id == updatedPost.id) {
        items[i] = updatedPost;
        break;
      }
    }

    // Update in user items list
    for (int i = 0; i < userItems.length; i++) {
      if (userItems[i].id == updatedPost.id) {
        userItems[i] = updatedPost;
        break;
      }
    }

    items.refresh();
    userItems.refresh();
  }

  // Reset all loading and error states
  void resetLoadingState() {
    isLoading(false);
    isError(false);
  }

  // Process posts for additional data (like comment counts)
  void _processPosts(List<ForumModel> posts) {
    for (var post in posts) {
      print(
          "Post ${post.id} has ${post.commentCount} comments according to API");
    }
  }

  // Add post to saved/bookmarked list
  Future<void> savePost(String postId) async {
    try {
      final index = items.indexWhere((post) => post.id == postId);
      if (index != -1) {
        items[index] = items[index].copyWith(isSaved: true);
        items.refresh();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to save post');
    }
  }

  // Fetch user's bookmarked posts
  Future<void> getBookmarkedPosts() async {
    try {
      isLoading.value = true;
      isError.value = false;
    } catch (e) {
      isError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  // Remove post from saved/bookmarked list
  Future<void> unsavePost(String postId) async {
    try {
      final index = items.indexWhere((post) => post.id == postId);
      if (index != -1) {
        items[index] = items[index].copyWith(isSaved: false);
        items.refresh();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to unsave post');
    }
  }

  // Alternative method for sub-forum poll voting
  Future<void> voteOnSubForumPollNew({
    required String pollId,
    required List<int> selectedOptionIndices,
  }) async {
    try {
      isLoadingSubForumPolls(true);
      await forumService.voteOnSubForumPollNew(
        pollId: pollId,
        selectedOptionIndices: selectedOptionIndices,
      );
      await getSubForumPolls(); // Refresh polls after voting
    } catch (e) {
      print("Error voting on sub-forum poll: $e");
    } finally {
      isLoadingSubForumPolls(false);
    }
  }

  // User's own forum polls management
  final RxList<Poll> myForumPolls = <Poll>[].obs;
  final RxBool isLoadingMyForumPolls = false.obs;

  // Fetch current user's forum polls
  Future<void> getMyForumPolls() async {
    try {
      isLoadingMyForumPolls(true);
      final polls = await forumService.getMyForumPolls();
      myForumPolls.assignAll(polls as Iterable<Poll>);
    } catch (e) {
      print("Error getting my forum polls: $e");
      Fluttertoast.showToast(msg: "Failed to load my forum polls");
    } finally {
      isLoadingMyForumPolls(false);
    }
  }

  // User's own sub-forum posts management
  final RxList<SubPostModel> mySubForumPosts = <SubPostModel>[].obs;
  final RxBool isLoadingMySubForumPosts = false.obs;

  // Fetch current user's sub-forum posts
  Future<void> getOwnSubForumPosts() async {
    try {
      isLoadingMySubForumPosts(true);
      final posts = await forumService.getOwnSubForumPosts();
      mySubForumPosts.assignAll(posts);
    } catch (e) {
      print("Error getting own sub-forum posts: $e");
      Fluttertoast.showToast(msg: "Failed to load your sub-forum posts");
    } finally {
      isLoadingMySubForumPosts(false);
    }
  }

  // User's own sub-forum polls management
  final RxList<SubPollModel> mySubForumPolls = <SubPollModel>[].obs;
  final RxBool isLoadingMySubForumPolls = false.obs;

  // Fetch current user's sub-forum polls with optional category filter
  Future<void> getMySubForumPolls({String? category}) async {
    try {
      isLoadingMySubForumPolls(true);
      print("Fetching my sub-forum polls...");
      final List<SubPollModel> response =
          await forumService.getMySubForumPolls(category: category);
      print("Received ${response.length} of my sub-forum polls");
      mySubForumPolls.assignAll(response);
    } catch (e) {
      print("Error getting my sub-forum polls: $e");
      Fluttertoast.showToast(msg: "Failed to load your sub-forum polls");
    } finally {
      isLoadingMySubForumPolls(false);
    }
  }

  // **FAVORITE/SAVED ITEMS FUNCTIONALITY**

  // Load all saved item IDs (posts, polls, etc.)
  Future<void> loadAllSavedItems() async {
    try {
      isLoadingSavedPosts(true);
      final savedIds = await forumService.getAllSavedItems();
      savedPostIds.assignAll(savedIds);
      print("Loaded ${savedIds.length} saved item IDs (all types)");
    } catch (e) {
      print("Error loading all saved items: $e");
      // Fallback to forum posts only if getAllSavedItems fails
      try {
        final savedIds = await forumService.getAllSavedItems();
        savedPostIds.assignAll(savedIds);
        print("Fallback: Loaded ${savedIds.length} saved post IDs");
      } catch (fallbackError) {
        print("Error in fallback loading: $fallbackError");
      }
    } finally {
      isLoadingSavedPosts(false);
    }
  }

  // Toggle save/unsave status for any item type
  Future<void> toggleSaveItem(String itemId, String itemType) async {
    try {
      final isSaved = savedPostIds.contains(itemId);

      if (isSaved) {
        // Remove from favorites
        await forumService.unsavePost(postId: itemId, itemType: itemType);
        savedPostIds.remove(itemId);
      } else {
        // Add to favorites
        await forumService.savePost(postId: itemId, itemType: itemType);
        savedPostIds.add(itemId);
      }

      // Refresh the saved items list
      savedPostIds.refresh();
    } catch (e) {
      print("Error toggling save item: $e");
      Fluttertoast.showToast(
        msg: "Failed to update favorites",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Check if any item is currently saved
  bool isItemSaved(String itemId) {
    return savedPostIds.contains(itemId);
  }
}
