import 'dart:async';

import 'package:flutter/widgets.dart';

import 'models.dart';
import 'services/credential_store.dart';
import 'services/notification_service.dart';
import 'services/realtime_client.dart';
import 'services/rocket_chat_api.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({
    RocketChatApi? api,
    RealtimeClient? realtime,
    CredentialStore? credentialStore,
    NotificationService? notificationService,
  }) : api = api ?? RocketChatApi(),
       realtime = realtime ?? RealtimeClient(),
       credentialStore = credentialStore ?? CredentialStore(),
       notificationService = notificationService ?? NotificationService() {
    WidgetsBinding.instance.addObserver(this);
    _messageSubscription = this.realtime.messages.listen(_onRealtimeMessage);
    _roomsSubscription = this.realtime.subscriptionsChanged.listen((_) {
      unawaited(_refreshRoomsFromRealtime());
    });
    _statusSubscription = this.realtime.status.listen((value) {
      realtimeStatus = value;
      notifyListeners();
    });
  }
  final RocketChatApi api;
  final RealtimeClient realtime;
  final CredentialStore credentialStore;
  final NotificationService notificationService;
  late final StreamSubscription<ChatMessage> _messageSubscription;
  late final StreamSubscription<void> _roomsSubscription;
  late final StreamSubscription<String> _statusSubscription;
  Session? session;
  String workspaceName = 'Rocket.Chat';
  String workspaceVersion = '';
  String realtimeStatus = 'REST 模式';
  bool busy = false;
  String? error;
  List<Room> rooms = [];
  List<ChatMessage> messages = [];
  Room? selectedRoom;
  ChatMessage? replyTo;
  String roomFilter = '';
  String? searchTerm;
  bool _appActive = true;
  bool _refreshingRooms = false;
  bool _resumingRealtime = false;
  final Set<String> _pendingCreatedRoomIds = {};

  bool get notificationsEnabled => notificationService.enabled;

  Future<void> initializeNotifications() async {
    await notificationService.initialize(onRoomSelected: _openRoomById);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (!value) {
      notificationService.disable();
      notifyListeners();
      return;
    }
    final granted = await notificationService.requestPermission();
    if (!granted) error = '系统未授予通知权限，请在系统设置中开启。';
    notifyListeners();
  }

  List<Room> get filteredRooms {
    if (roomFilter.trim().isEmpty) return rooms;
    final term = roomFilter.toLowerCase();
    return rooms
        .where((room) => room.displayName.toLowerCase().contains(term))
        .toList();
  }

  Future<SavedCredentials?> loadSavedCredentials() async {
    try {
      return await credentialStore.load();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSavedCredentials() async {
    try {
      await credentialStore.clear();
    } catch (exception) {
      error = '清除已保存密码失败：$exception';
      notifyListeners();
    }
  }

  Future<bool> login(
    String server,
    String username,
    String password, {
    bool rememberPassword = false,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final info = await api.serverInfo(server);
      final activeSession = await api.login(server, username, password);
      session = activeSession;
      workspaceName = info.name;
      workspaceVersion = info.version;
      await refreshRooms();
      try {
        if (rememberPassword) {
          await credentialStore.save(
            SavedCredentials(
              server: server.trim(),
              username: username.trim(),
              password: password,
            ),
          );
        } else {
          await credentialStore.clear();
        }
      } catch (exception) {
        error = '登录成功，但保存密码失败：$exception';
      }
      try {
        await realtime.connect(api.serverUri!, activeSession, api);
        for (final room in rooms) {
          realtime.subscribeRoom(room.id);
        }
      } catch (exception) {
        realtimeStatus = 'REST 模式：$exception';
      }
      await setNotificationsEnabled(true);
      return true;
    } catch (exception) {
      error = exception.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshRooms({String? selectRoomId}) async {
    final previousRooms = rooms;
    final refreshedRooms = await api.rooms();
    for (final roomId in _pendingCreatedRoomIds.toList()) {
      if (refreshedRooms.any((room) => room.id == roomId)) {
        _pendingCreatedRoomIds.remove(roomId);
        continue;
      }
      final oldIndex = previousRooms.indexWhere((room) => room.id == roomId);
      if (oldIndex >= 0) refreshedRooms.insert(0, previousRooms[oldIndex]);
    }
    rooms = refreshedRooms;
    final currentId = selectedRoom?.id;
    if (currentId != null) {
      final currentIndex = rooms.indexWhere((room) => room.id == currentId);
      if (currentIndex >= 0) selectedRoom = rooms[currentIndex];
    }
    notifyListeners();
    if (selectRoomId != null) {
      final index = rooms.indexWhere((room) => room.id == selectRoomId);
      if (index >= 0) await selectRoom(rooms[index]);
    } else if (selectedRoom == null && rooms.isNotEmpty) {
      await selectRoom(rooms.first);
    }
  }

  Future<void> selectRoom(Room room) async {
    selectedRoom = room;
    messages = [];
    replyTo = null;
    searchTerm = null;
    busy = true;
    notifyListeners();
    try {
      final loaded = await api.history(room);
      if (selectedRoom?.id == room.id) messages = loaded;
      room.unread = 0;
      unawaited(api.markRead(room.id));
      realtime.subscribeRoom(room.id);
    } catch (exception) {
      error = exception.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> send(String text) async {
    final room = selectedRoom;
    if (room == null || text.trim().isEmpty) return false;
    try {
      final message = await api.sendMessage(
        room.id,
        text.trim(),
        threadId: replyTo?.id,
      );
      _upsertMessage(message);
      replyTo = null;
      notifyListeners();
      return true;
    } catch (exception) {
      error = exception.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> search(String term) async {
    final room = selectedRoom;
    if (room == null || term.trim().isEmpty) return;
    busy = true;
    notifyListeners();
    try {
      messages = await api.searchMessages(room.id, term.trim());
      searchTerm = term.trim();
    } catch (exception) {
      error = exception.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clearSearch() async {
    searchTerm = null;
    if (selectedRoom != null) await selectRoom(selectedRoom!);
  }

  Future<void> edit(ChatMessage message, String text) async {
    await api.updateMessage(message.roomId, message.id, text);
    if (selectedRoom != null) await selectRoom(selectedRoom!);
  }

  Future<void> delete(ChatMessage message) async {
    await api.deleteMessage(message.roomId, message.id);
    messages.removeWhere((item) => item.id == message.id);
    notifyListeners();
  }

  Future<void> react(ChatMessage message) => api.react(message.id);

  Future<bool> newDirectMessage(String term) async {
    final users = await api.searchUsers(term);
    if (users.isEmpty) return false;
    final normalized = term.replaceFirst('@', '').toLowerCase();
    final index = users.indexWhere(
      (item) => item.username.toLowerCase() == normalized,
    );
    final user = index >= 0 ? users[index] : users.first;
    final roomId = await api.createDirectMessage(user.username);
    await _openCreatedRoom(
      Room(
        id: roomId,
        name: user.username,
        displayName: user.name.isEmpty ? user.username : user.name,
        type: 'd',
        avatarUsername: user.username,
      ),
    );
    return true;
  }

  Future<void> newChannel(String name, {bool private = false}) async {
    final roomId = await api.createChannel(name, private: private);
    await _openCreatedRoom(
      Room(
        id: roomId,
        name: name,
        displayName: name,
        type: private ? 'p' : 'c',
      ),
    );
  }

  Future<void> _openCreatedRoom(Room room) async {
    if (room.id.isEmpty) {
      throw const RocketChatException('服务器已创建会话，但没有返回会话 ID。');
    }
    final index = rooms.indexWhere((item) => item.id == room.id);
    if (index < 0) {
      _pendingCreatedRoomIds.add(room.id);
      rooms = [room, ...rooms];
    }
    await selectRoom(index < 0 ? room : rooms[index]);
  }

  Future<void> _refreshRoomsFromRealtime() async {
    if (_refreshingRooms || session == null) return;
    _refreshingRooms = true;
    try {
      await refreshRooms();
      for (final room in rooms) {
        realtime.subscribeRoom(room.id);
      }
    } catch (_) {
      // A transient refresh failure must not tear down the realtime stream.
    } finally {
      _refreshingRooms = false;
    }
  }

  void setReply(ChatMessage? message) {
    replyTo = message;
    notifyListeners();
  }

  void setRoomFilter(String value) {
    roomFilter = value;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await realtime.disconnect();
    await api.logout();
    session = null;
    rooms = [];
    messages = [];
    selectedRoom = null;
    _pendingCreatedRoomIds.clear();
    error = null;
    notifyListeners();
  }

  void _onRealtimeMessage(ChatMessage message) {
    final isCurrentRoom = message.roomId == selectedRoom?.id;
    final roomIndex = rooms.indexWhere((room) => room.id == message.roomId);
    final room = roomIndex < 0 ? null : rooms[roomIndex];
    if (isCurrentRoom) {
      _upsertMessage(message);
    } else {
      if (room != null) room.unread++;
    }
    if (message.userId != session?.userId && (!_appActive || !isCurrentRoom)) {
      unawaited(notificationService.showMessage(message, room));
    }
    notifyListeners();
  }

  Future<void> _openRoomById(String roomId) async {
    final index = rooms.indexWhere((room) => room.id == roomId);
    if (index >= 0) await selectRoom(rooms[index]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasActive = _appActive;
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive && !wasActive && session != null) {
      unawaited(_resumeRealtime());
    }
  }

  Future<void> _resumeRealtime() async {
    if (_resumingRealtime || session == null) return;
    _resumingRealtime = true;
    try {
      await realtime.reconnect();
      await refreshRooms();
      final room = selectedRoom;
      if (room != null && searchTerm == null) {
        final latest = await api.history(room);
        if (selectedRoom?.id == room.id && searchTerm == null) {
          final byId = <String, ChatMessage>{
            for (final message in messages) message.id: message,
            for (final message in latest) message.id: message,
          };
          messages = byId.values.toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          notifyListeners();
        }
      }
    } catch (exception) {
      // RealtimeClient keeps retrying after transient mobile network failures.
      realtimeStatus = '实时连接恢复中：$exception';
      notifyListeners();
    } finally {
      _resumingRealtime = false;
    }
  }

  void _upsertMessage(ChatMessage message) {
    final index = messages.indexWhere((item) => item.id == message.id);
    if (index < 0) {
      messages = [...messages, message]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else {
      messages[index] = message;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription.cancel();
    _roomsSubscription.cancel();
    _statusSubscription.cancel();
    realtime.dispose();
    api.dispose();
    super.dispose();
  }
}
