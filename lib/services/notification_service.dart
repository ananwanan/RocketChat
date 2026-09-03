import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool initialized = false;
  bool enabled = true;
  int _nextId = 1;

  Future<void> initialize({
    required ValueChanged<String> onRoomSelected,
  }) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(defaultActionName: '打开会话'),
      windows: WindowsInitializationSettings(
        appName: 'Rocket.Chat Flutter',
        appUserModelId: 'com.ananwanan.rocketchat',
        guid: '8dc58ba5-f63b-4a46-9f38-d48d8157787b',
      ),
      web: WebInitializationSettings(),
    );
    try {
      initialized =
          await _plugin.initialize(
            settings: settings,
            onDidReceiveNotificationResponse: (response) {
              final roomId = response.payload;
              if (roomId != null && roomId.isNotEmpty) {
                onRoomSelected(roomId);
              }
            },
          ) ??
          false;
    } catch (error) {
      debugPrint('通知初始化失败：$error');
      initialized = false;
      enabled = false;
    }
  }

  Future<bool> requestPermission() async {
    if (!initialized) return false;
    try {
      bool granted = true;
      if (kIsWeb) {
        granted =
            await _plugin
                .resolvePlatformSpecificImplementation<
                  WebFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            granted =
                await _plugin
                    .resolvePlatformSpecificImplementation<
                      AndroidFlutterLocalNotificationsPlugin
                    >()
                    ?.requestNotificationsPermission() ??
                false;
          case TargetPlatform.iOS:
            granted =
                await _plugin
                    .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin
                    >()
                    ?.requestPermissions(
                      alert: true,
                      badge: true,
                      sound: true,
                    ) ??
                false;
          case TargetPlatform.macOS:
            granted =
                await _plugin
                    .resolvePlatformSpecificImplementation<
                      MacOSFlutterLocalNotificationsPlugin
                    >()
                    ?.requestPermissions(
                      alert: true,
                      badge: true,
                      sound: true,
                    ) ??
                false;
          case TargetPlatform.windows:
          case TargetPlatform.linux:
          case TargetPlatform.fuchsia:
            granted = true;
        }
      }
      enabled = granted;
      return granted;
    } catch (error) {
      debugPrint('通知权限请求失败：$error');
      enabled = false;
      return false;
    }
  }

  void disable() => enabled = false;

  Future<void> showMessage(ChatMessage message, Room? room) async {
    if (!initialized || !enabled) return;
    final roomName = room?.displayName ?? '新消息';
    final body = message.text.trim().isEmpty ? '发来一条消息' : message.text.trim();
    try {
      await _plugin.show(
        id: _nextId++,
        title: '${message.author} · $roomName',
        body: body,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            'chat_messages',
            '聊天消息',
            channelDescription: 'Rocket.Chat 新消息提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(threadIdentifier: message.roomId),
          macOS: DarwinNotificationDetails(threadIdentifier: message.roomId),
          linux: const LinuxNotificationDetails(),
          windows: const WindowsNotificationDetails(),
          web: const WebNotificationDetails(),
        ),
        payload: message.roomId,
      );
    } catch (error) {
      debugPrint('消息通知发送失败：$error');
    }
  }
}
