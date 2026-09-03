import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

class RoomSidebar extends StatelessWidget {
  const RoomSidebar({super.key, required this.state, this.onSelected});
  final AppState state;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: const Icon(Icons.rocket_launch_rounded),
              ),
              title: Text(
                state.workspaceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '@${state.session!.username}${state.workspaceVersion.isEmpty ? '' : ' · v${state.workspaceVersion}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: '新建会话',
                onPressed: () => showNewConversationDialog(context, state),
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                onChanged: state.setRoomFilter,
                decoration: const InputDecoration(
                  hintText: '筛选会话',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: state.refreshRooms,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: state.filteredRooms.length,
                  itemBuilder: (context, index) {
                    final room = state.filteredRooms[index];
                    return _RoomTile(
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
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.circle, size: 10, color: Colors.green),
              title: Text(
                state.realtimeStatus,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: IconButton(
                tooltip: '退出登录',
                onPressed: state.logout,
                icon: const Icon(Icons.logout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.selected,
    required this.onTap,
  });
  final Room room;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    selected: selected,
    selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
    leading: SizedBox(
      width: 28,
      child: Center(
        child: Text(
          room.icon,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    ),
    title: Text(room.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: room.unread <= 0
        ? null
        : Badge(label: Text(room.unread > 99 ? '99+' : '${room.unread}')),
    onTap: onTap,
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
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('私信')),
                  ButtonSegment(value: 1, label: Text('公开频道')),
                  ButtonSegment(value: 2, label: Text('私有频道')),
                ],
                selected: {kind},
                onSelectionChanged: (value) =>
                    setState(() => kind = value.first),
              ),
              const SizedBox(height: 18),
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
