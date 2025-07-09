import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myunivrs/core/utils/custom_container.dart';
import 'package:myunivrs/core/utils/custom_text.dart';

import 'package:myunivrs/modules/groups/widgets/customtextfeild.dart';
import 'package:myunivrs/shared/widgets/app_buttons/app_main_button.dart';
import 'package:dio/dio.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';
import 'package:myunivrs/features/forum/subForum/services/SubPostService.dart';

class SubPostScreen extends StatefulWidget {
  const SubPostScreen({super.key});

  @override
  State<SubPostScreen> createState() => _SubPostScreenState();
}

class _SubPostScreenState extends State<SubPostScreen> {
  final List<String> _categories = [
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

  final postContentController = TextEditingController();
  final postTitleController = TextEditingController();
  final newCategoryController = TextEditingController();
  List<File> postImageFiles = [];
  String? _selectedPostCategory;
  bool _showNewCategoryField = false;
  final SubPostService _subPostService = SubPostService(Dio());

  @override
  void dispose() {
    postContentController.dispose();
    postTitleController.dispose();
    newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _selectImages({required List<File> targetList}) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> selectedImages = await picker.pickMultiImage();
    if (selectedImages.isNotEmpty) {
      setState(() {
        targetList.addAll(selectedImages.map((image) => File(image.path)));
      });
    }
  }

  void _removeImage(int index, {required List<File> targetList}) {
    setState(() {
      targetList.removeAt(index);
    });
  }

  void _addNewCategory(String category) {
    if (category.trim().isNotEmpty && !_categories.contains(category.trim())) {
      setState(() {
        _categories.add(category.trim());
        _selectedPostCategory = category.trim();
        _showNewCategoryField = false;
        newCategoryController.clear();
      });
    } else if (_categories.contains(category.trim())) {
      Fluttertoast.showToast(msg: "Category already exists!");
    }
  }

  Future<void> createPost() async {
    if (_showNewCategoryField && newCategoryController.text.isNotEmpty) {
      _selectedPostCategory = newCategoryController.text.trim();
      _addNewCategory(_selectedPostCategory!);
    }

    if (postTitleController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Post title is required");
      return;
    }
    if (postContentController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Post content is required");
      return;
    }
    if (_selectedPostCategory == null || _selectedPostCategory!.isEmpty) {
      Fluttertoast.showToast(
          msg: "Please select or add a category for your post");
      return;
    }

    try {
      final post = SubPostModel(
        title: postTitleController.text,
        content: postContentController.text,
        images: [], // Images handled by service
        upvotes: 0,
        downvotes: 0,
        isPinned: false,
        isClosed: false,
        status: 'active',
        category: _selectedPostCategory!,
        author: Author(
          id: 'current_user_id', // Replace with actual user ID
          email: '',
        ),
        createdAt: DateTime.now(), // Or make this nullable in your model
        commentCount: 0, // Or make this nullable in your model
      );

      await _subPostService.createSubForumPost(post, postImageFiles);

      Fluttertoast.showToast(
        msg: "Post created successfully",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.pop(context);
    } catch (e) {
      Get.snackbar("Error", "Failed to create post: $e",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      print("Error creating post: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          const CustomContainer(title: "Post Information"),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          const CustomText(
            lable: "Post Title",
            fontsize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E8E),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          CustomTextfeild(
            minlines: 1,
            maxlines: 1,
            controller: postTitleController,
            hinttext: "Enter your post title here",
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          const CustomText(
            lable: "Post Content",
            fontsize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E8E),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          CustomTextfeild(
            minlines: 4,
            maxlines: 4,
            controller: postContentController,
            hinttext: "Enter your post content here",
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          const CustomText(
            lable: "Category",
            fontsize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E8E),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedPostCategory,
                hint: const Text("Select a category"),
                icon: const Icon(Icons.arrow_drop_down),
                elevation: 16,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPostCategory = newValue;
                    _showNewCategoryField = newValue == 'add_new_category';
                    if (!_showNewCategoryField) newCategoryController.clear();
                  });
                },
                items: [
                  ..._categories.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  const DropdownMenuItem<String>(
                    value: 'add_new_category',
                    child: Text('Add New Category...',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.blue)),
                  ),
                ],
              ),
            ),
          ),
          if (_showNewCategoryField)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                CustomTextfeild(
                  controller: newCategoryController,
                  hinttext: "Enter new category name",
                  minlines: 1,
                  maxlines: 1,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: Color.fromARGB(255, 42, 206, 235)),
                    onPressed: () {
                      _addNewCategory(newCategoryController.text);
                    },
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _showNewCategoryField = false;
                        _selectedPostCategory = null;
                        newCategoryController.clear();
                      });
                    },
                    child: const Text("Cancel Add New Category"),
                  ),
                )
              ],
            ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          const CustomText(
            lable: "Upload Images (Optional)",
            fontsize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E8E),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          GestureDetector(
            onTap: () => _selectImages(targetList: postImageFiles),
            child: DottedBorder(
              strokeWidth: 1,
              dashPattern: const [8, 4],
              color: Colors.grey,
              borderType: BorderType.RRect,
              radius: const Radius.circular(10),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.06,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    "UPLOAD IMAGES",
                    style: TextStyle(
                      color: Color.fromARGB(255, 39, 191, 202),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          if (postImageFiles.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: postImageFiles.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(postImageFiles[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () =>
                              _removeImage(index, targetList: postImageFiles),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Center(
            child: AppMainButton(
              text: "Create Post",
              onPressed: createPost,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        ],
      ),
    );
  }
}
