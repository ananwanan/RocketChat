import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

class RocketChatApi {
  RocketChatApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  Uri? serverUri;
  Session? session;

  Future<({String name, String version})> serverInfo(String server) async {
    _configureServer(server);
    final json = await _request('GET', 'api/info', authenticated: false);
    final info = json['info'] is Map ? _map(json['info']) : json;
    return (
      name: _string(info, 'name', serverUri!.host),
      version: _string(info, 'version'),
    );
  }

  Future<Session> login(String server, String username, String password) async {
    _configureServer(server);
    final json = await _request(
      'POST',
      'api/v1/login',
      body: {'user': username, 'password': password},
      authenticated: false,
    );
    final data = _map(json['data']);
    final me = _map(data['me']);
    session = Session(
      userId: _string(data, 'userId'),
      authToken: _string(data, 'authToken'),
      username: _string(me, 'username', username),
      displayName: _string(me, 'name', username),
    );
    return session!;
  }

  Future<void> logout() async {
    try {
      if (session != null) await _request('POST', 'api/v1/logout', body: {});
    } finally {
      session = null;
    }
  }

  Future<List<Room>> rooms() async {
    final json = await _request('GET', 'api/v1/subscriptions.get');
    final source = json['update'] ?? json['subscriptions'];
    if (source is! List) return [];
    final result = source
        .whereType<Map>()
        .map((raw) => _map(raw))
        .where((item) => item['open'] != false)
        .map(
          (item) => Room(
            id: _string(item, 'rid'),
            name: _string(item, 'name'),
            displayName: _string(item, 'fname', _string(item, 'name')),
            type: _string(item, 't', 'c'),
            unread: _integer(item, 'unread'),
            favorite: item['f'] == true,
            lastSeen: _date(item['ls']),
          ),
        )
        .where((room) => room.id.isNotEmpty)
        .toList();
    result.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return (b.lastSeen ?? DateTime(1970)).compareTo(
        a.lastSeen ?? DateTime(1970),
      );
    });
    return result;
  }

  Future<List<ChatMessage>> history(Room room, {int count = 100}) async {
    final endpoint = switch (room.type) {
      'd' => 'im.history',
      'p' => 'groups.history',
      _ => 'channels.history',
    };
    final json = await _request(
      'GET',
      'api/v1/$endpoint',
      query: {'roomId': room.id, 'count': count.clamp(1, 100).toString()},
    );
    return _messageList(json['messages']);
  }

  Future<ChatMessage> sendMessage(
    String roomId,
    String text, {
    String? threadId,
  }) async {
    final message = <String, dynamic>{'rid': roomId, 'msg': text};
    if (threadId != null) message['tmid'] = threadId;
    final json = await _request(
      'POST',
      'api/v1/chat.sendMessage',
      body: {'message': message},
    );
    return parseMessage(_map(json['message']));
  }

  Future<void> markRead(String roomId) async =>
      _request('POST', 'api/v1/subscriptions.read', body: {'rid': roomId});
  Future<void> updateMessage(
    String roomId,
    String messageId,
    String text,
  ) async => _request(
    'POST',
    'api/v1/chat.update',
    body: {'roomId': roomId, 'msgId': messageId, 'text': text},
  );
  Future<void> deleteMessage(String roomId, String messageId) async => _request(
    'POST',
    'api/v1/chat.delete',
    body: {'roomId': roomId, 'msgId': messageId, 'asUser': true},
  );
  Future<void> react(String messageId, {String emoji = ':+1:'}) async =>
      _request(
        'POST',
        'api/v1/chat.react',
        body: {'messageId': messageId, 'emoji': emoji, 'shouldReact': true},
      );

  Future<List<ChatMessage>> searchMessages(String roomId, String term) async {
    final json = await _request(
      'GET',
      'api/v1/chat.search',
      query: {'roomId': roomId, 'searchText': term, 'count': '100'},
    );
    return _messageList(json['messages']);
  }

  Future<List<UserResult>> searchUsers(String term) async {
    final json = await _request(
      'GET',
      'api/v1/users.autocomplete',
      query: {
        'selector': jsonEncode({'term': term}),
      },
    );
    final source = json['items'] ?? json['users'];
    if (source is! List) return [];
    return source.whereType<Map>().map((raw) {
      final item = _map(raw);
      return UserResult(
        id: _string(item, '_id'),
        username: _string(item, 'username'),
        name: _string(item, 'name'),
        status: _string(item, 'status'),
      );
    }).toList();
  }

  Future<String> createDirectMessage(String username) async {
    final json = await _request(
      'POST',
      'api/v1/im.create',
      body: {'username': username},
    );
    return _string(_map(json['room']), 'rid');
  }

  Future<String> createChannel(String name, {bool private = false}) async {
    final json = await _request(
      'POST',
      'api/v1/${private ? 'groups.create' : 'channels.create'}',
      body: {'name': name, 'members': <String>[]},
    );
    return _string(_map(json[private ? 'group' : 'channel']), '_id');
  }

  ChatMessage parseMessage(Map<String, dynamic> item) {
    final user = _map(item['u']);
    final thread = _string(item, 'tmid');
    return ChatMessage(
      id: _string(item, '_id'),
      roomId: _string(item, 'rid'),
      userId: _string(user, '_id'),
      username: _string(user, 'username'),
      displayName: _string(user, 'name'),
      text: _string(item, 'msg'),
      timestamp: _date(item['ts']) ?? DateTime.now().toUtc(),
      edited: item.containsKey('editedAt'),
      system: _string(item, 't').isNotEmpty,
      threadId: thread.isEmpty ? null : thread,
      replyCount: _integer(item, 'tcount'),
    );
  }

  List<ChatMessage> _messageList(Object? source) {
    if (source is! List) return [];
    final result = source
        .whereType<Map>()
        .map((item) => parseMessage(_map(item)))
        .toList();
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (serverUri == null) throw const RocketChatException('尚未配置服务器。');
    var uri = serverUri!.resolve(path);
    if (query != null) uri = uri.replace(queryParameters: query);
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (authenticated) {
      if (session == null) throw const RocketChatException('请先登录。');
      headers['X-User-Id'] = session!.userId;
      headers['X-Auth-Token'] = session!.authToken;
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 30));
    Map<String, dynamic> json = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) json = _map(decoded);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    if (response.statusCode == 401) {
      throw const RocketChatException('登录失败或会话已过期，请检查账号、密码和服务器地址。');
    }
    throw RocketChatException(
      _string(
        json,
        'message',
        _string(json, 'error', '服务器返回 ${response.statusCode}。'),
      ),
      _string(json, 'errorType'),
    );
  }

  void _configureServer(String server) {
    final input = Uri.tryParse(server.trim());
    if (input == null ||
        !input.hasScheme ||
        !input.hasAuthority ||
        !{'http', 'https'}.contains(input.scheme)) {
      throw const RocketChatException('请输入有效的 http:// 或 https:// 服务器地址。');
    }
    serverUri = input.replace(
      path: '${input.path.replaceFirst(RegExp(r'/+$'), '')}/',
      query: null,
      fragment: null,
    );
  }

  void dispose() => _client.close();
  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static String _string(
    Map<String, dynamic> map,
    String key, [
    String fallback = '',
  ]) => map[key] is String ? map[key] as String : fallback;
  static int _integer(Map<String, dynamic> map, String key) =>
      map[key] is num ? (map[key] as num).toInt() : 0;
  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
