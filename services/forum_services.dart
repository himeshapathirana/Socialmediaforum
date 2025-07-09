import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/features/forum/models/forum_model.dart';
import 'package:myunivrs/features/forum/poll/models/pollModel.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

// Report Type Enum
enum ReportType {
  ForumPost,
  ForumPoll,
  SubForumPost,
  SubForumPoll,
  Comment,
  User,
}

// Report Model
class ReportModel {
  final String? id;
  final String reportedItem;
  final String reason;
  final DateTime reportedAt;
  final ReportType reportedType;
  final String? note;
  final String? reportedBy;
  ReportModel({
    this.id,
    required this.reportedItem,
    required this.reason,
    required this.reportedAt,
    required this.reportedType,
    this.note,
    this.reportedBy,
  });
  Map<String, dynamic> toJson() {
    return {
      'reportedItem': reportedItem,
      'reason': reason,
      'reportedAt': reportedAt.toIso8601String(),
      'reportedType': reportedType.toString().split('.').last,
      'note': note ?? '',
    };
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['_id'],
      reportedItem: json['reportedItem'],
      reason: json['reason'],
      reportedAt: DateTime.parse(json['reportedAt']),
      reportedType: ReportType.values.firstWhere(
        (type) => type.toString().split('.').last == json['reportedType'],
        orElse: () => ReportType.ForumPost,
      ),
      note: json['note'],
      reportedBy: json['reportedBy'],
    );
  }
}

class ForumService {
  final Dio dio;
  final baseUrl = apiUrl;
  ForumService(this.dio);
  final _refreshController = StreamController<void>.broadcast();
  Stream<void> get refreshStream => _refreshController.stream;
  void triggerRefresh() {
    _refreshController.add(null);
  }

  @override
  void dispose() {
    _refreshController.close();
  }

  Future<void> refreshAllContent() async {
    try {
      await Future.wait([
        getPosts(1, 10),
        getAllPolls(),
        getSubForumPosts(),
        getSubForumPolls(),
      ]);
      triggerRefresh();
    } catch (e) {
      print("Error refreshing all content: $e");
    }
  }

  Future<void> refreshForumPosts() async {
    try {
      await getPosts(1, 10);
      triggerRefresh();
    } catch (e) {
      print("Error refreshing forum posts: $e");
    }
  }

