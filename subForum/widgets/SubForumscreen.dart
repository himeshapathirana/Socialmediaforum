import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:myunivrs/features/forum/subForum/widgets/SubForumPostCard.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SubForumPosts extends StatefulWidget {
  const SubForumPosts(
      {Key? key, required int index, required Map<String, Object> post})
      : super(key: key);

  @override
  _SubForumPostsState createState() => _SubForumPostsState();
}

class _SubForumPostsState extends State<SubForumPosts> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String? error;
  String category = '';

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      setState(() {
        isLoading = true;
      });
      final response = await http.get(
        Uri.parse(
            'https://api.myunivrs.com/sub-forum-post/all-sub-forum-posts?category=$category'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          posts = data['subForumPosts'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load posts';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching posts: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sub-Forum Posts'),
      ),
      body: Padding(
        padding: EdgeInsets.all(width * 0.04),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Filter by Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  category = value;
                });
                fetchPosts();
              },
            ),
            SizedBox(height: height * 0.02),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(error!))
                      : posts.isEmpty
                          ? const Center(child: Text('No posts found'))
                          : ListView.builder(
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                return SubForumPostCard(
                                  index: index,
                                  post: post,
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
