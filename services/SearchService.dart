// services/forum_search_service.dart
import 'package:myunivrs/features/forum/models/forum_model.dart';
import 'package:myunivrs/features/forum/poll/models/pollModel.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';

class ForumSearchService {
  Future<List<dynamic>> searchFeed({
    required List<dynamic> items,
    required String query,
    required List<String> categories,
  }) async {
    if (query.isEmpty && categories.isEmpty) return items;

    final lowerCaseQuery = query.toLowerCase();
    final lowerCaseCategories = categories.map((c) => c.toLowerCase()).toList();

    return items.where((item) {
      bool matchesQuery = query.isEmpty;
      bool matchesCategory = categories.isEmpty;

      // Common check for both query and category
      if (!matchesQuery || !matchesCategory) {
        // Handle Forum Posts
        if (item is ForumModel) {
          if (!matchesQuery) {
            matchesQuery = item.title?.toLowerCase().contains(lowerCaseQuery) ==
                    true ||
                item.content?.toLowerCase().contains(lowerCaseQuery) == true ||
                '${item.author?['firstName'] ?? ''} ${item.author?['lastName'] ?? ''}'
                    .toLowerCase()
                    .contains(lowerCaseQuery);
          }
          if (!matchesCategory) {
            matchesCategory = item.category != null &&
                lowerCaseCategories.contains(item.category!.toLowerCase());
          }
        }
        // Handle Polls
        else if (item is Poll) {
          if (!matchesQuery) {
            matchesQuery =
                item.question?.toLowerCase().contains(lowerCaseQuery) == true ||
                    item.options?.any((option) =>
                            option.toLowerCase().contains(lowerCaseQuery)) ==
                        true;
          }
        }
        // Handle SubForum Posts
        else if (item is SubPostModel) {
          if (!matchesQuery) {
            matchesQuery = item.title.toLowerCase().contains(lowerCaseQuery) ||
                item.content.toLowerCase().contains(lowerCaseQuery) ||
                item.author.displayName.toLowerCase().contains(lowerCaseQuery);
          }
          if (!matchesCategory) {
            matchesCategory = item.category != null &&
                lowerCaseCategories.contains(item.category!.toLowerCase());
          }
        }
        // Handle SubForum Polls
        else if (item is SubPollModel) {
          if (!matchesQuery) {
            matchesQuery =
                item.question?.toLowerCase().contains(lowerCaseQuery) == true ||
                    item.options?.any((option) =>
                            option.toLowerCase().contains(lowerCaseQuery)) ==
                        true;
          }
          if (!matchesCategory) {
            matchesCategory = item.category != null &&
                lowerCaseCategories.contains(item.category!.toLowerCase());
          }
        }
      }

      return matchesQuery && matchesCategory;
    }).toList();
  }
}
