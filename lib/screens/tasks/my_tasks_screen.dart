import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/task/task_card.dart';
import '../../providers/location_provider.dart';
import '../home/task_detail_screen.dart';
import '../tasks/create_task_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
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
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;
    final taskProv = context.watch<TaskProvider>();
    final locProv = context.watch<LocationProvider>();

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        appBar: CustomAppBar(title: 'My Tasks', showBackButton: false),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    // Ensure user streams are active
    if (!taskProv.isUserInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<TaskProvider>().initUserStreams(user);
      });
    }

    final double? userLat = locProv.currentPosition?.latitude;
    final double? userLng = locProv.currentPosition?.longitude;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: CustomAppBar(
        title: 'My Tasks',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          indicatorWeight: 3,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: const Color(0xFF6A6A8A),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Posted Tasks'),
            Tab(text: 'Accepted Tasks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Tasks created by this user
          _buildTaskList(
            context: context,
            tasks: taskProv.myCreatedTasks,
            emptyMessage: 'No tasks posted yet',
            emptySubtitle: 'Tap the + button to post your first task',
            emptyIcon: Icons.post_add_rounded,
            userLat: userLat,
            userLng: userLng,
          ),

          // Tab 2: Tasks accepted by worker
          _buildTaskList(
            context: context,
            tasks: taskProv.myAcceptedTasks,
            emptyMessage: 'No accepted tasks yet',
            emptySubtitle: 'Browse the map to find and accept tasks near you',
            emptyIcon: Icons.work_outline_rounded,
            userLat: userLat,
            userLng: userLng,
          ),
        ],
      ),
      floatingActionButton: user.isCreator
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
              ),
              backgroundColor: const Color(0xFF6C63FF),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Post Task',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildTaskList({
    required BuildContext context,
    required List<TaskModel> tasks,
    required String emptyMessage,
    required String emptySubtitle,
    required IconData emptyIcon,
    double? userLat,
    double? userLng,
  }) {
    if (tasks.isEmpty) {
      return _buildEmptyState(emptyMessage, emptySubtitle, emptyIcon);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          userLat: userLat,
          userLng: userLng,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(task: task),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF6A6A8A),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
