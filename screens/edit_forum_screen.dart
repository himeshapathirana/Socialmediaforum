import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myunivrs/features/event/widgets/event_pickimage.dart';
import 'package:myunivrs/features/forum/controller/forum_controller.dart';
import 'package:myunivrs/features/forum/models/forum_model.dart';
import 'package:myunivrs/shared/widgets/app_buttons/app_main_button.dart';
import '../../../core/styles/colors.dart';
import '../../../core/utils/app_bar_common.dart';
import '../../../core/utils/custom_text.dart';
import '../../../core/utils/custom_container.dart';
import '../../../modules/groups/widgets/customtextfeild.dart';

class EditForumScreen extends StatefulWidget {
  final ForumModel post;
  const EditForumScreen({super.key, required this.post});

  @override
  State<EditForumScreen> createState() => _EditForumScreenState();
}

class _EditForumScreenState extends State<EditForumScreen> {
  final ForumController _forumController = Get.find();
  List<File> imageFiles = [];
  List<String> existingImages = [];
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  List<File> newImageFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data
    titleController.text = widget.post.title ?? '';
    contentController.text = widget.post.content ?? '';
    if (widget.post.images != null) {
      existingImages = [...widget.post.images!];
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      existingImages.removeAt(index);
    });
  }

  Future<void> _selectImages() async {
    final List<XFile> selectedImages = await _picker.pickMultiImage();
    if (selectedImages.isNotEmpty) {
      setState(() {
        newImageFiles.addAll(selectedImages.map((image) => File(image.path)));
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      newImageFiles.removeAt(index);
    });
  }

  Future<void> updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the values directly from the form
      final newTitle = titleController.text.trim();
      final newContent = contentController.text.trim();

      print("Form values - Title: $newTitle");
      print("Form values - Content: $newContent");
      print("Form values - Existing images: $existingImages");
      print("Form values - New images count: ${newImageFiles.length}");

      // Create an updated forum model with the complete data
      final updatedForum = ForumModel(
        id: widget.post.id,
        title: newTitle,
        content: newContent,
        images: existingImages,
        upvotes: widget.post.upvotes,
        downvotes: widget.post.downvotes,
        isPinned: widget.post.isPinned,
        isClosed: widget.post.isClosed,
        status: widget.post.status,
        author: widget.post.author,
        commentCount: widget.post.commentCount,
      );

      final updatedPost = await _forumController.updatePost(
        updatedForum,
        widget.post.id!,
        newImageFiles.isNotEmpty ? newImageFiles : null,
      );

      // Make sure controller loading state is reset before navigation
      _forumController.resetLoadingState();

      // Navigate back with just success flag, not any complex object
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print("Error updating post: $e");
      Fluttertoast.showToast(
        msg: "Failed to update post: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
      );
      // Reset controller loading state on error too
      _forumController.resetLoadingState();
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
                    child: Text("Edit Forum Post",
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
                      controller: titleController,
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
                      lable: "Content",
                      fontsize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E8E),
                    ),
                    SizedBox(height: height * 0.01),
                    CustomTextfeild(
                      minlines: 4,
                      maxlines: 4,
                      controller: contentController,
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
                    if (existingImages.isNotEmpty)
                      Container(
                        height: 100,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: existingImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 100,
                                  height: 100,
                                  child: CachedNetworkImage(
                                    imageUrl: existingImages[index],
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
                      onTap: _selectImages,
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
                    if (newImageFiles.isNotEmpty)
                      Container(
                        height: 100,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: newImageFiles.length,
                          itemBuilder: (context, index) => Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(newImageFiles[index]),
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
                    // Replace the current button with AppMainButton
                    AppMainButton(
                      onPressed: () async {
                        await updatePost();
                      },
                      text: "UPDATE POST",
                      isLoading: _isLoading,
                      width: double.infinity,
                      height: 55,
                      backgroundColor: const Color(0xFF27BFCA),
                      textColor: Colors.white,
                      borderRadius: 10,
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
    // Ensure loading state is cleared when leaving screen
    _forumController.resetLoadingState();
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }
}
