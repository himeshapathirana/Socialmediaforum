import 'package:flutter/material.dart';
import 'package:myunivrs/features/forum/subForum/screens/SubPollScreen.dart';
import 'package:myunivrs/features/forum/subForum/screens/SubPostScreen.dart';

class CreateSubForumScreen extends StatefulWidget {
  const CreateSubForumScreen({super.key});

  @override
  State<CreateSubForumScreen> createState() => _CreateSubForumScreenState();
}

class _CreateSubForumScreenState extends State<CreateSubForumScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: "Post"),
              Tab(text: "Poll"),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 25, right: 25),
              child: TabBarView(
                controller: _tabController,
                children: const [
                  SubPostScreen(),
                  SubPollScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
