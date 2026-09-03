import 'package:flutter/material.dart';

import '../app_state.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.state,
    required this.username,
    required this.label,
    this.radius = 18,
  });

  final AppState state;
  final String username;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final uri = state.api.avatarUri(username);
    final fallback = _FallbackAvatar(
      radius: radius,
      label: label,
      color: _avatarColor(username.isEmpty ? label : username),
    );
    if (uri == null) return fallback;
    return ClipOval(
      child: Image.network(
        uri.toString(),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        headers: state.api.authenticationHeaders,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  static Color _avatarColor(String value) {
    const colors = [
      Color(0xff6c6ce5),
      Color(0xffec6f83),
      Color(0xff2ca58d),
      Color(0xffd8893a),
      Color(0xff4c88d9),
    ];
    return colors[value.hashCode.abs() % colors.length];
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({
    required this.radius,
    required this.label,
    required this.color,
  });

  final double radius;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: color,
    foregroundColor: Colors.white,
    child: Text(
      label.isEmpty
          ? '?'
          : String.fromCharCode(label.runes.first).toUpperCase(),
      style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.w700),
    ),
  );
}
