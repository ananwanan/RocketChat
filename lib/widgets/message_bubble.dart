import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, child: Text(message.initial)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        message.author,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(time, style: Theme.of(context).textTheme.bodySmall),
                    if (message.edited)
                      Text(
                        '  已编辑',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: '消息操作',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onSelected: (action) => _action(context, action, own),
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
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                SelectableText(
                  message.text.isEmpty && message.system
                      ? '系统消息'
                      : message.text,
                ),
                if (message.replyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${message.replyCount} 条回复',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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

  Future<void> _action(BuildContext context, String action, bool own) async {
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
              content: const Text('确定删除这条消息？'),
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
