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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff13679a)),
        fontFamily: 'MiSansVF',
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff5da9d6),
          brightness: Brightness.dark,
        ),
        fontFamily: 'MiSansVF',
        useMaterial3: true,
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