  Future<void> refreshPolls() async {
    try {
      print("Refreshing polls...");
      await getAllPolls();
      triggerRefresh();
    } catch (e) {
      print("Error refreshing polls: $e");
      Fluttertoast.showToast(
        msg: "Failed to refresh polls: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
      // Re-throw the error if you want calling code to handle it
      rethrow;
    }
  }

  Future<void> refreshSubForumPosts() async {
    try {
      await getSubForumPosts();
      triggerRefresh();
    } catch (e) {
      print("Error refreshing sub-forum posts: $e");
    }
  }

  Future<void> refreshSubForumPolls() async {
    try {
      await getSubForumPolls();
      triggerRefresh();
    } catch (e) {
      print("Error refreshing sub-forum polls: $e");
    }
  }

  Future<void> refreshMyContent() async {
    try {
      await Future.wait([
        getMyPosts(),
        getMyForumPolls(),
        getOwnSubForumPosts(),
        getMySubForumPolls(),
      ]);
      triggerRefresh();
    } catch (e) {
      print("Error refreshing my content: $e");
    }
  }

  Future<void> refreshBookmarkedContent() async {
    try {
      await getBookmarkedPosts();
      triggerRefresh();
    } catch (e) {
      print("Error refreshing bookmarked content: $e");
    }
  }

  Future<String?> getToken() async {
    print("Fetching token...");
    String? token = await SharedPref.getToken();
    print("Token fetched: $token");
    return token;
  }

  Future<void> createPost(ForumModel forum, List<File>? images) async {
    print("Preparing formData for createPost...");
    final formDataMap = {
      'title': forum.title,
      'content': forum.content,
      'upvotes': forum.upvotes,
      'downvotes': forum.downvotes,
      'isPinned': forum.isPinned ? "true" : "false",
      'isClosed': forum.isClosed ? "true" : "false",
    };
    formDataMap.forEach((key, value) {
      print("Form Data - $key: $value");
    });
    var formData = FormData.fromMap(formDataMap);
    if (images != null && images.isNotEmpty) {
      for (File image in images) {
        print("Adding image to formData: ${image.path}");
        formData.files.add(
          MapEntry(
            'files',
            await MultipartFile.fromFile(image.path,
                filename: image.path.split('/').last),
          ),
        );
      }
    }
    print("FormData prepared: ${formData.fields}");
    try {
      final String? authToken = await getToken();
      print(
          "Sending createPost request to $baseUrl/forum/create-forum-post...");
      final Response response = await dio.post(
        '$baseUrl/forum/create-forum-post',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );
      print("Received response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 201) {
        await refreshForumPosts();
      } else {
        print("Failed to create post: ${response.data}");
        Fluttertoast.showToast(msg: "Failed to create post: ${response.data}");
      }
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      print("Unexpected error in createPost: $e");
      Fluttertoast.showToast(
          msg: "An unexpected error occurred: ${e.toString()}");
    }
  }

  Future<ForumModel> getUserPosts(String postId) async {
    try {
      print("Fetching post with ID: $postId");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      final Response response = await dio.get(
        '$baseUrl/forum/view-forum-post/$postId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );
      print("Received response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        return ForumModel.fromJson(response.data);
      } else if (response.statusCode == 401) {
        print("Authentication error: Token may be expired");
        throw Exception('Authentication failed. Please log in again.');
      } else {
        throw Exception('Failed to get post: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print("DioException in getUserPosts: ${e.message}");
      print("Response status: ${e.response?.statusCode}");
      print("Response data: ${e.response?.data}");
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      }
      throw Exception('Failed to get post: ${e.message}');
    } catch (e) {
      print("Unexpected error in getPost: $e");
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<List<ForumModel>> getPosts(int page, int limit) async {
    try {
      print("Fetching posts...");
      final String? authToken = await getToken();
      final Response response = await dio.get(
        '$baseUrl/forum/view-forum-post',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      print("Received response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = response.data;
        final List<dynamic> forumPosts = responseData['forumPosts'] ?? [];
        print("Number of posts received: ${forumPosts.length}");
        final posts = forumPosts.map((post) {
          print("Converting post: $post");
          return ForumModel.fromJson(post);
        }).toList();
        print("Successfully converted ${posts.length} posts");
        return posts;
      } else {
        throw Exception('Failed to get posts: ${response.statusMessage}');
      }
    } catch (e) {
      print("Error in getPosts service: $e");
      throw e;
    }
  }

  Future<List<ForumModel>> getMyPosts() async {
    try {
      print("=== Starting getMyPosts in Service ===");

      // Get both token and user ID
      final String? authToken = await getToken();

      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }

      final response = await dio.get(
        '$baseUrl/forum/view-own-post',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("Response status code: ${response.statusCode}");
      print("Full response data: ${response.data}");

      if (response.statusCode == 200) {
        // Handle different response formats
        List<dynamic> forumPosts;

        if (response.data is List) {
          // Direct list response
          forumPosts = response.data;
        } else if (response.data is Map<String, dynamic>) {
          // Object response with posts array
          final responseData = response.data as Map<String, dynamic>;
          forumPosts = responseData['forumPosts'] ??
              responseData['posts'] ??
              responseData['userPosts'] ??
              [];
        } else {
          throw Exception('Unexpected response format');
        }

        print("Number of user posts received: ${forumPosts.length}");

        final posts = forumPosts.map((post) {
          try {
            return ForumModel.fromJson(post);
          } catch (e) {
            print("Error converting post: $e");
            print("Post data: $post");
            rethrow;
          }
        }).toList();

        print("Successfully converted ${posts.length} user posts");
        return posts;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again.');
      } else if (response.statusCode == 404) {
        print("No posts found for user");
        return []; // Return empty list if no posts found
      } else {
        throw Exception('Failed to get my posts: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print("DioException in getMyPosts: ${e.message}");
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (e.response?.statusCode == 404) {
        print("No posts found for the user");
        return []; // Return empty list instead of throwing error
      }
      throw Exception('Failed to get my posts: ${e.message}');
    } catch (e) {
      print("Error in getMyPosts: $e");
      throw Exception('Failed to get my posts: $e');
    }
  }

  Future<List<ForumModel>> getBookmarkedPosts() async {
    try {
      print("Fetching bookmarked posts...");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      final Response response = await dio.get(
        '$baseUrl/forum/bookmarked-posts',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      print(
          "Received bookmarked posts response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        final List<dynamic> bookmarkedPosts =
            response.data['bookmarkedPosts'] ?? [];
        return bookmarkedPosts
            .map((post) => ForumModel.fromJson(post))
            .toList();
      } else {
        throw Exception(
            'Failed to get bookmarked posts: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Failed to get bookmarked posts: ${e.message}');
    } catch (e) {
      print("Unexpected error in getBookmarkedPosts: $e");
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> toggleBookmarkStatus(String postId, bool isBookmarked) async {
    try {
      print("Toggling bookmark for post ID: $postId to $isBookmarked");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      final Response response = await dio.post(
        '$baseUrl/forum/bookmark/$postId',
        data: {'isBookmarked': isBookmarked},
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      print(
          "Toggle bookmark response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: isBookmarked ? "Post bookmarked!" : "Bookmark removed!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        throw Exception('Failed to toggle bookmark: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Failed to toggle bookmark: ${e.message}');
    } catch (e) {
      print("Unexpected error in toggleBookmarkStatus: $e");
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<File> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = file.path.split('/').last;
    final image = img.decodeImage(file.readAsBytesSync())!;
    int targetHeight = (800 * image.height / image.width).round();
    final resized = img.copyResize(
      image,
      width: 800,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
    final compressedImageFile = File('${tempDir.path}/compressed_$fileName')
      ..writeAsBytesSync(img.encodeJpg(resized, quality: 70));
    return compressedImageFile;
  }

  Future<ForumModel> updatePost(
      ForumModel forum, String postId, List<File>? newImages) async {
    print("Updating post with ID: $postId");
    try {
      final String? authToken = await getToken();
      final updateData = {
        'title': forum.title,
        'content': forum.content,
        'images': forum.images,
        'isPinned': forum.isPinned,
        'isClosed': forum.isClosed,
      };
      print("Update data for text content: $updateData");
      final Response textUpdateResponse = await dio.patch(
        '$baseUrl/forum/update-forum-post/$postId',
        data: updateData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );
      print(
          "Text update response: ${textUpdateResponse.statusCode} - ${textUpdateResponse.data}");
      if (textUpdateResponse.statusCode != 200) {
        throw Exception('Failed to update forum post text content');
      }
      if (newImages != null && newImages.isNotEmpty) {
        print("Processing ${newImages.length} new images for post $postId");
        var tempFormData = FormData.fromMap({
          'title': 'Temp upload for ${forum.title}',
          'content': 'Temp content for image upload',
          'isPinned': "false",
          'isClosed': "false",
        });
        for (File image in newImages) {
          print("Adding new image to upload: ${image.path}");
          File compressedImage = await compressImage(image);
          tempFormData.files.add(
            MapEntry(
              'files',
              await MultipartFile.fromFile(compressedImage.path,
                  filename: compressedImage.path.split('/').last),
            ),
          );
        }
        final Response imageUploadResponse = await dio.post(
          '$baseUrl/forum/create-forum-post',
          data: tempFormData,
          options: Options(
            headers: {'Authorization': 'Bearer $authToken'},
            validateStatus: (status) => status! < 500,
          ),
        );
        print(
            "Image upload response: ${imageUploadResponse.statusCode} - ${imageUploadResponse.data}");
        if (imageUploadResponse.statusCode == 201) {
          await refreshForumPosts();
          List<String> uploadedImageUrls = [];
          if (imageUploadResponse.data['images'] != null) {
            uploadedImageUrls =
                List<String>.from(imageUploadResponse.data['images']);
            print("Extracted image URLs: $uploadedImageUrls");
            List<String> combinedImageUrls = [
              ...(forum.images ?? []),
              ...uploadedImageUrls
            ];
            final updateWithImagesData = {
              'images': combinedImageUrls,
            };
            final Response finalUpdateResponse = await dio.patch(
              '$baseUrl/forum/update-forum-post/$postId',
              data: updateWithImagesData,
              options: Options(
                headers: {
                  'Authorization': 'Bearer $authToken',
                  'Content-Type': 'application/json',
                },
                validateStatus: (status) => status! < 500,
              ),
            );
            print(
                "Final update response: ${finalUpdateResponse.statusCode} - ${finalUpdateResponse.data}");
            if (finalUpdateResponse.statusCode == 200) {
              try {
                String tempPostId = imageUploadResponse.data['_id'];
                await dio.delete(
                  '$baseUrl/forum/delete-forum-post/$tempPostId',
                  options: Options(
                    headers: {'Authorization': 'Bearer $authToken'},
                    validateStatus: (status) => status! < 500,
                  ),
                );
                print("Temporary post deleted successfully");
              } catch (e) {
                print("Warning: Failed to delete temporary post: $e");
              }
              return ForumModel.fromJson(finalUpdateResponse.data);
            } else {
              throw Exception('Failed to update post with new image URLs');
            }
          } else {
            print("No images found in temporary post");
            throw Exception('No images were uploaded successfully');
          }
        } else {
          throw Exception(
              'Failed to upload images: ${imageUploadResponse.statusMessage}');
        }
      } else {
        return ForumModel.fromJson(textUpdateResponse.data);
      }
    } catch (e) {
      print("Error updating post: $e");
      Fluttertoast.showToast(
        msg: "Failed to update post: ${e.toString()}",
        backgroundColor: Colors.red,
      );
      throw Exception('Failed to update post: $e');
    }
  }

  Future<void> updateSubForumVotes(
      String postId, int upvotes, int downvotes) async {
    try {
      print("Updating votes for sub-forum post: $postId");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      final updateData = {
        'upvotes': upvotes,
        'downvotes': downvotes,
      };
      print("Update sub-forum votes data: $updateData");
      final Response response = await dio.patch(
        '$baseUrl/sub-forum-post/update-sub-forum-post/$postId',
        data: updateData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );
      print(
          "Sub-forum vote update response: ${response.statusCode} - ${response.data}");
      if (response.statusCode != 200) {
        throw Exception('Failed to update sub-forum vote counts');
      }
    } catch (e) {
      print("Error updating sub-forum votes: $e");
      throw Exception('Failed to update sub-forum vote counts: $e');
    }
  }

  Future<void> updateVotes(String postId, int upvotes, int downvotes) async {
    try {
      print("Updating votes for post: $postId");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      final updateData = {
        'upvotes': upvotes,
        'downvotes': downvotes,
      };
      print("Update votes data: $updateData");
      final Response response = await dio.patch(
        '$baseUrl/forum/update-forum-post/$postId',
        data: updateData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );
      print("Vote update response: ${response.statusCode} - ${response.data}");
      if (response.statusCode != 200) {
        throw Exception('Failed to update vote counts');
      }
    } catch (e) {
      print("Error updating votes: $e");
      throw Exception('Failed to update vote counts: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      print("Deleting post with ID: $postId");
      final String? authToken = await getToken();
      final Response response = await dio.delete(
        '$baseUrl/forum/delete-forum-post/$postId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      print("Delete response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: "Forum post deleted successfully");
        await refreshForumPosts();
      } else {
        print("Failed to delete post: ${response.statusMessage}");
        throw Exception('Failed to delete post');
      }
    } catch (e) {
      print("Error deleting post: $e");
      throw Exception('Failed to delete post: $e');
    }
  }

  Future<void> createPoll({
    required String question,
    required List<String> options,
    required bool allowMultipleAnswers,
  }) async {
    print("Attempting to create poll...");
    try {
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing. Please log in.');
      }
      final data = {
        "question": question,
        "options": options,
        "allowMultipleAnswers": allowMultipleAnswers,
        "upvotes": 0,
        "downvotes": 0,
      };
      print(
          "Sending poll creation request to $baseUrl/forum-poll/create-forum-poll with data: $data");
      final Response response = await dio.post(
        '$baseUrl/forum-poll/create-forum-poll',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );
      print(
          "Poll creation response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 201 || response.statusCode == 200) {
        Fluttertoast.showToast(msg: "Poll created successfully!");
        await refreshPolls();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again.');
      } else {
        throw Exception('Failed to create poll: ${response.data}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Failed to create poll: ${e.message}');
    } catch (e) {
      print("Unexpected error in createPoll: $e");
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<List<Poll>> getAllPolls() async {
    try {
      print("Fetching all polls...");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing. Please log in.');
      }

      // Update this URL if needed
      final String endpoint = '$baseUrl/forum-poll/all-forum-polls';
      print("Making request to: $endpoint");

      final Response response = await dio.get(
        endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          // Don't throw for 404 - handle it explicitly
          validateStatus: (status) => status! < 500,
        ),
      );

      print("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Handle successful response
        if (response.data is Map && response.data['polls'] is List) {
          return (response.data['polls'] as List)
              .map((poll) => Poll.fromJson(poll))
              .toList();
        } else if (response.data is List) {
          // Handle case where response is directly a list
          return (response.data as List)
              .map((poll) => Poll.fromJson(poll))
              .toList();
        } else {
          throw Exception('Unexpected response format: ${response.data}');
        }
      } else if (response.statusCode == 404) {
        throw Exception(
            'Polls endpoint not found (404). Please check the URL.');
      } else {
        throw Exception('Failed to get polls: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print("Dio error in getAllPolls: ${e.message}");
      if (e.response != null) {
        print(
            "Error response: ${e.response?.statusCode} - ${e.response?.data}");
      }
      throw Exception('Failed to get polls: ${e.message}');
    } catch (e) {
      print("Unexpected error in getAllPolls: $e");
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<void> voteOnPoll({
    required String pollId,
    required List<int> selectedOptionIndices,
  }) async {
    try {
      final String? authToken = await getToken();
      if (authToken == null) {
        throw Exception('Authentication token is missing');
      }
      final data = {
        "selectedOptions": selectedOptionIndices,
      };
      final Response response = await dio.post(
        '$baseUrl/forum-poll/vote/$pollId',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to vote: ${response.data}');
      }
    } catch (e) {
      print("Error voting on poll: $e");
      throw Exception('Failed to vote: $e');
    }
  }

  // NEW METHOD TO GET FEED FORUMS
  Future<List<ForumModel>> getFeedForums() async {
    try {
      print("Fetching feed forums...");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      final Response response = await dio.get(
        '$baseUrl/feed',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            return status! < 500;
          },
        ),
      );
      print(
          "Received feed forums response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        if (response.data is List) {
          return (response.data as List)
              .map((post) => ForumModel.fromJson(post))
              .toList();
        } else if (response.data is Map && response.data['feedPosts'] is List) {
          return (response.data['feedPosts'] as List)
              .map((post) => ForumModel.fromJson(post))
              .toList();
        } else {
          throw Exception(
              'Unexpected response format for feed forums: ${response.data}');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again.');
      } else {
        throw Exception('Failed to get feed forums: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Failed to get feed forums: ${e.message}');
    } catch (e) {
      print("Unexpected error in getFeedForums: $e");
      throw Exception(
          'An unexpected error occurred while fetching feed forums: ${e.toString()}');
    }
  }

  //  Updated getSubForumPosts to return List
  Future<List<SubPostModel>> getSubForumPosts({String? category}) async {
    try {
      print("Fetching sub-forum posts...");
      final String? authToken = await getToken();
      print(
          "Auth token: ${authToken?.substring(0, 5)}..."); // Log first 5 chars

      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }

      final Map<String, dynamic> queryParams = {};
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final url = '$baseUrl/sub-forum-post/all-sub-forum-posts';
      print("Making request to: $url");
      print("Query parameters: $queryParams");
      print("Headers: ${{
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      }}");

      final Response response = await dio.get(
        url,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("Received response status: ${response.statusCode}");
      print("Response headers: ${response.headers}");
      print("Full response data: ${response.data}");

      if (response.statusCode == 200) {
        List<dynamic> subForumPostsData;

        // Enhanced response format handling
        if (response.data is List) {
          subForumPostsData = response.data;
        } else if (response.data is Map) {
          if (response.data['subForumPosts'] is List) {
            subForumPostsData = response.data['subForumPosts'];
          } else if (response.data['posts'] is List) {
            subForumPostsData = response.data['posts'];
          } else if (response.data['data'] is List) {
            subForumPostsData = response.data['data'];
          } else {
            print("Unexpected Map structure: ${response.data.keys}");
            throw Exception('Unexpected response format for sub-forum posts');
          }
        } else {
          throw Exception('Unexpected response type for sub-forum posts');
        }

        print("Found ${subForumPostsData.length} posts");

        final List<SubPostModel> convertedPosts = [];
        for (var postData in subForumPostsData) {
          try {
            print("Processing post: ${postData['id'] ?? 'unknown'}");
            final SubPostModel post = SubPostModel.fromJson(postData);
            convertedPosts.add(post);
          } catch (e) {
            print("Error converting post: $e");
            print("Problematic post data: $postData");
          }
        }

        print("Successfully converted ${convertedPosts.length} posts");
        return convertedPosts;
      } else {
        print("Error response: ${response.statusCode} - ${response.data}");
        throw Exception(
            'Failed to get sub-forum posts: ${response.statusCode} - ${response.data}');
      }
    } on DioException catch (e) {
      print("DioError: ${e.message}");
      print("DioError response: ${e.response?.data}");
      print("DioError type: ${e.type}");
      throw Exception('Network error: ${e.message}');
    } catch (e, stackTrace) {
      print("Unexpected error: $e");
      print("Stack trace: $stackTrace");
      throw Exception('An unexpected error occurred: $e');
    }
  }

  void _handleDioError(DioException e) {
    print("Dio error: ${e.message}");
    if (e.response != null) {
      print("Error response data: ${e.response?.data}");
      if (e.response?.statusCode == 401) {
        Fluttertoast.showToast(msg: "Session expired. Please log in again.");
      } else {
        Fluttertoast.showToast(msg: "Server error: ${e.response?.data}");
      }
    } else {
      Fluttertoast.showToast(msg: "Failed to connect: ${e.message}");
    }
  }

  // REPORT FUNCTIONALITY METHODS

  /// Submit a report for various content types (posts, comments, polls, etc.)
  Future<void> submitReport({
    required String reportedItem,
    required String reason,
    required DateTime reportedAt,
    required ReportType reportedType,
    String? note,
  }) async {
    try {
      print("Submitting report for ${reportedType.toString()}: $reportedItem");
      final String? authToken = await getToken();

      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing. Please log in.');
      }

      final reportData = {
        'reportedItem': reportedItem,
        'reason': reason,
        'reportedAt': reportedAt.toIso8601String(),
        'reportedType': reportedType.toString().split('.').last,
        'note': note ?? '',
        'status': 'pending',
      };

      print("Sending report data: $reportData");

      final Response response = await dio.post(
        '$baseUrl/report',
        data: reportData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print(
          "Submit report response: ${response.statusCode} - ${response.data}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Report submitted successfully. We'll review it shortly.",
          backgroundColor: Colors.green,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      } else if (response.statusCode == 400) {
        final errorData = response.data;
        final errorMessage = errorData['message'] ?? 'Invalid report data';
        throw Exception(errorMessage);
      } else if (response.statusCode == 409) {
        Fluttertoast.showToast(
          msg: "You have already reported this content.",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      } else {
        throw Exception('Failed to submit report: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print("Dio error submitting report: ${e.message}");
      if (e.response != null) {
        print("Error response data: ${e.response?.data}");

        if (e.response?.statusCode == 409) {
          Fluttertoast.showToast(
            msg: "You have already reported this content.",
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          return;
        }

        final errorMessage = e.response?.data['message'] ?? e.message;
        Fluttertoast.showToast(
          msg: "Failed to submit report: $errorMessage",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: "Network error. Please check your connection.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
      throw Exception('Failed to submit report: ${e.message}');
    } catch (e) {
      print("Error submitting report: $e");
      Fluttertoast.showToast(
        msg: "Failed to submit report: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Report a forum post specifically
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? note,
  }) async {
    await submitReport(
      reportedItem: postId,
      reason: reason,
      reportedAt: DateTime.now(),
      reportedType: ReportType.ForumPost,
      note: note,
    );
  }

  /// Report a forum poll specifically
  Future<void> reportPoll({
    required String pollId,
    required String reason,
    String? note,
  }) async {
    await submitReport(
      reportedItem: pollId,
      reason: reason,
      reportedAt: DateTime.now(),
      reportedType: ReportType.ForumPoll,
      note: note,
    );
  }

  /// Report a subforum post specifically
  Future<void> reportSubForumPost({
    required String postId,
    required String reason,
    String? note,
  }) async {
    await submitReport(
      reportedItem: postId,
      reason: reason,
      reportedAt: DateTime.now(),
      reportedType: ReportType.SubForumPost,
      note: note,
    );
  }

  // NEW: Report SubForum poll
  Future<void> reportSubForumPoll({
    required String pollId,
    required String reason,
    String? note,
  }) async {
    await submitReport(
      reportedItem: pollId,
      reason: reason,
      reportedAt: DateTime.now(),
      reportedType: ReportType.SubForumPoll,
      note: note,
    );
  }

// NEW: Get SubForum polls
// Get SubForum polls
  Future<List<SubPollModel>> getSubForumPolls({String? category}) async {
    try {
      print("Fetching sub-forum polls...");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      // Prepare query parameters
      final Map<String, dynamic> queryParams = {};
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      final String url = '$baseUrl/sub-forum-poll/all-polls';
      print("Making request to: $url");
      print("Query parameters: $queryParams");
      final Response response = await dio.get(
        url,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );
      print("Received response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        List<dynamic> subForumPollsData;
        // Handle different response formats
        if (response.data is List) {
          subForumPollsData = response.data;
        } else if (response.data is Map &&
            response.data['subForumPolls'] is List) {
          subForumPollsData = response.data['subForumPolls'];
        } else if (response.data is Map && response.data['polls'] is List) {
          subForumPollsData = response.data['polls'];
        } else {
          throw Exception('Unexpected response format for sub-forum polls');
        }
        print("Converting ${subForumPollsData.length} polls to SubPollModel");
        final List<SubPollModel> convertedPolls = [];
        for (var pollData in subForumPollsData) {
          try {
            final SubPollModel poll = SubPollModel.fromJson(pollData);
            convertedPolls.add(poll);
            print("Successfully converted poll: ${poll.question}");
          } catch (e) {
            print("Error converting poll: $e");
            print("Poll data: $pollData");
          }
        }
        print(
            "Successfully converted ${convertedPolls.length} sub-forum polls");
        return convertedPolls;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again.');
      } else {
        throw Exception(
            'Failed to get sub-forum polls: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Failed to get sub-forum polls: ${e.message}');
    } catch (e) {
      print("Unexpected error in getSubForumPolls: $e");
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

// NEW: Vote on SubForum poll
  Future<void> voteOnSubForumPoll({
    required String pollId,
    required List<int> selectedOptionIndices,
  }) async {
    try {
      final String? authToken = await getToken();
      if (authToken == null) {
        throw Exception('Authentication token is missing');
      }

      final data = {
        "pollId": pollId,
        "selectedOptions": selectedOptionIndices,
      };

      final Response response = await dio.post(
        '$baseUrl/sub-forum-poll/vote',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to vote: ${response.data}');
      }
    } catch (e) {
      print("Error voting on sub-forum poll: $e");
      throw Exception('Failed to vote: $e');
    }
  }

  // **UPDATED SUBFORUM POLL VOTING METHOD FOR NEW API**
  Future<void> voteOnSubForumPollNew({
    required String pollId,
    required List<int> selectedOptionIndices,
  }) async {
    try {
      final String? authToken = await getToken();
      if (authToken == null) {
        throw Exception('Authentication token is missing');
      }

      // **NEW API STRUCTURE**
      final data = {
        "poll": pollId,
        "selectedOptions": selectedOptionIndices,
        "pollType": "SubForumPoll",
      };

      print("Sending SubForum poll vote with new API structure: $data");

      final Response response = await dio.post(
        '$baseUrl/poll-vote',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      print(
          "SubForum poll vote response: ${response.statusCode} - ${response.data}");

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to vote: ${response.data}');
      }
    } catch (e) {
      print("Error voting on sub-forum poll with new API: $e");
      throw Exception('Failed to vote: $e');
    }
  }

///////////////new features /////////
  Future<List<Poll?>> getMyForumPolls() async {
    print('[DEBUG] Starting getMyForumPolls()');
    try {
      // 1. Get authentication token
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing. Please log in.');
      }

      // 2. Make API request
      final Response response = await dio.get(
        '$baseUrl/forum-poll/my-forum-polls',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      // 3. Handle response
      if (response.statusCode == 200) {
        if (response.data is Map && response.data['polls'] is List) {
          final now = DateTime.now().toUtc(); // Get current UTC time

          final polls = (response.data['polls'] as List).map((poll) {
            // Add time validation for each poll
            try {
              final createdAt = DateTime.parse(poll['createdAt']).toUtc();

              // If poll timestamp is in the future (more than 5 minutes tolerance)
              if (createdAt.isAfter(now.add(Duration(minutes: 5)))) {
                print(
                    '[WARNING] Future timestamp detected for poll ${poll['_id']}');
                poll['createdAt'] =
                    now.toIso8601String(); // Adjust to current time
              }

              return Poll.fromJson(poll);
            } catch (e) {
              print(
                  '[ERROR] Invalid timestamp for poll ${poll['_id']}: ${poll['createdAt']}');
              poll['createdAt'] =
                  now.toIso8601String(); // Fallback to current time
              return Poll.fromJson(poll);
            }
          }).toList();

          return polls;
        }
        throw Exception('Unexpected response format');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again.');
      } else {
        throw Exception('Failed to get polls: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print('[DioError] ${e.type}: ${e.message}');
      if (e.response != null) {
        print('Response data: ${e.response?.data}');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e, stackTrace) {
      print('[ERROR] $e\n$stackTrace');
      throw Exception('Failed to load polls');
    }
  }

// Add this to ForumService class
  Future<List<SubPostModel>> getOwnSubForumPosts() async {
    try {
      print("Fetching own sub-forum posts...");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      final Response response = await dio.get(
        '$baseUrl/sub-forum-post/own-sub-forum-posts',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );
      print("Received response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        List<dynamic> subForumPostsData;
        if (response.data is Map && response.data['subForumPosts'] is List) {
          subForumPostsData = response.data['subForumPosts'];
        } else {
          throw Exception('Unexpected response format for own sub-forum posts');
        }
        return subForumPostsData
            .map((post) => SubPostModel.fromJson(post))
            .toList();
      } else {
        throw Exception(
            'Failed to get own sub-forum posts: ${response.statusMessage}');
      }
    } catch (e) {
      print("Error getting own sub-forum posts: $e");
      throw Exception('Failed to get own sub-forum posts: $e');
    }
  }

  // Add this to ForumService class
  Future<List<SubPollModel>> getMySubForumPolls({String? category}) async {
    try {
      print("Fetching my sub-forum polls...");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }
      final Map<String, dynamic> queryParams = {};
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      final Response response = await dio.get(
        '$baseUrl/sub-forum-poll/my-polls',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );
      print("Received response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        List<dynamic> subForumPollsData;
        if (response.data is Map && response.data['subForumPolls'] is List) {
          subForumPollsData = response.data['subForumPolls'];
        } else if (response.data is List) {
          subForumPollsData = response.data;
        } else {
          throw Exception('Unexpected response format for my sub-forum polls');
        }
        return subForumPollsData
            .map((poll) => SubPollModel.fromJson(poll))
            .toList();
      } else {
        throw Exception(
            'Failed to get my sub-forum polls: ${response.statusMessage}');
      }
    } catch (e) {
      print("Error getting my sub-forum polls: $e");
      throw Exception('Failed to get my sub-forum polls: $e');
    }
  }

  /// Update a forum poll
  /// Update a forum poll
  Future<void> updateForumPoll({
    required String pollId,
    String? question,
    List<String>? options,
    bool? allowMultipleAnswers,
  }) async {
    try {
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing. Please log in.');
      }
      final updateData = {
        if (question != null) 'question': question,
        if (options != null) 'options': options,
        if (allowMultipleAnswers != null)
          'allowMultipleAnswers': allowMultipleAnswers,
      };
      final Response response = await dio.patch(
        '$baseUrl/forum-poll/update-forum-poll/$pollId',
        data: updateData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );
      if (response.statusCode == 200) {
        await refreshPolls();
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Poll not found');
      } else {
        throw Exception('Failed to update poll: ${response.data['message']}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? e.message);
      }
      throw Exception('Failed to update poll: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update poll: $e');
    }
  }

  /// Delete a forum poll
  Future<void> deleteForumPoll(String pollId) async {
    try {
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing. Please log in.');
      }
      final Response response = await dio.delete(
        '$baseUrl/forum-poll/remove-forum-poll/$pollId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );
      if (response.statusCode == 200) {
        await refreshPolls();
        return;
      } else if (response.statusCode == 404) {
        throw Exception('Poll not found');
      } else {
        throw Exception('Failed to delete poll: ${response.data['message']}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? e.message);
      }
      throw Exception('Failed to delete poll: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete poll: $e');
    }
  }

  Future<void> updateSubForumPost({
    required String postId,
    required String title,
    required String content,
    required String category,
    required List<String> images,
    List<File>? newImages,
  }) async {
    print("Updating sub-forum post with ID: $postId");
    try {
      final String? authToken = await getToken();
      final updateData = {
        'title': title,
        'content': content,
        'category': category,
        'images': images,
      };

      print("Update data for text content: $updateData");

      // First update the text content and existing images
      final Response textUpdateResponse = await dio.patch(
        '$baseUrl/sub-forum-post/update-sub-forum-post/$postId',
        data: updateData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print(
          "Text update response: ${textUpdateResponse.statusCode} - ${textUpdateResponse.data}");

      if (textUpdateResponse.statusCode != 200) {
        throw Exception('Failed to update sub-forum post text content');
      }

      // If there are new images, upload them separately
      if (newImages != null && newImages.isNotEmpty) {
        print("Processing ${newImages.length} new images for post $postId");
        var tempFormData = FormData.fromMap({
          'title': 'Temp upload for $title',
          'content': 'Temp content for image upload',
          'category': category,
        });

        for (File image in newImages) {
          print("Adding new image to upload: ${image.path}");
          File compressedImage = await compressImage(image);
          tempFormData.files.add(
            MapEntry(
              'files',
              await MultipartFile.fromFile(compressedImage.path,
                  filename: compressedImage.path.split('/').last),
            ),
          );
        }

        final Response imageUploadResponse = await dio.post(
          '$baseUrl/sub-forum-post/create-sub-forum-post',
          data: tempFormData,
          options: Options(
            headers: {'Authorization': 'Bearer $authToken'},
            validateStatus: (status) => status! < 500,
          ),
        );

        print(
            "Image upload response: ${imageUploadResponse.statusCode} - ${imageUploadResponse.data}");

        if (imageUploadResponse.statusCode == 201) {
          await refreshSubForumPosts();
          List<String> uploadedImageUrls = [];
          if (imageUploadResponse.data['images'] != null) {
            uploadedImageUrls =
                List<String>.from(imageUploadResponse.data['images']);
            print("Extracted image URLs: $uploadedImageUrls");

            // Combine existing images with new ones
            List<String> combinedImageUrls = [...images, ...uploadedImageUrls];

            final updateWithImagesData = {
              'images': combinedImageUrls,
            };

            final Response finalUpdateResponse = await dio.patch(
              '$baseUrl/sub-forum-post/update-sub-forum-post/$postId',
              data: updateWithImagesData,
              options: Options(
                headers: {
                  'Authorization': 'Bearer $authToken',
                  'Content-Type': 'application/json',
                },
                validateStatus: (status) => status! < 500,
              ),
            );

            print(
                "Final update response: ${finalUpdateResponse.statusCode} - ${finalUpdateResponse.data}");

            if (finalUpdateResponse.statusCode == 200) {
              await refreshSubForumPosts();
              try {
                // Delete the temporary post used for image upload
                String tempPostId = imageUploadResponse.data['_id'];
                await dio.delete(
                  '$baseUrl/sub-forum-post/delete-sub-forum-post/$tempPostId',
                  options: Options(
                    headers: {'Authorization': 'Bearer $authToken'},
                    validateStatus: (status) => status! < 500,
                  ),
                );
                print("Temporary sub-forum post deleted successfully");
              } catch (e) {
                print("Warning: Failed to delete temporary sub-forum post: $e");
              }
            } else {
              throw Exception('Failed to update post with new image URLs');
            }
          } else {
            print("No images found in temporary post");
            throw Exception('No images were uploaded successfully');
          }
        } else {
          throw Exception(
              'Failed to upload images: ${imageUploadResponse.statusMessage}');
        }
      }
    } catch (e) {
      print("Error updating sub-forum post: $e");
      Fluttertoast.showToast(
        msg: "Failed to update post: ${e.toString()}",
        backgroundColor: Colors.red,
      );
      throw Exception('Failed to update sub-forum post: $e');
    }
  }

  Future<void> deleteSubForumPost(String postId) async {
    try {
      print("Deleting sub-forum post with ID: $postId");
      final String? authToken = await getToken();
      final Response response = await dio.delete(
        '$baseUrl/sub-forum-post/delete-sub-forum-post/$postId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      print("Delete response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: "Sub-forum post deleted successfully");
        await refreshSubForumPosts();
      } else {
        print("Failed to delete sub-forum post: ${response.statusMessage}");
        throw Exception('Failed to delete sub-forum post');
      }
    } catch (e) {
      print("Error deleting sub-forum post: $e");
      throw Exception('Failed to delete sub-forum post: $e');
    }
  }

  Future<void> updateSubForumPoll({
    required String pollId,
    String? question,
    List<String>? options,
    bool? allowMultipleAnswers,
    String? category,
  }) async {
    try {
      // Debug: Print incoming parameters
      print('Updating sub-forum poll with ID: $pollId');
      print('Question update: $question');
      print('Options update: $options');
      print('Allow multiple: $allowMultipleAnswers');
      print('Category update: $category');

      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing. Please log in.');
      }

      // Validate that at least one field is provided for update
      if (question == null &&
          options == null &&
          allowMultipleAnswers == null &&
          category == null) {
        throw Exception('No fields provided for update.');
      }

      final updateData = {
        if (question != null) 'question': question,
        if (options != null) 'options': options,
        if (allowMultipleAnswers != null)
          'allowMultipleAnswers': allowMultipleAnswers,
        if (category != null) 'category': category,
      };

      // Debug: Print the complete update data
      print('Update data being sent: $updateData');

      // Use the full URL to avoid any baseUrl issues
      final String url =
          'https://api.myunivrs.com/sub-forum-poll/update-poll/$pollId';
      print('Making PATCH request to: $url');

      final Response response = await dio.patch(
        url,
        data: updateData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          // Don't throw for 404 - we'll handle it explicitly
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Debug: Print complete response
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: "Poll updated successfully");
        await refreshSubForumPosts();
      } else if (response.statusCode == 404) {
        // More detailed 404 error handling
        if (response.data != null && response.data['message'] != null) {
          throw Exception('Poll not found: ${response.data['message']}');
        } else {
          throw Exception('Poll not found. Please check the poll ID.');
        }
      } else if (response.statusCode == 400) {
        // Handle bad request errors
        final errorMsg = response.data['message'] ?? 'Invalid request data';
        throw Exception('Failed to update poll: $errorMsg');
      } else {
        // Handle other status codes
        final errorMsg = response.data['message'] ?? response.statusMessage;
        throw Exception('Failed to update poll: $errorMsg');
      }
    } on DioException catch (e) {
      // Specific Dio error handling
      print('DioError updating sub-forum poll: ${e.message}');
      print('Error type: ${e.type}');
      if (e.response != null) {
        print('Error response status: ${e.response?.statusCode}');
        print('Error response data: ${e.response?.data}');
      }

      if (e.type == DioExceptionType.connectionError) {
        throw Exception(
            'Network error. Please check your internet connection.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Poll not found. Please check the poll ID.');
      } else {
        throw Exception('Failed to update poll: ${e.message}');
      }
    } catch (e) {
      print("Unexpected error updating sub-forum poll: $e");
      throw Exception('Failed to update poll: ${e.toString()}');
    }
  }

  Future<void> deleteSubForumPoll(String pollId) async {
    try {
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing. Please log in.');
      }

      // Use full URL to avoid any baseUrl issues
      final Response response = await dio.delete(
        'https://api.myunivrs.com/sub-forum-poll/remove-poll/$pollId',
        data: {'id': pollId}, // Some APIs require this
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500, // Important for 400 errors
        ),
      );

      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: "Poll deleted successfully");
        await refreshSubForumPosts();
      } else {
        // Get detailed error message from response
        final errorMsg = response.data['message'] ?? response.statusMessage;
        throw Exception('Failed to delete poll: $errorMsg');
      }
    } catch (e) {
      print("Error deleting sub-forum poll: $e");
      throw Exception('Failed to delete poll: ${e.toString()}');
    }
  }

  /// Delete a forum poll

//pavan's

// **NEW FAVORITE/SAVE FUNCTIONALITY**

  /// Save/Favorite a post
  Future<void> savePost({
    required String postId,
    required String itemType,
  }) async {
    try {
      print("Saving post: $postId of type: $itemType");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }

      final requestData = {
        'item': postId,
        'itemType': itemType,
      };

      print("Save request data: $requestData");

      final Response response = await dio.post(
        '$baseUrl/saved',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("Save response: ${response.statusCode} - ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        Fluttertoast.showToast(
          msg: "Post saved to favorites!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        throw Exception('Failed to save post: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print("Dio error saving post: ${e.message}");
      if (e.response?.statusCode == 409) {
        Fluttertoast.showToast(
          msg: "Post is already in favorites!",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      } else {
        _handleDioError(e);
        throw Exception('Failed to save post: ${e.message}');
      }
    } catch (e) {
      print("Error saving post: $e");
      throw Exception('Failed to save post: $e');
    }
  }

  /// Remove from favorites
  Future<void> unsavePost({
    required String postId,
    required String itemType,
  }) async {
    try {
      print("Removing post from favorites: $postId of type: $itemType");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }

      final Response response = await dio.delete(
        '$baseUrl/saved',
        queryParameters: {
          'itemId': postId,
          'itemType': itemType,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("Unsave response: ${response.statusCode} - ${response.data}");

      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Post removed from favorites!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        throw Exception(
            'Failed to remove from favorites: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Failed to remove from favorites: ${e.message}');
    } catch (e) {
      print("Error removing from favorites: $e");
      throw Exception('Failed to remove from favorites: $e');
    }
  }

  /// Get all saved/favorite posts
  Future<List<String>> getAllSavedItems() async {
    try {
      print("Fetching all saved items...");
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }

      final Response response = await dio.get(
        '$baseUrl/saved',
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print(
          "Get all saved items response: ${response.statusCode} - ${response.data}");

      if (response.statusCode == 200) {
        final List<dynamic> savedItems =
            response.data['savedItems'] ?? response.data ?? [];

        // Extract all item IDs regardless of type
        List<String> savedItemIds = [];
        for (var item in savedItems) {
          if (item is Map<String, dynamic>) {
            String? itemId =
                item['item']?['_id'] ?? item['item'] ?? item['itemId'];

            if (itemId != null) {
              savedItemIds.add(itemId);
            }
          }
        }

        print("Extracted ${savedItemIds.length} saved item IDs (all types)");
        return savedItemIds;
      } else {
        throw Exception('Failed to get saved items: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Failed to get saved items: ${e.message}');
    } catch (e) {
      print("Error getting saved items: $e");
      throw Exception('Failed to get saved items: $e');
    }
  }

  /// Check if a specific post is saved
  Future<bool> isItemSaved(String itemId) async {
    try {
      final savedItemIds = await getAllSavedItems();
      return savedItemIds.contains(itemId);
    } catch (e) {
      print("Error checking if item is saved: $e");
      return false;
    }
  }
}
