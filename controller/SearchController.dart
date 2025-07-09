// controllers/forum_search_controller.dart
import 'package:get/get.dart';
import 'package:myunivrs/features/forum/services/SearchService.dart';

class ForumSearchController extends GetxController {
  final ForumSearchService _searchService = ForumSearchService();
  final RxString _searchQuery = ''.obs;
  final RxBool _isSearching = false.obs;
  final RxList<dynamic> _searchResults = <dynamic>[].obs;
  final RxList<String> _selectedCategories = <String>[].obs;

  String get searchQuery => _searchQuery.value;
  bool get isSearching => _isSearching.value;
  List<dynamic> get searchResults => _searchResults;
  List<String> get selectedCategories => _selectedCategories;

  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    update();
  }

  void setSearchQuery(String query) {
    _searchQuery.value = query;
  }

  void setIsSearching(bool value) {
    _isSearching.value = value;
  }

  Future<void> searchFeed(List<dynamic> items) async {
    if (_searchQuery.value.isEmpty && _selectedCategories.isEmpty) {
      _searchResults.clear();
      return;
    }

    _isSearching.value = true;
    try {
      final results = await _searchService.searchFeed(
        items: items,
        query: _searchQuery.value,
        categories: _selectedCategories,
      );
      _searchResults.assignAll(results);
    } finally {
      _isSearching.value = false;
    }
  }

  void clearSearch() {
    _searchQuery.value = '';
    _selectedCategories.clear();
    _searchResults.clear();
    _isSearching.value = false;
  }
}
