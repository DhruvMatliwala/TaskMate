import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/directions_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/shimmer_loader.dart';
import '../chat/chat_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<TaskModel?> _taskStream;
  final _bidController = TextEditingController();
  final _bidMsgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taskStream = _firestoreService.streamTask(widget.task.id);
  }

  @override
  void dispose() {
    _bidController.dispose();
    _bidMsgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel!;

    return StreamBuilder<TaskModel?>(
      stream: _taskStream,
      initialData: widget.task,
      builder: (context, snapshot) {
        final task = snapshot.data ?? widget.task;
        final locProvider = context.watch<LocationProvider>();

        final isMyTask = task.creatorId == user.uid;
        final isAcceptedWorker = task.workerId == user.uid;

        // Calculate real distance and travel time from user GPS position
        final userLatLng = locProvider.currentLatLng;
        final taskLatLng = LatLng(task.location.latitude, task.location.longitude);
        final distKm = DirectionsService.getDistanceKm(userLatLng, taskLatLng);
        final distText = DirectionsService.formatDistance(distKm);
        final etaText = DirectionsService.formatDuration(DirectionsService.estimateDurationMinutes(distKm));

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          appBar: CustomAppBar(
            title: task.title,
            showBackButton: true,
            actions: [
              if (task.isUrgent == true)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.bolt_rounded, color: Color(0xFFFF6584)),
                ),
              _StatusBadge(task: task),
              const SizedBox(width: 16),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero Image ──────────────────────────────────────────
                    _buildHeroImage(task),

                    // ── Content ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & reward
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (task.isOpen == true)
                                _BudgetBadge(min: task.minBudget, max: task.maxBudget)
                              else
                                _RewardBadge(reward: task.reward),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Description Card
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  task.description,
                                  style: const TextStyle(
                                    color: Color(0xFFB0B0C8),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Location, Distance & Creator Card ───────────────
                          GlassCard(
                            child: Column(
                              children: [
                                _InfoRow(
                                  icon: task.category.icon,
                                  color: task.category.color,
                                  label: 'Category',
                                  value: task.category.displayName,
                                ),
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  color: const Color(0xFFFF6584),
                                  label: 'Location',
                                  value: task.locationName,
                                ),
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.alt_route_rounded,
                                  color: const Color(0xFF38F9D7),
                                  label: 'Distance',
                                  value: '$distText  (approx $etaText travel)',
                                ),
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.person_outline,
                                  color: const Color(0xFF6C63FF),
                                  label: 'Posted by',
                                  value: task.creatorName,
                                ),
                                if (task.workerName != null) ...[
                                  const SizedBox(height: 12),
                                  _InfoRow(
                                    icon: Icons.work_outline,
                                    color: const Color(0xFF43E97B),
                                    label: 'Worker',
                                    value: task.workerName!,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.access_time,
                                  color: const Color(0xFFFFD700),
                                  label: 'Posted',
                                  value: _formatDate(task.createdAt),
                                ),
                              ],
                            ),
                          ),

                          if (isMyTask == true && (task.isOpen == true || task.isAccepted == true)) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _confirmCancel(context, task),
                              icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF6584), size: 18),
                              label: const Text(
                                'Cancel This Task',
                                style: TextStyle(color: Color(0xFFFF6584), fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: const Color(0xFFFF6584).withValues(alpha: 0.4)),
                                backgroundColor: const Color(0xFFFF6584).withValues(alpha: 0.05),
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ── Dynamic Bidding Section ───────────────────────
                          if (task.isOpen == true) ...[
                            if (isMyTask == true)
                              _buildCreatorBidsSection(task)
                            else if (user.isWorker == true)
                              _buildWorkerBiddingSection(task, user),
                          ],

                          const SizedBox(height: 14),

                          // ── Turn-by-Turn GPS Navigation Button ─────────────
                          if (task.isAccepted == true || task.isInProgress == true)
                            OutlinedButton.icon(
                              onPressed: () => DirectionsService.openGoogleMapsNavigation(
                                originLat: userLatLng.latitude,
                                originLng: userLatLng.longitude,
                                destLat: task.location.latitude,
                                destLng: task.location.longitude,
                                destName: task.locationName,
                              ),
                              icon: const Icon(Icons.navigation_rounded, color: Color(0xFF38F9D7), size: 18),
                              label: Text(
                                'Start Navigation in Google Maps ($distText)',
                                style: const TextStyle(
                                  color: Color(0xFF38F9D7),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: const Color(0xFF38F9D7).withValues(alpha: 0.4)),
                                backgroundColor: const Color(0xFF38F9D7).withValues(alpha: 0.08),
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // ── Action Buttons ─────────────────────────────────

                          // WORKER: Start task (if accepted)
                          if (isAcceptedWorker == true && task.isAccepted == true) ...[
                            Consumer<TaskProvider>(
                              builder: (_, taskProv, __) => GradientButton(
                                label: 'Start Task',
                                isLoading: taskProv.isLoading,
                                icon: Icons.play_circle_outline,
                                gradient: const [Color(0xFF6C63FF), Color(0xFF9C5FC8)],
                                onPressed: () => _startTask(context, task, user, locProvider),
                              ),
                            ),
                          ],

                          // WORKER: Complete task (if in progress)
                          if (isAcceptedWorker == true && task.isInProgress == true) ...[
                            Consumer<TaskProvider>(
                              builder: (_, taskProv, __) => GradientButton(
                                label: 'Mark as Complete',
                                isLoading: taskProv.isLoading,
                                icon: Icons.check_circle_outline,
                                gradient: const [Color(0xFF43E97B), Color(0xFF38F9D7)],
                                onPressed: () => _completeTask(context, task, user),
                              ),
                            ),
                          ],

                          // CHAT: Both creator and accepted worker can message each other
                          if ((isMyTask == true || isAcceptedWorker == true) &&
                              (task.isAccepted == true || task.isInProgress == true)) ...[
                            const SizedBox(height: 12),
                            GradientButton.outlined(
                              label: isMyTask ? 'Message Worker' : 'Message Creator',
                              icon: Icons.chat_bubble_outline,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatRoomId: task.chatRoomId?.isNotEmpty == true
                                        ? task.chatRoomId!
                                        : 'chat_${task.id}',
                                    taskTitle: task.title,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Completed state
                          if (task.isCompleted == true) ...[
                            GlassCard(
                              backgroundColor: const Color(0xFF43E97B).withValues(alpha: 0.05),
                              borderColor: const Color(0xFF43E97B).withValues(alpha: 0.3),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Color(0xFF43E97B), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'This task has been completed!',
                                    style: TextStyle(
                                      color: Color(0xFF43E97B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Creator: Review Bids ──────────────────────────────────────────────────

  Widget _buildCreatorBidsSection(TaskModel task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Worker Quotes'),
        const SizedBox(height: 12),
        StreamBuilder<List<BidModel>>(
          stream: context.read<TaskProvider>().streamBids(task.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ShimmerLoader(height: 100);
            }
            final bids = snapshot.data ?? [];
            if (bids.isEmpty) {
              return GlassCard(
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_empty_rounded, color: Colors.white.withValues(alpha: 0.3), size: 32),
                      const SizedBox(height: 12),
                      const Text(
                        'No quotes received yet.',
                        style: TextStyle(color: Color(0xFF6A6A8A), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bids.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final bid = bids[index];
                return _BidListItem(
                  bid: bid,
                  onChat: () => _openPreHireChat(
                    context,
                    task: task,
                    otherUserId: bid.workerId,
                    otherUserName: bid.workerName,
                    otherUserPhoto: bid.workerPhotoUrl,
                  ),
                  onHire: () => _acceptBid(context, task, bid),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ── Worker: Place Bid ─────────────────────────────────────────────────────

  Widget _buildWorkerBiddingSection(TaskModel task, UserModel user) {
    return StreamBuilder<List<BidModel>>(
      stream: context.read<TaskProvider>().streamBids(task.id),
      builder: (context, snapshot) {
        final bids = snapshot.data ?? [];
        final myBid = bids.any((b) => b.workerId == user.uid)
            ? bids.firstWhere((b) => b.workerId == user.uid)
            : null;

        if (myBid != null) {
          return GlassCard(
            borderColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF6C63FF), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Your Quote Sent',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      '₹${myBid.amount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFF43E97B), fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDate(myBid.timestamp), style: const TextStyle(color: Color(0xFF6A6A8A), fontSize: 12)),
                    OutlinedButton.icon(
                      onPressed: () => _openPreHireChat(
                        context,
                        task: task,
                        otherUserId: task.creatorId,
                        otherUserName: task.creatorName,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF38F9D7)),
                      label: const Text('Message Poster', style: TextStyle(color: Color(0xFF38F9D7), fontWeight: FontWeight.w700, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: const Color(0xFF38F9D7).withValues(alpha: 0.5)),
                        backgroundColor: const Color(0xFF38F9D7).withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                if (myBid.message != null && myBid.message!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    myBid.message!,
                    style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          );
        }

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send a Quote',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Budget Range: ₹${task.minBudget.toStringAsFixed(0)} - ₹${task.maxBudget.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bidController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration(
                  hint: 'Offer Amount (₹)',
                  icon: Icons.currency_rupee,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bidMsgController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _fieldDecoration(
                  hint: 'Optional message to the creator...',
                  icon: Icons.chat_bubble_outline,
                ),
              ),
              const SizedBox(height: 16),
              Consumer<TaskProvider>(
                builder: (_, taskProv, __) => GradientButton(
                  label: 'Send Quote',
                  isLoading: taskProv.isLoading,
                  icon: Icons.send_rounded,
                  onPressed: () => _placeBid(context, task, user),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openPreHireChat(
                  context,
                  task: task,
                  otherUserId: task.creatorId,
                  otherUserName: task.creatorName,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF38F9D7)),
                label: const Text(
                  'Message Poster (Ask Question)',
                  style: TextStyle(color: Color(0xFF38F9D7), fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF38F9D7).withValues(alpha: 0.4)),
                  backgroundColor: const Color(0xFF38F9D7).withValues(alpha: 0.06),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF3A3A5A), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF4A4A6A), size: 18),
      filled: true,
      fillColor: const Color(0xFF0F0F1A),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D2D4E))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D2D4E))),
    );
  }

  Widget _buildHeroImage(TaskModel task) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: task.imageUrl != null
          ? CachedNetworkImage(
              imageUrl: task.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ShimmerLoader(height: 240, borderRadius: 0),
              errorWidget: (_, __, ___) => _buildImagePlaceholder(),
            )
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.task_alt, color: Color(0xFF2D2D4E), size: 64),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Action Handlers ───────────────────────────────────────────────────────

  void _openPreHireChat(
    BuildContext context, {
    required TaskModel task,
    required String otherUserId,
    required String otherUserName,
    String? otherUserPhoto,
  }) {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;

    final isCreator = task.creatorId == user.uid;
    final workerId = isCreator ? otherUserId : user.uid;
    final workerName = isCreator ? otherUserName : user.name;
    final creatorId = task.creatorId;
    final creatorName = task.creatorName;

    final chatRoomId = 'chat_${task.id}_$workerId';

    // Ensure chat room doc exists in Firestore with participants & names
    _firestoreService.sendMessage(
      chatRoomId: chatRoomId,
      message: MessageModel(
        id: '',
        senderId: user.uid,
        senderName: user.name,
        text: '👋 Started pre-hire discussion for "${task.title}"',
        timestamp: DateTime.now(),
      ),
      taskId: task.id,
      taskTitle: task.title,
      creatorId: creatorId,
      creatorName: creatorName,
      workerId: workerId,
      workerName: workerName,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatRoomId: chatRoomId,
          taskTitle: '${task.title} (Pre-Hire)',
        ),
      ),
    );
  }

  Future<void> _placeBid(
    BuildContext context,
    TaskModel task,
    UserModel user,
  ) async {
    final amount = double.tryParse(_bidController.text.trim());
    if (amount == null || amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid offer amount')));
      return;
    }

    final taskProv = context.read<TaskProvider>();
    final success = await taskProv.placeBid(
      taskId: task.id,
      worker: user,
      amount: amount,
      message: _bidMsgController.text.trim().isEmpty ? null : _bidMsgController.text.trim(),
    );

    if (success == true && mounted == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote sent successfully!')));
      _bidController.clear();
      _bidMsgController.clear();
    }
  }

  Future<void> _acceptBid(
    BuildContext context,
    TaskModel task,
    BidModel bid,
  ) async {
    final taskProv = context.read<TaskProvider>();
    final success = await taskProv.acceptBid(taskId: task.id, bid: bid);

    if (success == true && mounted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hired ${bid.workerName}! Task is now active.')),
      );
    }
  }

  void _confirmCancel(BuildContext context, TaskModel task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Task?'),
        content: const Text('Are you sure you want to cancel this task? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, Keep It', style: TextStyle(color: Color(0xFF6A6A8A))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<TaskProvider>().cancelTask(task.id);
              if (success == true && mounted == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task cancelled successfully.')),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6584)),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _startTask(
    BuildContext context,
    TaskModel task,
    UserModel user,
    LocationProvider locProvider,
  ) async {
    final taskProv = context.read<TaskProvider>();
    await taskProv.startTask(task.id);
    // Start broadcasting GPS
    await locProvider.startTracking(task.id);
  }

  Future<void> _completeTask(
    BuildContext context,
    TaskModel task,
    UserModel user,
  ) async {
    final taskProv = context.read<TaskProvider>();
    context.read<LocationProvider>().stopTracking();
    final success = await taskProv.completeTask(
      taskId: task.id,
      workerId: user.uid,
    );

    if (context.mounted == false) return;
    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task marked as complete! 🎉')),
      );
    }
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
    );
  }
}

class _BidListItem extends StatelessWidget {
  final BidModel bid;
  final VoidCallback onChat;
  final VoidCallback onHire;

  const _BidListItem({
    required this.bid,
    required this.onChat,
    required this.onHire,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                backgroundImage: bid.workerPhotoUrl != null ? NetworkImage(bid.workerPhotoUrl!) : null,
                child: bid.workerPhotoUrl == null
                    ? Text(
                        bid.workerName.isNotEmpty ? bid.workerName[0].toUpperCase() : 'W',
                        style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bid.workerName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          bid.workerRating.toStringAsFixed(1),
                          style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '₹${bid.amount.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF43E97B), fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          if (bid.message != null && bid.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bid.message!,
              style: const TextStyle(color: Color(0xFFB0B0C8), fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF38F9D7)),
                  label: const Text(
                    'Chat',
                    style: TextStyle(color: Color(0xFF38F9D7), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF38F9D7).withValues(alpha: 0.5)),
                    backgroundColor: const Color(0xFF38F9D7).withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onHire,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                  label: const Text(
                    'Hire This Worker',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetBadge extends StatelessWidget {
  final double min;
  final double max;
  const _BudgetBadge({required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('EST. BUDGET', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 9, fontWeight: FontWeight.w800)),
          Text(
            '₹${min.toStringAsFixed(0)}-${max.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskModel task;
  const _StatusBadge({required this.task});

  Color get _color {
    switch (task.status) {
      case TaskStatus.open:
        return const Color(0xFF43E97B);
      case TaskStatus.accepted:
        return const Color(0xFFFFD700);
      case TaskStatus.inProgress:
        return const Color(0xFF6C63FF);
      case TaskStatus.completed:
        return const Color(0xFF9E9E9E);
      case TaskStatus.cancelled:
        return const Color(0xFFFF6584);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        task.status.displayName,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final double reward;
  const _RewardBadge({required this.reward});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF43E97B).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '₹${reward.toStringAsFixed(0)}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6A6A8A),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
