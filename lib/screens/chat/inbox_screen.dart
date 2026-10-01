import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/glass_card.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Unread', 'As Poster', 'As Worker'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().userModel;
      if (user != null) {
        context.read<ChatProvider>().initInbox(user.uid);
      }
    });
  }

  String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && dt.day == now.day) {
      return DateFormat('hh:mm a').format(dt);
    }
    if (diff.inDays < 2) return 'Yesterday';
    return DateFormat('MMM dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatProv = context.watch<ChatProvider>();
    final myUid = auth.userModel?.uid ?? '';

    final allRooms = chatProv.inboxChatRooms;
    final unreadCount = chatProv.totalUnreadCount;

    // Filter conversations
    final filteredRooms = allRooms.where((room) {
      // Search
      final otherName = room.otherParticipantName(myUid).toLowerCase();
      final taskTitle = room.taskTitle.toLowerCase();
      final lastMsg = room.lastMessage.toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          otherName.contains(query) ||
          taskTitle.contains(query) ||
          lastMsg.contains(query);

      if (!matchesSearch) return false;

      // Filter chips
      if (_selectedFilter == 'Unread') {
        return room.isUnread(myUid);
      } else if (_selectedFilter == 'As Poster') {
        return room.creatorId == myUid;
      } else if (_selectedFilter == 'As Worker') {
        return room.workerId == myUid;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: CustomAppBar(
        title: 'Messages',
        showBackButton: true,
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6584).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF6584), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_chat_unread_rounded, size: 14, color: Color(0xFFFF6584)),
                      const SizedBox(width: 4),
                      Text(
                        '$unreadCount New',
                        style: const TextStyle(
                          color: Color(0xFFFF6584),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2D2D4E)),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search chats, people, or tasks...',
                      hintStyle: TextStyle(color: Color(0xFF6A6A8A), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF6C63FF), size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', allRooms.length),
                      const SizedBox(width: 8),
                      _buildFilterChip('Unread', unreadCount),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'As Poster',
                        allRooms.where((r) => r.creatorId == myUid).length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'As Worker',
                        allRooms.where((r) => r.workerId == myUid).length,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Conversations List ──────────────────────────────────────────────
          Expanded(
            child: filteredRooms.isEmpty
                ? _buildEmptyState(allRooms.isEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredRooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final room = filteredRooms[index];
                      return _buildChatRoomCard(context, room, myUid);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF2D2D4E),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.25) : const Color(0xFF2D2D4E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatRoomCard(BuildContext context, ChatRoomModel room, String myUid) {
    final isUnread = room.isUnread(myUid);
    final otherName = room.otherParticipantName(myUid);
    final otherRole = room.otherParticipantRole(myUid);
    final otherPhoto = room.otherParticipantPhoto(myUid);
    final isWorker = otherRole == 'Worker';
    final roleColor = isWorker ? const Color(0xFF43E97B) : const Color(0xFFFF6584);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatRoomId: room.id,
              taskTitle: room.taskTitle,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        backgroundColor: isUnread
            ? const Color(0xFF6C63FF).withOpacity(0.12)
            : const Color(0xFF1A1A2E).withOpacity(0.8),
        borderColor: isUnread ? const Color(0xFF6C63FF).withOpacity(0.6) : const Color(0xFF2D2D4E),
        borderRadius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Avatar with Role Glow ─────────────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: roleColor.withOpacity(0.15),
                  backgroundImage: otherPhoto != null ? NetworkImage(otherPhoto) : null,
                  child: otherPhoto == null
                      ? Text(
                          otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF43E97B),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1A1A2E), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // ── Conversation Info ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Name
                      Expanded(
                        child: Text(
                          otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      // Time
                      Text(
                        _formatMessageTime(room.lastMessageTime),
                        style: TextStyle(
                          color: isUnread ? const Color(0xFF38F9D7) : const Color(0xFF6A6A8A),
                          fontSize: 11,
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Role Badge & Task Title Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          otherRole,
                          style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '• ${room.taskTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Last Message Snippet
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.lastMessage.isNotEmpty ? room.lastMessage : 'Start discussing task details...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isUnread ? Colors.white : const Color(0xFF6A6A8A),
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF6C63FF),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF6C63FF),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool noRoomsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withOpacity(0.12),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
              ),
              child: const Icon(Icons.forum_outlined, size: 40, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 20),
            Text(
              noRoomsAtAll ? 'No messages yet' : 'No matching chats found',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noRoomsAtAll
                  ? 'When you accept a task or a worker accepts your task, real-time chat discussions will automatically appear here.'
                  : 'Try searching with a different name or changing your filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
