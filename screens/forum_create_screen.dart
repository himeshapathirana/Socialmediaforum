import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myunivrs/core/utils/custom_container.dart';
import 'package:myunivrs/core/utils/custom_text.dart';
import 'package:myunivrs/features/forum/controller/forum_controller.dart';
import 'package:myunivrs/features/forum/models/forum_model.dart';
import 'package:myunivrs/modules/groups/widgets/customtextfeild.dart';
import 'package:myunivrs/features/forum/poll/CreatePoll.dart';
import 'package:myunivrs/shared/widgets/app_buttons/app_main_button.dart';
import 'package:myunivrs/features/forum/subForum/screens/CreateSubForum.dart';
import '../../../core/styles/colors.dart';
import '../../../core/utils/app_bar_common.dart';

class ForumCreation extends StatefulWidget {
  const ForumCreation({super.key});

  @override
  State<ForumCreation> createState() => _ForumCreationState();
}

class _ForumCreationState extends State<ForumCreation>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ForumController _forumController = Get.find();
  List<File> imageFiles = [];
  final descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String? _validateDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'Description is required';
    }
    return null;
  }

  Future<void> _selectImages() async {
    final List<XFile> selectedImages = await _picker.pickMultiImage();
    if (selectedImages.isNotEmpty) {
      setState(() {
        imageFiles.addAll(selectedImages.map((image) => File(image.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      imageFiles.removeAt(index);
    });
  }

  Future<void> createPost() async {
    final descriptionError = _validateDescription(descriptionController.text);

    if (descriptionError != null) {
      Fluttertoast.showToast(msg: descriptionError);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    ForumModel forum = ForumModel(
      title: descriptionController.text,
      content: descriptionController.text,
      upvotes: 0,
      downvotes: 0,
      isPinned: false,
      isClosed: false,
    );

    try {
      await _forumController.createPost(
          forum, imageFiles.isEmpty ? null : imageFiles);

      Fluttertoast.showToast(
        msg: "Forum created successfully",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      await _forumController.getPosts(1, 10);
      Navigator.pop(context);
    } catch (e) {
      Get.snackbar(
        "Error",
        "Something went wrong",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height > size.width;
    final isSmallScreen = size.shortestSide < 600;

    return Scaffold(
      backgroundColor: lightColorScheme.surface,
      appBar: const MyAppBarCommon(),
      body: SafeArea(
        child: Column(
          children: [
            // Responsive Tab Bar - Improved version
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : size.width * 0.1,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate the available width for each tab
                  final tabWidth = constraints.maxWidth / 3;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: tabWidth <
                          120, // Enable scrolling if tabs are too narrow
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      indicatorPadding: const EdgeInsets.all(4),
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: [
                        // New Post Tab
                        SizedBox(
                          width: tabWidth < 120
                              ? null
                              : tabWidth, // Use auto width if scrollable
                          child: const Tab(
                            text: "New Post",
                          ),
                        ),
                        // New Poll Tab
                        SizedBox(
                          width: tabWidth < 120 ? null : tabWidth,
                          child: const Tab(
                            text: "New Poll",
                          ),
                        ),
                        // Subforum Tab
                        SizedBox(
                          width: tabWidth < 120 ? null : tabWidth,
                          child: const Tab(
                            text: "Subforum",
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // New Post Tab
                  SingleChildScrollView(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: Form(
                      key: _formKey,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : size.width * 0.1,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: isSmallScreen ? 12 : 20),
                            const CustomContainer(title: "Forum Information"),
                            SizedBox(height: isSmallScreen ? 12 : 20),
                            const CustomText(
                              lable: "Content",
                              fontsize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF8E8E8E),
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            CustomTextfeild(
                              minlines: 4,
                              maxlines: 8,
                              controller: descriptionController,
                              hinttext: "Enter your text here",
                              validator: _validateDescription,
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 20),
                            const CustomText(
                              lable: "Upload images (optional)",
                              fontsize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF8E8E8E),
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            GestureDetector(
                              onTap: _selectImages,
                              child: DottedBorder(
                                strokeWidth: 1,
                                dashPattern: const [8, 4],
                                color: Colors.grey,
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(10),
                                child: Container(
                                  height: isSmallScreen ? 50 : 60,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "UPLOAD IMAGES",
                                      style: TextStyle(
                                        color: const Color.fromARGB(
                                            255, 39, 191, 202),
                                        fontSize: isSmallScreen ? 16 : 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 20),
                            if (imageFiles.isNotEmpty)
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isPortrait ? 3 : 5,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                                itemCount: imageFiles.length,
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          imageFiles[index],
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        right: 5,
                                        top: 5,
                                        child: GestureDetector(
                                          onTap: () => _removeImage(index),
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
                            SizedBox(height: isSmallScreen ? 20 : 30),
                            Center(
                              child: Obx(
                                () => SizedBox(
                                  width: isSmallScreen
                                      ? size.width * 0.9
                                      : size.width * 0.4,
                                  child: AppMainButton(
                                    isLoading: _forumController.isLoading.value,
                                    text: _forumController.isLoading.value
                                        ? "Creating..."
                                        : "Create a Forum",
                                    onPressed: () async {
                                      if (!_forumController.isLoading.value) {
                                        await createPost();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 20 : 30),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const CreatePollScreen(),

                  const CreateSubForumScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
