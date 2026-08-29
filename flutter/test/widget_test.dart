import 'package:flutter_test/flutter_test.dart';
import 'package:rocket_chat_flutter/main.dart';
import 'package:rocket_chat_flutter/models.dart';

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

  testWidgets('login screen renders without credentials', (tester) async {
    await tester.pumpWidget(const RocketChatApp());
    expect(find.text('Rocket.Chat'), findsOneWidget);
    expect(find.text('Flutter 跨平台客户端'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.textContaining('密码只用于本次登录'), findsOneWidget);
  });
}
