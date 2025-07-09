import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:myunivrs/core/utils/custom_container.dart';
import 'package:myunivrs/core/utils/custom_text.dart';
import 'package:myunivrs/modules/groups/widgets/customtextfeild.dart';
import 'package:myunivrs/shared/widgets/app_buttons/app_main_button.dart';
import 'package:dio/dio.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:myunivrs/features/forum/subForum/services/SubPollService.dart';

class SubPollScreen extends StatefulWidget {
  const SubPollScreen({super.key});

  @override
  State<SubPollScreen> createState() => _SubPollScreenState();
}

class _SubPollScreenState extends State<SubPollScreen> {
  final List<String> _categories = [
    'General',
    'Academics',
    'Events',
    'Announcements',
    'Discussions',
    'Campus Life',
    'Student Feedback',
    'Course Preferences',
    'Social Activities',
    'Technology & Innovation',
    'Sports',
    'Food & Dining',
    'University Policy',
  ];

  final pollQuestionController = TextEditingController();
  final List<TextEditingController> pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final newCategoryController = TextEditingController();
  bool _allowMultipleOptions = false;
  String? _selectedPollCategory;
  bool _showNewCategoryField = false;
  final SubPollService _subPollService = SubPollService(Dio());

  // Add these variables to store current user information
  String? _currentUserId;
  String? _currentUserEmail;
  String? _currentUserFirstName;
  String? _currentUserLastName;
  String? _currentUserProfileName;
  String? _currentUserInstitution;
  String? _currentUserPhoneNumber;
  String? _currentUserProfilePic;
  bool _currentUserIsAdmin = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current user data (you would get this from your auth system)
    _initializeCurrentUser();
  }

  void _initializeCurrentUser() {
    // TODO: Replace with actual user data from your authentication system
    setState(() {
      _currentUserId = 'current_user_id'; // Get from auth
      _currentUserEmail = 'user@example.com'; // Get from auth
      _currentUserFirstName = 'John'; // Get from user profile
      _currentUserLastName = 'Doe'; // Get from user profile
      _currentUserProfileName = 'johndoe'; // Get from user profile
      _currentUserIsAdmin = false; // Get from user permissions
    });
  }

  Author _getCurrentUserAuthor() {
    return Author(
      id: _currentUserId ?? '',
      firstName: _currentUserFirstName,
      lastName: _currentUserLastName,
      profileName: _currentUserProfileName,
      institution: _currentUserInstitution,
      email: _currentUserEmail,
      phoneNumber: _currentUserPhoneNumber,
      profilePic: _currentUserProfilePic,
      isAdmin: _currentUserIsAdmin,
    );
  }

  @override
  void dispose() {
    pollQuestionController.dispose();
    for (var controller in pollOptionControllers) {
      controller.dispose();
    }
    newCategoryController.dispose();
    super.dispose();
  }

  void _addPollOption() {
    setState(() {
      pollOptionControllers.add(TextEditingController());
    });
  }

  void _removePollOption(int index) {
    if (pollOptionControllers.length > 2) {
      setState(() {
        pollOptionControllers.removeAt(index);
      });
    }
  }

  void _addNewCategory(String category) {
    if (category.trim().isNotEmpty && !_categories.contains(category.trim())) {
      setState(() {
        _categories.add(category.trim());
        _selectedPollCategory = category.trim();
        _showNewCategoryField = false;
        newCategoryController.clear();
      });
    } else if (_categories.contains(category.trim())) {
      Fluttertoast.showToast(msg: "Category already exists!");
    }
  }

  Future<void> createPoll() async {
    if (_showNewCategoryField && newCategoryController.text.isNotEmpty) {
      _selectedPollCategory = newCategoryController.text.trim();
      _addNewCategory(_selectedPollCategory!);
    }

    if (pollQuestionController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Poll question is required");
      return;
    }
    for (var controller in pollOptionControllers) {
      if (controller.text.isEmpty) {
        Fluttertoast.showToast(msg: "All poll options must be filled");
        return;
      }
    }
    if (_selectedPollCategory == null || _selectedPollCategory!.isEmpty) {
      Fluttertoast.showToast(
          msg: "Please select or add a category for your poll");
      return;
    }
    if (pollOptionControllers.length < 2) {
      Fluttertoast.showToast(msg: "Please provide at least two poll options");
      return;
    }

    try {
      final poll = SubPollModel(
        question: pollQuestionController.text,
        options: pollOptionControllers.map((c) => c.text).toList(),
        author: _getCurrentUserAuthor(), // Use the method to get current user
        allowMultipleAnswers: _allowMultipleOptions,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        upvotes: 0,
        downvotes: 0,
        comments: 0,
        totalVotes: 0,
        optionStats: pollOptionControllers
            .map((option) => OptionStat(
                  option: option.text,
                  count: 0,
                  percentage: 0.0,
                ))
            .toList(),
        isPinned: false,
        isClosed: false,
        status: 'active',
        category: _selectedPollCategory!,
      );

      await _subPollService.createSubForumPoll(poll);

      Fluttertoast.showToast(
        msg: "Poll created successfully",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.pop(context);
    } catch (e) {
      Get.snackbar("Error", "Failed to create poll: $e",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      print("Error creating poll: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          const CustomContainer(title: "Poll Information"),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          const CustomText(
            lable: "Poll Question",
            fontsize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E8E),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          CustomTextfeild(
            minlines: 2,
            maxlines: 2,
            controller: pollQuestionController,
            hinttext: "Enter your poll question",
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          const CustomText(
            lable: "Poll Options",
            fontsize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E8E),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pollOptionControllers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomTextfeild(
                        minlines: 1,
                        maxlines: 1,
                        controller: pollOptionControllers[index],
                        hinttext: "Option ${index + 1}",
                      ),
                    ),
                    if (pollOptionControllers.length > 2)
                      IconButton(
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removePollOption(index),
                      ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          TextButton(
            onPressed: _addPollOption,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.blue),
                SizedBox(width: 5),
                Text("Add Option", style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const CustomText(
                lable: "Allow Multiple Options",
                fontsize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8E8E8E),
              ),
              Switch(
                value: _allowMultipleOptions,
                onChanged: (bool value) {
                  setState(() {
                    _allowMultipleOptions = value;
                  });
                },
                activeColor: Colors.blue,
              ),
            ],
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
                value: _selectedPollCategory,
                hint: const Text("Select a category"),
                icon: const Icon(Icons.arrow_drop_down),
                elevation: 16,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                onChanged: (String? newValue) {
                  setState(() {
                    if (newValue == 'add_new_category') {
                      _selectedPollCategory = null;
                      _showNewCategoryField = true;
                    } else {
                      _selectedPollCategory = newValue;
                      _showNewCategoryField = false;
                      newCategoryController.clear();
                    }
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
                        color: Color.fromARGB(255, 49, 196, 233)),
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
                        _selectedPollCategory = null;
                        newCategoryController.clear();
                      });
                    },
                    child: const Text("Cancel Add New Category"),
                  ),
                )
              ],
            ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Center(
            child: AppMainButton(
              text: "Create Poll",
              onPressed: createPoll,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        ],
      ),
    );
  }
}
