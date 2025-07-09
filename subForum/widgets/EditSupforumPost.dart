import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/shared/widgets/app_buttons/app_main_button.dart';
import 'package:myunivrs/core/styles/colors.dart';
import 'package:myunivrs/core/utils/app_bar_common.dart';
import 'package:myunivrs/core/utils/custom_text.dart';
import 'package:myunivrs/core/utils/custom_container.dart';
import 'package:myunivrs/modules/groups/widgets/customtextfeild.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPostModel.dart';

class EditSubForumPostScreen extends StatefulWidget {
  final SubPostModel post;
  const EditSubForumPostScreen({Key? key, required this.post})
      : super(key: key);

  @override
  State<EditSubForumPostScreen> createState() => _EditSubForumPostScreenState();
}

class _EditSubForumPostScreenState extends State<EditSubForumPostScreen> {
  final ForumService _forumService = ForumService(Dio());
  List<File> _newImageFiles = [];
  List<String> _existingImages = [];
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.post.title;
    _contentController.text = widget.post.content;
    _categoryController.text = widget.post.category;
    _existingImages = List.from(widget.post.images);
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> selectedImages = await _picker.pickMultiImage();
      if (selectedImages.isNotEmpty) {
        setState(() {
          _newImageFiles
              .addAll(selectedImages.map((image) => File(image.path)));
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to pick images: ${e.toString()}");
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
    });
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _forumService.updateSubForumPost(
        postId: widget.post.id!,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _categoryController.text.trim(),
        images: _existingImages,
        newImages: _newImageFiles.isNotEmpty ? _newImageFiles : null,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        Fluttertoast.showToast(msg: "Post updated successfully");
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to update post: ${e.toString()}",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePost() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _forumService.deleteSubForumPost(widget.post.id!);
      if (mounted) {
        Navigator.of(context).pop(true);
        Fluttertoast.showToast(msg: "Post deleted successfully");
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to delete post: ${e.toString()}",
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: lightColorScheme.surface,
      appBar: const MyAppBarCommon(),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: height * 0.12,
                color: const Color.fromARGB(255, 237, 237, 237),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 25),
                    child: Text("Edit Sub-Forum Post",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                color: const Color.fromARGB(255, 237, 237, 237),
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: height * 0.02),
                    const CustomText(
                      lable: "Title",
                      fontsize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E8E),
                    ),
                    SizedBox(height: height * 0.01),
                    CustomTextfeild(
                      controller: _titleController,
                      hinttext: "Enter post title",
                      minlines: 1,
                      maxlines: 1,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: height * 0.02),
                    const CustomText(
                      lable: "Category",
                      fontsize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E8E),
                    ),
                    SizedBox(height: height * 0.01),
                    CustomTextfeild(
                      controller: _categoryController,
                      hinttext: "Enter category",
                      minlines: 1,
                      maxlines: 1,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Category is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: height * 0.02),
                    const CustomText(
                      lable: "Content",
                      fontsize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E8E),
                    ),
                    SizedBox(height: height * 0.01),
                    CustomTextfeild(
                      minlines: 4,
                      maxlines: 4,
                      controller: _contentController,
                      hinttext: "Enter your text here",
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Content is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: height * 0.02),
                    // Existing Images
                    if (_existingImages.isNotEmpty)
                      Container(
                        height: 100,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _existingImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 100,
                                  height: 100,
                                  child: CachedNetworkImage(
                                    imageUrl: _existingImages[index],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeExistingImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    // Upload New Images
                    GestureDetector(
                      onTap: _pickImages,
                      child: DottedBorder(
                        strokeWidth: 1,
                        dashPattern: const [8, 4],
                        color: Colors.grey,
                        borderType: BorderType.RRect,
                        radius: const Radius.circular(10),
                        child: Container(
                          height: height * 0.06,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              "UPLOAD NEW IMAGES",
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
                    // New Images Preview
                    if (_newImageFiles.isNotEmpty)
                      Container(
                        height: 100,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _newImageFiles.length,
                          itemBuilder: (context, index) => Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(_newImageFiles[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => _removeNewImage(index),
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
                          ),
                        ),
                      ),
                    SizedBox(height: height * 0.03),
                    Row(
                      children: [
                        Expanded(
                          child: AppMainButton(
                            onPressed: _updatePost,
                            text: "UPDATE POST",
                            isLoading: _isLoading,
                            width: double.infinity,
                            height: 55,
                            backgroundColor: const Color(0xFF27BFCA),
                            textColor: Colors.white,
                            borderRadius: 10,
                          ),
                        ),
                        SizedBox(width: width * 0.03),
                      ],
                    ),
                    SizedBox(height: height * 0.05),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
}
