import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rocket_chat_flutter/app_state.dart';
import 'package:rocket_chat_flutter/models.dart';
import 'package:rocket_chat_flutter/screens/login_screen.dart';
import 'package:rocket_chat_flutter/services/credential_store.dart';
import 'package:rocket_chat_flutter/services/rocket_chat_api.dart';

class FakeConversationApi extends RocketChatApi {
  @override
  Future<List<UserResult>> searchUsers(String term) async => const [
    UserResult(id: 'u2', username: 'alice', name: 'Alice', status: 'online'),
  ];

  @override
  Future<String> createDirectMessage(String username) async => 'room-alice';

  @override
  Future<List<Room>> rooms() async => [];

  @override
  Future<List<ChatMessage>> history(Room room, {int count = 100}) async => [];

  @override
  Future<void> markRead(String roomId) async {}

  @override
  void dispose() {}
}

class MemoryLoginStorage implements SecureStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test('room exposes the correct icon and unread state', () {
    final room = Room(
      id: 'GENERAL',
      name: 'general',
      displayName: 'General',
      type: 'c',
      unread: 3,
    );
    expect(room.icon, '#');
    expect(room.typeLabel, '公开频道');
    expect(room.unread, 3);
  });

  test('message falls back to username and creates an initial', () {
    final message = ChatMessage(
      id: 'm1',
      roomId: 'GENERAL',
      userId: 'u1',
      username: 'coder',
      displayName: '',
      text: 'hello',
      timestamp: DateTime.utc(2026),
    );
    expect(message.author, 'coder');
    expect(message.initial, 'C');
  });

  test('message initial keeps a complete unicode character', () {
    final message = ChatMessage(
      id: 'm2',
      roomId: 'GENERAL',
      userId: 'u2',
      username: 'emoji',
      displayName: '😀 user',
      text: 'hello',
      timestamp: DateTime.utc(2026),
    );
    expect(message.initial, '😀');
  });

  testWidgets('a newly created direct message is visible immediately', (
    tester,
  ) async {
    final state = AppState(
      api: FakeConversationApi(),
      credentialStore: CredentialStore(backend: MemoryLoginStorage()),
    );

    expect(await state.newDirectMessage('@alice'), isTrue);
    expect(state.rooms.map((room) => room.id), contains('room-alice'));
    expect(state.selectedRoom?.id, 'room-alice');
    expect(state.selectedRoom?.avatarUsername, 'alice');

    await state.refreshRooms();
    expect(state.rooms.map((room) => room.id), contains('room-alice'));

    state.dispose();
  });

  testWidgets('login screen uses the configured default server', (
    tester,
  ) async {
    final state = AppState(
      credentialStore: CredentialStore(backend: MemoryLoginStorage()),
    );
    await tester.pumpWidget(MaterialApp(home: LoginScreen(state: state)));
    await tester.pumpAndSettle();

    final serverField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(serverField.controller?.text, 'http://192.168.31.188:3000');

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('login screen restores securely saved credentials', (
    tester,
  ) async {
    final store = CredentialStore(backend: MemoryLoginStorage());
    await store.save(
      const SavedCredentials(
        server: 'https://chat.example.com/',
        username: 'saved-user',
        password: 'saved-password',
      ),
    );
    final state = AppState(credentialStore: store);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'MiSansVF'),
        home: LoginScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rocket.Chat'), findsOneWidget);
    expect(find.text('Flutter 跨平台客户端'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.textContaining('密码只用于本次登录'), findsOneWidget);
    expect(find.text('保存密码'), findsOneWidget);
    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields[0].controller?.text, 'https://chat.example.com/');
    expect(fields[1].controller?.text, 'saved-user');
    expect(fields[2].controller?.text, 'saved-password');
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(
      Theme.of(tester.element(find.text('Rocket.Chat')))
          .textTheme
          .bodyMedium
          ?.fontFamily,
      'MiSansVF',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
