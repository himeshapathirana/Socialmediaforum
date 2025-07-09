import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:myunivrs/features/forum/services/forum_services.dart';
import 'package:myunivrs/features/forum/subForum/model/SubPollModel.dart';
import 'package:dio/dio.dart';

class EditSubForumPoll extends StatefulWidget {
  final SubPollModel poll;

  const EditSubForumPoll({Key? key, required this.poll}) : super(key: key);

  @override
  _EditSubForumPollState createState() => _EditSubForumPollState();
}

class _EditSubForumPollState extends State<EditSubForumPoll> {
  late TextEditingController _questionController;
  late List<TextEditingController> _optionControllers;
  late bool _allowMultipleAnswers;
  late TextEditingController _categoryController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.poll.question);
    _optionControllers = widget.poll.options
        .map((option) => TextEditingController(text: option))
        .toList();
    _allowMultipleAnswers = widget.poll.allowMultipleAnswers;
    _categoryController =
        TextEditingController(text: widget.poll.category ?? '');
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _categoryController.dispose();
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers.removeAt(index);
      });
    } else {
      Fluttertoast.showToast(msg: "Poll must have at least 2 options");
    }
  }

  Future<void> _updatePoll() async {
    if (_questionController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter a question");
      return;
    }

    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      Fluttertoast.showToast(msg: "Please enter at least 2 options");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final forumService = ForumService(Dio());
      await forumService.updateSubForumPoll(
        pollId: widget.poll.id!,
        question: _questionController.text,
        options: options,
        allowMultipleAnswers: _allowMultipleAnswers,
        category:
            _categoryController.text.isEmpty ? null : _categoryController.text,
      );

      if (mounted) {
        Fluttertoast.showToast(msg: "Poll updated successfully");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: "Failed to update poll: ${e.toString()}");
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Sub-Forum Poll"),
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(15),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Poll Question",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _questionController,
                            decoration: InputDecoration(
                              hintText: "Enter your poll question",
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            maxLines: 2,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Poll Options",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._optionControllers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final controller = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        hintText: "Option ${index + 1}",
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () => _removeOption(index),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          OutlinedButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add Option"),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(
                                  color: Theme.of(context).primaryColor),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        "Allow multiple answers",
                        style: TextStyle(fontSize: 16),
                      ),
                      value: _allowMultipleAnswers,
                      onChanged: (value) {
                        setState(() {
                          _allowMultipleAnswers = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Category",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _categoryController,
                            decoration: InputDecoration(
                              hintText: "Enter category",
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updatePoll,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
