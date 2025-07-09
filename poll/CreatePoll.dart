import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:myunivrs/core/utils/custom_container.dart';
import 'package:myunivrs/core/utils/custom_text.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/modules/groups/widgets/customtextfeild.dart';

import 'package:myunivrs/api/api_config.dart';

import 'package:dio/dio.dart';
import 'package:myunivrs/shared/widgets/app_buttons/app_main_button.dart';

class CreatePollScreen extends StatefulWidget {
  const CreatePollScreen({super.key});

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  // Initialize ForumService using GetX or pass it via constructor/provider
  // For simplicity, we'll initialize it here. In a real app, use Get.put for better DI.
  late final ForumService _forumService;

  final pollQuestionController = TextEditingController();
  final List<TextEditingController> pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _allowMultipleOptions = false;

  @override
  void initState() {
    super.initState();
    _forumService = ForumService(
        Dio()); // Initialize Dio here. Consider using Get.find() if already registered.
  }

  @override
  void dispose() {
    pollQuestionController.dispose();
    for (var controller in pollOptionControllers) {
      controller.dispose();
    }
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

  Future<void> createPoll() async {
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

    if (pollOptionControllers.length < 2) {
      Fluttertoast.showToast(
          msg: "Please add at least two options for a poll.");
      return;
    }

    try {
      await _forumService.createPoll(
        question: pollQuestionController.text,
        options: pollOptionControllers.map((c) => c.text).toList(),
        allowMultipleAnswers: _allowMultipleOptions,
      );

      // If the above call succeeds without throwing an exception, show success
      Fluttertoast.showToast(
        msg: "Poll created successfully!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Clear fields after successful creation
      pollQuestionController.clear();
      setState(() {
        pollOptionControllers.clear();
        pollOptionControllers.add(TextEditingController());
        pollOptionControllers.add(TextEditingController());
        _allowMultipleOptions = false;
      });
    } catch (e) {
      // The ForumService method already handles showing toasts/snackbars for errors,
      // but you can add a generic one here if needed.
      Get.snackbar(
        "Error",
        e.toString(), // Display the error message from the thrown exception
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      print("Error creating poll in UI: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 25, right: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomContainer(
              title: "Poll Information",
            ),
            SizedBox(height: height * 0.02),
            const CustomText(
              lable: "Poll Question",
              fontsize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E8E),
            ),
            SizedBox(height: height * 0.01),
            CustomTextfeild(
              minlines: 2,
              maxlines: 2,
              controller: pollQuestionController,
              hinttext: "Enter your poll question",
            ),
            SizedBox(height: height * 0.02),
            const CustomText(
              lable: "Poll Options",
              fontsize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E8E),
            ),
            SizedBox(height: height * 0.01),
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
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () => _removePollOption(index),
                        ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: height * 0.01),
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
            SizedBox(height: height * 0.02),
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
            SizedBox(height: height * 0.02),
            Center(
              child: AppMainButton(
                text: "Create Poll",
                onPressed: createPoll,
              ),
            ),
            SizedBox(height: height * 0.05),
          ],
        ),
      ),
    );
  }
}
