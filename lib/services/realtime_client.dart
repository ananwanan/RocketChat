import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models.dart';
import 'rocket_chat_api.dart';

class RealtimeClient {
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnectTimer;
  Future<void>? _connectionAttempt;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _subscriptionsChanged = StreamController<void>.broadcast();
  final _status = StreamController<String>.broadcast();
  final Set<String> _desiredRoomIds = {};
  final Map<String, String> _roomSubscriptions = {};
  Uri? _server;
  Session? _session;
  RocketChatApi? _api;
  bool _shouldStayConnected = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<void> get subscriptionsChanged => _subscriptionsChanged.stream;
  Stream<String> get status => _status.stream;

  Future<void> connect(Uri server, Session session, RocketChatApi api) async {
    _server = server;
    _session = session;
    _api = api;
    _shouldStayConnected = true;
    _desiredRoomIds.clear();
    await _openConnection(force: true);
  }

  /// Replaces a potentially stale transport and restores all subscriptions.
  /// Mobile platforms commonly suspend sockets while the app is backgrounded.
  Future<void> reconnect() async {
    if (!_shouldStayConnected || _server == null || _session == null) return;
    await _openConnection(force: true);
  }

  void subscribeRoom(String roomId) {
    _desiredRoomIds.add(roomId);
    if (_channel == null || _roomSubscriptions.containsKey(roomId)) return;
    _subscribeRoom(roomId);
  }

  Future<void> _openConnection({required bool force}) {
    final inProgress = _connectionAttempt;
    if (inProgress != null) return inProgress;

    final attempt = _connectTransport(force: force);
    _connectionAttempt = attempt;
    return attempt.whenComplete(() {
      if (identical(_connectionAttempt, attempt)) _connectionAttempt = null;
    });
  }

  Future<void> _connectTransport({required bool force}) async {
    if (!_shouldStayConnected || _disposed) return;
    if (!force && _channel != null) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeTransport();
    if (!_shouldStayConnected || _disposed) return;

    final server = _server!;
    final session = _session!;
    final socketUri = server.replace(
      scheme: server.scheme == 'https' ? 'wss' : 'ws',
      path: '${server.path.replaceFirst(RegExp(r'/+$'), '')}/websocket',
      query: null,
      fragment: null,
    );
    _emitStatus(_reconnectAttempt == 0 ? '实时连接中' : '实时连接重连中');

    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(socketUri);
      await channel.ready.timeout(const Duration(seconds: 15));
      if (!_shouldStayConnected || _disposed) {
        await channel.sink.close();
        return;
      }

      _channel = channel;
      _subscription = channel.stream.listen(
        _onData,
        onError: (Object error) => _handleTransportClosed(channel!, error),
        onDone: () => _handleTransportClosed(channel!),
        cancelOnError: true,
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
      _send({
        'msg': 'sub',
        'id': 'subscriptions-changed',
        'name': 'stream-notify-user',
        'params': ['${session.userId}/subscriptions-changed', false],
      });
      for (final roomId in _desiredRoomIds) {
        _subscribeRoom(roomId);
      }
      _reconnectAttempt = 0;
      _emitStatus('实时连接已建立');
    } catch (error) {
      if (channel != null && identical(channel, _channel)) {
        await _closeTransport();
      } else if (channel != null) {
        await channel.sink.close();
      }
      _emitStatus('实时连接失败：$error');
      _scheduleReconnect();
      rethrow;
    }
  }

  void _subscribeRoom(String roomId) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-$roomId';
    _roomSubscriptions[roomId] = id;
    _send({
      'msg': 'sub',
      'id': id,
      'name': 'stream-room-messages',
      'params': [roomId, false],
    });
  }

  void _handleTransportClosed(WebSocketChannel channel, [Object? error]) {
    if (!identical(channel, _channel)) return;
    _channel = null;
    _subscription = null;
    _roomSubscriptions.clear();
    _emitStatus(error == null ? '实时连接已关闭' : '实时连接中断：$error');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldStayConnected || _disposed || _reconnectTimer != null) return;
    final seconds = switch (_reconnectAttempt) {
      0 => 1,
      1 => 2,
      2 => 4,
      3 => 8,
      _ => 15,
    };
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(_openConnection(force: false).catchError((_) {}));
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
      if (fields['eventName'] is String &&
          (fields['eventName'] as String).endsWith('/subscriptions-changed')) {
        _subscriptionsChanged.add(null);
        return;
      }
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

  void _emitStatus(String value) {
    if (!_status.isClosed) _status.add(value);
  }

  Future<void> _closeTransport() async {
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    _roomSubscriptions.clear();
    await channel?.sink.close();
  }

  Future<void> disconnect() async {
    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _server = null;
    _session = null;
    _api = null;
    _desiredRoomIds.clear();
    await _closeTransport();
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messages.close();
    await _subscriptionsChanged.close();
    await _status.close();
  }
}
