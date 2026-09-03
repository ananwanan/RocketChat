import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'user_avatar.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.state});
  final ChatMessage message;
  final AppState state;

  String get time {
    final local = message.timestamp.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final own = message.userId == state.session?.userId;
    if (message.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text.isEmpty ? '系统消息' : message.text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        left: own ? 64 : 18,
        right: own ? 18 : 64,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        mainAxisAlignment: own
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!own) ...[
            UserAvatar(
              state: state,
              username: message.username,
              label: message.author,
              radius: 18,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: own
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!own)
                        Flexible(
                          child: Text(
                            message.author,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!own) const SizedBox(width: 7),
                      Text(
                        '$time${message.edited ? ' · 已编辑' : ''}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (own)
                      _MessageMenu(message: message, state: state, own: own),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: own
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(17),
                            topRight: const Radius.circular(17),
                            bottomLeft: Radius.circular(own ? 17 : 5),
                            bottomRight: Radius.circular(own ? 5 : 17),
                          ),
                          border: own
                              ? null
                              : Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0a101225),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SelectableText(
                          message.text,
                          style: TextStyle(
                            color: own
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    if (!own)
                      _MessageMenu(message: message, state: state, own: own),
                  ],
                ),
                if (message.replyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, left: 5, right: 5),
                    child: Text(
                      '${message.replyCount} 条回复',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageMenu extends StatelessWidget {
  const _MessageMenu({
    required this.message,
    required this.state,
    required this.own,
  });
  final ChatMessage message;
  final AppState state;
  final bool own;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '消息操作',
    padding: EdgeInsets.zero,
    iconSize: 18,
    onSelected: (action) => _action(context, action),
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'reply',
        child: ListTile(
          leading: Icon(Icons.reply),
          title: Text('回复'),
          dense: true,
        ),
      ),
      const PopupMenuItem(
        value: 'react',
        child: ListTile(
          leading: Icon(Icons.thumb_up_outlined),
          title: Text('添加 👍'),
          dense: true,
        ),
      ),
      if (own)
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('编辑'),
            dense: true,
          ),
        ),
      if (own)
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('删除'),
            dense: true,
          ),
        ),
    ],
  );

  Future<void> _action(BuildContext context, String action) async {
    try {
      switch (action) {
        case 'reply':
          state.setReply(message);
        case 'react':
          await state.react(message);
        case 'edit':
          if (!own) return;
          final text = await _editDialog(context, message.text);
          if (text != null && text.trim().isNotEmpty) {
            await state.edit(message, text.trim());
          }
        case 'delete':
          if (!own) return;
          final yes = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('删除消息'),
              content: const Text('确定删除这条消息？此操作无法撤销。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('删除'),
                ),
              ],
            ),
          );
          if (yes == true) await state.delete(message);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<String?> _editDialog(BuildContext context, String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑消息'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
