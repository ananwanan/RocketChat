import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/message_bubble.dart';
import '../widgets/room_sidebar.dart';
import '../widgets/user_avatar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 820;
      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(width: 306, child: RoomSidebar(state: state)),
              Expanded(child: _ChatPanel(state: state)),
            ],
          ),
        );
      }
      return Scaffold(
        drawer: Drawer(
          width: 316,
          shape: const RoundedRectangleBorder(),
          child: RoomSidebar(
            state: state,
            onSelected: () => Navigator.maybePop(context),
          ),
        ),
        body: _ChatPanel(state: state, mobile: true),
      );
    },
  );
}

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({required this.state, this.mobile = false});
  final AppState state;
  final bool mobile;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final composer = TextEditingController();
  final scroll = ScrollController();
  int previousCount = 0;

  @override
  void didUpdateWidget(covariant _ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.messages.length != previousCount) {
      previousCount = widget.state.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    composer.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (await widget.state.send(composer.text)) composer.clear();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.state.selectedRoom;
    return Builder(
      builder: (context) => Column(
        children: [
          _ChatHeader(
            state: widget.state,
            room: room,
            mobile: widget.mobile,
            onMenu: () => Scaffold.of(context).openDrawer(),
            onSearch: room == null ? null : () => _searchDialog(context),
            onRefresh: room == null
                ? null
                : () => widget.state.selectRoom(room),
          ),
          if (widget.state.searchTerm != null)
            _NoticeBar(
              icon: Icons.manage_search_rounded,
              text:
                  '“${widget.state.searchTerm}” 的搜索结果 · ${widget.state.messages.length} 条',
              color: Theme.of(context).colorScheme.secondaryContainer,
              onClose: widget.state.clearSearch,
            ),
          if (widget.state.error != null)
            _NoticeBar(
              icon: Icons.error_outline_rounded,
              text: widget.state.error!,
              color: Theme.of(context).colorScheme.errorContainer,
              onClose: widget.state.clearError,
            ),
          Expanded(
            child: room == null
                ? const _EmptyChat()
                : Stack(
                    children: [
                      if (widget.state.messages.isEmpty && !widget.state.busy)
                        const Center(child: Text('这里还没有消息，打个招呼吧')),
                      ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: widget.state.messages.length,
                        itemBuilder: (context, index) => MessageBubble(
                          key: ValueKey(widget.state.messages[index].id),
                          message: widget.state.messages[index],
                          state: widget.state,
                        ),
                      ),
                      if (widget.state.busy)
                        const Align(
                          alignment: Alignment.topCenter,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    ],
                  ),
          ),
          if (room != null) ...[
            if (widget.state.replyTo != null)
              _ReplyPreview(
                message: widget.state.replyTo!,
                onClose: () => widget.state.setReply(null),
              ),
            _Composer(controller: composer, onSend: send),
          ],
        ],
      ),
    );
  }

  Future<void> _searchDialog(BuildContext context) async {
    final controller = TextEditingController();
    final term = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索当前会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '关键词',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (term != null && term.trim().isNotEmpty) await widget.state.search(term);
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.state,
    required this.room,
    required this.mobile,
    required this.onMenu,
    this.onSearch,
    this.onRefresh,
  });
  final AppState state;
  final Room? room;
  final bool mobile;
  final VoidCallback onMenu;
  final VoidCallback? onSearch;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          if (mobile)
            IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
          const SizedBox(width: 6),
          if (room?.type == 'd')
            UserAvatar(
              state: state,
              username: room!.avatarUsername ?? room!.name,
              label: room!.displayName,
              radius: 20,
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                room == null
                    ? Icons.chat_bubble_outline_rounded
                    : _roomIcon(room!.type),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room?.displayName ?? '选择一个会话',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  room?.typeLabel ?? '从左侧会话列表开始聊天',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '搜索消息',
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    ),
  );

  IconData _roomIcon(String type) => switch (type) {
    'd' => Icons.person_outline_rounded,
    'p' => Icons.lock_outline_rounded,
    'l' => Icons.support_agent_rounded,
    _ => Icons.tag_rounded,
  };
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({
    required this.icon,
    required this.text,
    required this.color,
    required this.onClose,
  });
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    child: ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(text),
      trailing: IconButton(
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded),
      ),
    ),
  );
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.onClose});
  final ChatMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      border: Border(
        left: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 3,
        ),
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.reply_rounded, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '回复 ${message.author}：${message.text}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter, control: true):
                    onSend,
              },
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: '输入消息…',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                  helperText: 'Ctrl + Enter 发送',
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: '发送',
            onPressed: onSend,
            style: IconButton.styleFrom(fixedSize: const Size(48, 48)),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    ),
  );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.forum_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '让对话开始吧',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text('从会话列表中选择一个频道或联系人', style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
