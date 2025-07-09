import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/shared/shared_pref.dart';

enum VoteType { none, upvote, downvote }

class EnhancedVoteTrackingService {
  static const String _votePrefix = 'vote_';
  static const String _lastSyncKey = 'last_vote_sync';
  
  // Save vote locally with enhanced debugging
  static Future<void> saveVote(String targetId, VoteType voteType) async {
    print("=== SAVING VOTE LOCALLY ===");
    print("Target ID: $targetId");
    print("Vote Type: ${voteType.toString()}");
    
    final prefs = await SharedPreferences.getInstance();
    final key = '$_votePrefix$targetId';
    
    switch (voteType) {
      case VoteType.upvote:
        await prefs.setString(key, 'upvote');
        print("Saved upvote for $targetId");
        break;
      case VoteType.downvote:
        await prefs.setString(key, 'downvote');
        print("Saved downvote for $targetId");
        break;
      case VoteType.none:
        await prefs.remove(key);
        print("Removed vote for $targetId");
        break;
    }
    
    // Update last sync time
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    print("Updated last sync time");
  }
  
  // Get vote status locally with enhanced debugging
  static Future<VoteType> getVoteStatus(String targetId) async {
    print("=== GETTING VOTE STATUS LOCALLY ===");
    print("Target ID: $targetId");
    
    final prefs = await SharedPreferences.getInstance();
    final key = '$_votePrefix$targetId';
    final voteString = prefs.getString(key);
    
    print("Stored vote string: $voteString");
    
    VoteType result;
    switch (voteString) {
      case 'upvote':
        result = VoteType.upvote;
        break;
      case 'downvote':
        result = VoteType.downvote;
        break;
      default:
        result = VoteType.none;
        break;
    }
    
    print("Returning vote type: ${result.toString()}");
    return result;
  }
  
  // **ENHANCED: Sync user votes from API with better debugging**
  static Future<void> syncUserVotesFromAPI() async {
    print("=== SYNCING USER VOTES FROM API ===");
    
    try {
      final String? authToken = await SharedPref.getToken();
      final String? userId = await SharedPref.getUserId();
      
      if (authToken == null || userId == null) {
        print('No auth token or user ID found');
        print('Auth token: ${authToken != null ? "Present" : "Missing"}');
        print('User ID: ${userId != null ? "Present" : "Missing"}');
        return;
      }
      
      print("User ID: $userId");
      print("Auth token: ${authToken.substring(0, 20)}...");
      
      // Using your exact API endpoint
      final url = '$apiUrl/vote/votedPosts?userId=$userId';
      print("API URL: $url");
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );
      
      print("Sync response status: ${response.statusCode}");
      print("Sync response body: ${response.body}");
      
      if (response.statusCode == 200) {
        final List<dynamic> votedPosts = jsonDecode(response.body);
        print("Number of voted posts received: ${votedPosts.length}");
        
        final prefs = await SharedPreferences.getInstance();
        
        // Clear existing vote data
        final keys = prefs.getKeys().where((key) => key.startsWith(_votePrefix));
        print("Clearing ${keys.length} existing vote entries");
        for (String key in keys) {
          await prefs.remove(key);
        }
        
        // Store new vote data from your API response structure
        int syncedCount = 0;
        for (var voteData in votedPosts) {
          final String targetId = voteData['targetId'];
          final String voteType = voteData['type']; // 'upvote' or 'downvote'
          final String targetType = voteData['targetType']; // 'ForumPost', 'ForumPoll', 'SubForumPost'
          
          await saveVote(targetId, voteType == 'upvote' ? VoteType.upvote : VoteType.downvote);
          
          print("Synced vote: $targetId -> $voteType ($targetType)");
          syncedCount++;
        }
        
        print("Successfully synced $syncedCount votes");
        
        // Update last sync time
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        
      } else {
        print('Failed to sync votes: ${response.statusCode}');
        print('Error response: ${response.body}');
      }
    } catch (e) {
      print('Error syncing user votes: $e');
    }
  }
  
  // Check if sync is needed (sync every hour) with debugging
  static Future<bool> needsSync() async {
    print("=== CHECKING IF SYNC IS NEEDED ===");
    
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hourInMs = 60 * 60 * 1000; // 1 hour in milliseconds
    
    final timeSinceLastSync = now - lastSync;
    final needsSync = timeSinceLastSync > hourInMs;
    
    print("Last sync: ${DateTime.fromMillisecondsSinceEpoch(lastSync)}");
    print("Current time: ${DateTime.fromMillisecondsSinceEpoch(now)}");
    print("Time since last sync: ${timeSinceLastSync / 1000 / 60} minutes");
    print("Needs sync: $needsSync");
    
    return needsSync;
  }
  
  // Get all user votes as a map with debugging
  static Future<Map<String, VoteType>> getAllUserVotes() async {
    print("=== GETTING ALL USER VOTES ===");
    
    final prefs = await SharedPreferences.getInstance();
    final Map<String, VoteType> votes = {};
    
    final keys = prefs.getKeys().where((key) => key.startsWith(_votePrefix));
    print("Found ${keys.length} vote entries");
    
    for (String key in keys) {
      final targetId = key.substring(_votePrefix.length);
      final voteType = await getVoteStatus(targetId);
      votes[targetId] = voteType;
      print("Vote entry: $targetId -> ${voteType.toString()}");
    }
    
    return votes;
  }
  
  // Clear all vote data with debugging
  static Future<void> clearAllVotes() async {
    print("=== CLEARING ALL VOTES ===");
    
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_votePrefix));
    
    print("Clearing ${keys.length} vote entries");
    
    for (String key in keys) {
      await prefs.remove(key);
    }
    await prefs.remove(_lastSyncKey);
    
    print("All votes cleared");
  }
}
