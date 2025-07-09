import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class SubPostService {
  final Dio dio;
  final String baseUrl = apiUrl;

  SubPostService(this.dio);

  Future<String?> getToken() async {
    try {
      final token = await SharedPref.getToken();
      return token;
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  Future<File> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = file.path.split('/').last;
      final image = img.decodeImage(await file.readAsBytes())!;

      // Calculate target height while maintaining aspect ratio
      const targetWidth = 800;
      final targetHeight = (targetWidth * image.height / image.width).round();

      final resized = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );

      final compressedImageFile = File('${tempDir.path}/compressed_$fileName')
        ..writeAsBytesSync(img.encodeJpg(resized, quality: 70));

      return compressedImageFile;
    } catch (e) {
      print('Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }

  Future<void> createSubForumPost(SubPostModel post, List<File>? images) async {
    try {
      print("Preparing formData for createSubForumPost...");

      // Prepare the basic form data
      final formDataMap = {
        'title': post.title,
        'content': post.content,
        'category': post.category, // Added category field
        'upvotes': post.upvotes.toString(),
        'downvotes': post.downvotes.toString(),
        'isPinned': post.isPinned.toString(),
        'isClosed': post.isClosed.toString(),
        'status': post.status,
      };

      // Log form data
      formDataMap.forEach((key, value) {
        print("Form Data - $key: $value");
      });

      var formData = FormData.fromMap(formDataMap);

      // Handle images
      if (images != null && images.isNotEmpty) {
        for (File image in images) {
          print("Adding image to formData: ${image.path}");
          try {
            File compressedImage = await compressImage(image);
            formData.files.add(
              MapEntry(
                'files', // Changed from 'images' to match your working forum implementation
                await MultipartFile.fromFile(
                  compressedImage.path,
                  filename: compressedImage.path.split('/').last,
                ),
              ),
            );
          } catch (e) {
            print("Error processing image ${image.path}: $e");
            // Continue with other images if one fails
          }
        }
      }

      print("FormData prepared with ${formData.files.length} images");

      // Get auth token
      final String? authToken = await getToken();
      if (authToken == null) {
        throw Exception('Authentication token is missing');
      }

      print("Sending request to $baseUrl/sub-forum-post/create-sub-forum-post");

      // Make the request
      final Response response = await dio.post(
        '$baseUrl/sub-forum-post/create-sub-forum-post',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("Response status: ${response.statusCode}");
      print("Response data: ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        Fluttertoast.showToast(
          msg: "Sub-forum post created successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        String errorMessage = "Failed to create post";
        if (response.data != null && response.data is Map) {
          errorMessage += ": ${response.data['message'] ?? response.data}";
        }
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      String errorMessage = "Network error: ${e.message}";
      if (e.response != null) {
        errorMessage =
            "Server error: ${e.response?.data['message'] ?? e.response?.data}";
      }
      print(errorMessage);
      Fluttertoast.showToast(
        msg: errorMessage,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print("Unexpected error: $e");
      Fluttertoast.showToast(
        msg: "An unexpected error occurred: ${e.toString()}",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<List<SubPostModel>> getSubforumPosts(String category) async {
    try {
      final response = await dio.get(
        '$baseUrl/sub-forum-post/all-sub-forum-posts',
        queryParameters: {'category': category},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['subForumPosts'] ?? [];
        return data.map((postJson) => SubPostModel.fromJson(postJson)).toList();
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to load subforum posts: ${e.message}');
    }
  }

  void _handleDioError(DioException e) {
    final errorMessage = e.response != null
        ? 'Server error: ${e.response?.data['message'] ?? e.response?.data}'
        : 'Network error: ${e.message}';

    _showErrorToast(errorMessage);
    print('Dio error: $errorMessage');
  }

  void _handleErrorResponse(Response response) {
    final errorMessage = response.data is Map
        ? response.data['message'] ?? 'Failed to create post'
        : 'Failed to create post: ${response.statusCode}';

    _showErrorToast(errorMessage);
    throw Exception(errorMessage);
  }

  void _handleGenericError(dynamic e) {
    final errorMessage = 'An unexpected error occurred: ${e.toString()}';
    _showErrorToast(errorMessage);
    print(errorMessage);
    throw Exception(errorMessage);
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  // Add these methods to your SubPostService class

  /// Update a sub-forum post
  // Add these methods to your ForumService class

  /// Update a sub-forum post

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }
}
