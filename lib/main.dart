import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RocketChatApp());
}

class RocketChatApp extends StatefulWidget {
  const RocketChatApp({super.key});

  @override
  State<RocketChatApp> createState() => _RocketChatAppState();
}

class _RocketChatAppState extends State<RocketChatApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = AppState();
    unawaited(state.initializeNotifications());
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rocket.Chat Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff5b5bd6),
          primary: const Color(0xff5555cf),
          surface: const Color(0xfff7f8fc),
        ),
        fontFamily: 'MiSansVF',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff7f8fc),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xffffffff),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffe3e5ee)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffe3e5ee)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xff6868df), width: 1.5),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            side: BorderSide(color: Color(0xffe8e9f1)),
          ),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xffe8e9f1)),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff5da9d6),
          brightness: Brightness.dark,
        ),
        fontFamily: 'MiSansVF',
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => state.session == null
            ? LoginScreen(state: state)
            : HomeScreen(state: state),
      ),
    );
  }
}
