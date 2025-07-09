import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/api/api_config.dart';
import 'package:myunivrs/shared/shared_pref.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';

class SubPollService {
  final Dio dio;
  final String baseUrl = apiUrl;

  SubPollService(this.dio);

  Future<String?> getToken() async {
    print("Fetching token...");
    String? token = await SharedPref.getToken();
    print("Token fetched: $token");
    return token;
  }

  Future<void> createSubForumPoll(SubPollModel poll) async {
    print("Preparing data for createSubForumPoll...");

    // Create a modified copy of the poll with UTC timestamps
    final data = {
      ...poll.toJson(),
      'createdAt': poll.createdAt.toUtc().toIso8601String(),
      'updatedAt': poll.updatedAt.toUtc().toIso8601String(),
      'clientTimeZone': DateTime.now().timeZoneName,
      'clientTimeZoneOffset': DateTime.now().timeZoneOffset.inHours,
    };

    print("Data prepared with UTC times: $data");

    try {
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }

      print(
          "Sending createSubForumPoll request to $baseUrl/sub-forum-poll/create-poll");
      final Response response = await dio.post(
        '$baseUrl/sub-forum-poll/create-poll',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      print("Received response: ${response.statusCode} - ${response.data}");
      if (response.statusCode == 201 || response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: "Poll created successfully",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        print("Failed to create poll: ${response.data}");
        Fluttertoast.showToast(msg: "Failed to create poll: ${response.data}");
      }
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception('Failed to create poll: ${e.message}');
    } catch (e) {
      print("Unexpected error in createSubForumPoll: $e");
      Fluttertoast.showToast(
          msg: "An unexpected error occurred: ${e.toString()}");
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<List<SubPollModel>> getSubforumPolls(String category) async {
    try {
      final String? authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Authentication token is missing or invalid');
      }

      final response = await dio.get(
        '$baseUrl/sub-forum-poll/all-polls',
        queryParameters: {'category': category},
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['polls'] ?? [];
        return data.map((pollJson) => SubPollModel.fromJson(pollJson)).toList();
      } else {
        throw Exception(
            'Failed to load polls with status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Failed to load polls: ${e.message}');
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
}
