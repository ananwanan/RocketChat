import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/room_sidebar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(width: 290, child: RoomSidebar(state: state)),
              const VerticalDivider(width: 1),
              Expanded(child: _ChatPanel(state: state)),
            ],
          ),
        );
      }
      return Scaffold(
        drawer: Drawer(
          width: 310,
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
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
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
    if (room == null) {
      return Builder(
        builder: (context) => Column(
          children: [
            if (widget.mobile)
              AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                title: const Text('Rocket.Chat'),
              ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined, size: 64),
                    SizedBox(height: 12),
                    Text('请选择一个会话'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Builder(
      builder: (context) => Column(
        children: [
          Material(
            elevation: 1,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    if (widget.mobile)
                      IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${room.icon} ${room.displayName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            room.typeLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '搜索消息',
                      onPressed: () => _searchDialog(context),
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: '刷新',
                      onPressed: () => widget.state.selectRoom(room),
                      icon: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          if (widget.state.searchTerm != null)
            Material(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: ListTile(
                dense: true,
                title: Text(
                  '“${widget.state.searchTerm}” 的搜索结果：${widget.state.messages.length} 条',
                ),
                trailing: IconButton(
                  onPressed: widget.state.clearSearch,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          if (widget.state.error != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                dense: true,
                title: Text(widget.state.error!),
                trailing: IconButton(
                  onPressed: widget.state.clearError,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                if (widget.state.messages.isEmpty && !widget.state.busy)
                  const Center(child: Text('暂无消息')),
                ListView.builder(
                  controller: scroll,
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
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
          if (widget.state.replyTo != null)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.reply),
                title: Text(
                  '回复 ${widget.state.replyTo!.author}：${widget.state.replyTo!.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  onPressed: () => widget.state.setReply(null),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): send,
                      },
                      child: TextField(
                        controller: composer,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: '输入消息（Ctrl+Enter 发送）',
                          prefixIcon: Icon(Icons.chat_bubble_outline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '发送',
                    onPressed: send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
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
          decoration: const InputDecoration(labelText: '关键词'),
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
