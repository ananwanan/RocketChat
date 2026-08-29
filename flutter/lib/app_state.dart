import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'services/realtime_client.dart';
import 'services/rocket_chat_api.dart';

class AppState extends ChangeNotifier {
  AppState({RocketChatApi? api, RealtimeClient? realtime})
    : api = api ?? RocketChatApi(),
      realtime = realtime ?? RealtimeClient() {
    _messageSubscription = this.realtime.messages.listen(_onRealtimeMessage);
    _statusSubscription = this.realtime.status.listen((value) {
      realtimeStatus = value;
      notifyListeners();
    });
  }
  final RocketChatApi api;
  final RealtimeClient realtime;
  late final StreamSubscription<ChatMessage> _messageSubscription;
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

  List<Room> get filteredRooms {
    if (roomFilter.trim().isEmpty) return rooms;
    final term = roomFilter.toLowerCase();
    return rooms
        .where((room) => room.displayName.toLowerCase().contains(term))
        .toList();
  }

  Future<bool> login(String server, String username, String password) async {
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
        await realtime.connect(api.serverUri!, activeSession, api);
      } catch (exception) {
        realtimeStatus = 'REST 模式：$exception';
      }
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
    rooms = await api.rooms();
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
    final roomId = await api.createDirectMessage(
      (index >= 0 ? users[index] : users.first).username,
    );
    await refreshRooms(selectRoomId: roomId);
    return true;
  }

  Future<void> newChannel(String name, {bool private = false}) async {
    final roomId = await api.createChannel(name, private: private);
    await refreshRooms(selectRoomId: roomId);
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
    error = null;
    notifyListeners();
  }

  void _onRealtimeMessage(ChatMessage message) {
    if (message.roomId == selectedRoom?.id) {
      _upsertMessage(message);
    } else {
      final index = rooms.indexWhere((room) => room.id == message.roomId);
      if (index >= 0) rooms[index].unread++;
    }
    notifyListeners();
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
    _messageSubscription.cancel();
    _statusSubscription.cancel();
    realtime.dispose();
    api.dispose();
    super.dispose();
  }
}
