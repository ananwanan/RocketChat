import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models.dart';
import 'rocket_chat_api.dart';

class RealtimeClient {
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _status = StreamController<String>.broadcast();
  final Map<String, String> _roomSubscriptions = {};
  RocketChatApi? _api;
  Stream<ChatMessage> get messages => _messages.stream;
  Stream<String> get status => _status.stream;

  Future<void> connect(Uri server, Session session, RocketChatApi api) async {
    await disconnect();
    _api = api;
    final socketUri = server.replace(
      scheme: server.scheme == 'https' ? 'wss' : 'ws',
      path: '${server.path.replaceFirst(RegExp(r'/+$'), '')}/websocket',
      query: null,
      fragment: null,
    );
    final channel = WebSocketChannel.connect(socketUri);
    await channel.ready.timeout(const Duration(seconds: 15));
    _channel = channel;
    _subscription = channel.stream.listen(
      _onData,
      onError: (Object error) => _status.add('实时连接中断：$error'),
      onDone: () => _status.add('实时连接已关闭'),
    );
    _send({
      'msg': 'connect',
      'version': '1',
      'support': ['1'],
    });
    _send({
      'msg': 'method',
      'method': 'login',
      'id': 'login',
      'params': [
        {'resume': session.authToken},
      ],
    });
    _status.add('实时连接已建立');
  }

  void subscribeRoom(String roomId) {
    final old = _roomSubscriptions.remove(roomId);
    if (old != null) _send({'msg': 'unsub', 'id': old});
    final id = '${DateTime.now().microsecondsSinceEpoch}-$roomId';
    _roomSubscriptions[roomId] = id;
    _send({
      'msg': 'sub',
      'id': id,
      'name': 'stream-room-messages',
      'params': [roomId, false],
    });
  }

  void _onData(Object? value) {
    try {
      final decoded = jsonDecode(value as String);
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      if (json['msg'] == 'ping') {
        _send({'msg': 'pong'});
        return;
      }
      if (json['msg'] != 'changed') return;
      final fields = json['fields'];
      if (fields is! Map || fields['args'] is! List) return;
      for (final raw in fields['args'] as List) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final message = item.containsKey('_id') ? item : item['message'];
        if (message is Map) {
          _messages.add(_api!.parseMessage(Map<String, dynamic>.from(message)));
        }
      }
    } catch (_) {
      // Ignore frames that are not Rocket.Chat message events.
    }
  }

  void _send(Map<String, dynamic> value) =>
      _channel?.sink.add(jsonEncode(value));

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _roomSubscriptions.clear();
  }

  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _status.close();
  }
}
