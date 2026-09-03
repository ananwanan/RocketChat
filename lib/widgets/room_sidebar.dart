import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'user_avatar.dart';

class RoomSidebar extends StatelessWidget {
  const RoomSidebar({super.key, required this.state, this.onSelected});
  final AppState state;
  final VoidCallback? onSelected;

  static const sidebar = Color(0xff17182b);
  static const sidebarSoft = Color(0xff22243c);
  static const muted = Color(0xffaeb1c7);

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: sidebar,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xff6868df),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.workspaceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${state.session!.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '新建会话',
                  onPressed: () => showNewConversationDialog(context, state),
                  style: IconButton.styleFrom(
                    backgroundColor: sidebarSoft,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              onChanged: state.setRoomFilter,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索会话',
                hintStyle: const TextStyle(color: muted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: muted,
                  size: 20,
                ),
                filled: true,
                fillColor: sidebarSoft,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xff7777e8)),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 18, 8),
            child: Text(
              '会话',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.refreshRooms,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.filteredRooms.length,
                itemBuilder: (context, index) {
                  final room = state.filteredRooms[index];
                  return _RoomTile(
                    state: state,
                    room: room,
                    selected: room.id == state.selectedRoom?.id,
                    onTap: () async {
                      await state.selectRoom(room);
                      onSelected?.call();
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: sidebarSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Color(0xff55d6a2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.realtimeStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: state.notificationsEnabled ? '关闭消息通知' : '开启消息通知',
                  onPressed: () => state.setNotificationsEnabled(
                    !state.notificationsEnabled,
                  ),
                  color: state.notificationsEnabled
                      ? const Color(0xffffc857)
                      : muted,
                  icon: Icon(
                    state.notificationsEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_outlined,
                  ),
                ),
                IconButton(
                  tooltip: '退出登录',
                  onPressed: state.logout,
                  color: muted,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.state,
    required this.room,
    required this.selected,
    required this.onTap,
  });
  final AppState state;
  final Room room;
  final bool selected;
  final VoidCallback onTap;

  IconData get icon => switch (room.type) {
    'd' => Icons.person_outline_rounded,
    'p' => Icons.lock_outline_rounded,
    'l' => Icons.support_agent_rounded,
    _ => Icons.tag_rounded,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Material(
      color: selected ? const Color(0xff34365b) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: room.type == 'd'
            ? UserAvatar(
                state: state,
                username: room.avatarUsername ?? room.name,
                label: room.displayName,
                radius: 16,
              )
            : Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : RoomSidebar.muted,
              ),
        title: Text(
          room.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xffd9dbea),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: room.unread <= 0
            ? null
            : Badge(
                backgroundColor: const Color(0xffff5c77),
                textColor: Colors.white,
                label: Text(room.unread > 99 ? '99+' : '${room.unread}'),
              ),
        onTap: onTap,
      ),
    ),
  );
}

Future<void> showNewConversationDialog(
  BuildContext context,
  AppState state,
) async {
  var kind = 0;
  final name = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('新建会话'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('私信'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('公开'),
                    icon: Icon(Icons.tag),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text('私有'),
                    icon: Icon(Icons.lock_outline),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (value) =>
                    setState(() => kind = value.first),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: kind == 0 ? '用户名' : '频道名',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('创建'),
          ),
        ],
      ),
    ),
  );
  if (result != true || name.text.trim().isEmpty || !context.mounted) {
    name.dispose();
    return;
  }
  try {
    if (kind == 0) {
      final found = await state.newDirectMessage(name.text.trim());
      if (!found) throw const RocketChatException('未找到该用户。');
    } else {
      await state.newChannel(name.text.trim(), private: kind == 2);
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  } finally {
    name.dispose();
  }
}
