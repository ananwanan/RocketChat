class Session {
  const Session({
    required this.userId,
    required this.authToken,
    required this.username,
    required this.displayName,
  });
  final String userId;
  final String authToken;
  final String username;
  final String displayName;
}

class Room {
  Room({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type,
    this.unread = 0,
    this.favorite = false,
    this.lastSeen,
    this.avatarUsername,
  });
  final String id;
  final String name;
  final String displayName;
  final String type;
  int unread;
  final bool favorite;
  final DateTime? lastSeen;
  final String? avatarUsername;
  String get icon => switch (type) {
    'd' => '●',
    'p' => '◆',
    'l' => '☎',
    _ => '#',
  };
  String get typeLabel => switch (type) {
    'd' => '私信',
    'p' => '私有频道',
    'l' => '在线客服',
    _ => '公开频道',
  };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.text,
    required this.timestamp,
    this.edited = false,
    this.system = false,
    this.threadId,
    this.replyCount = 0,
  });
  final String id;
  final String roomId;
  final String userId;
  final String username;
  final String displayName;
  final String text;
  final DateTime timestamp;
  final bool edited;
  final bool system;
  final String? threadId;
  final int replyCount;
  String get author => displayName.isEmpty ? username : displayName;
  String get initial => author.isEmpty
      ? '?'
      : String.fromCharCode(author.runes.first).toUpperCase();
}

class UserResult {
  const UserResult({
    required this.id,
    required this.username,
    required this.name,
    required this.status,
  });
  final String id;
  final String username;
  final String name;
  final String status;
  String get label => name.isEmpty ? '@$username' : '$name  @$username';
}

class RocketChatException implements Exception {
  const RocketChatException(this.message, [this.errorType]);
  final String message;
  final String? errorType;
  @override
  String toString() => message;
}
