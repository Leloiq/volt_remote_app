import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/remote_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/setup/setup_step1_screen.dart';
import 'screens/setup/setup_step2_screen.dart';
import 'screens/setup/setup_step3_screen.dart';
import 'screens/main_shell.dart';
import 'screens/voice_search_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RemoteProvider()),
      ],
      child: const VoltApp(),
    ),
  );
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class VoltApp extends StatefulWidget {
  const VoltApp({super.key});

  @override
  State<VoltApp> createState() => _VoltAppState();
}

class _VoltAppState extends State<VoltApp> {
  StreamSubscription? _errorSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _errorSub = context.read<RemoteProvider>().onError.listen((error) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VOLT Remote',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/setup/1': (context) => const SetupStep1Screen(),
        '/setup/2': (context) => const SetupStep2Screen(),
        '/setup/3': (context) => const SetupStep3Screen(),
        '/home': (context) => const MainShell(),
        '/voice-search': (context) => const VoiceSearchScreen(),
      },
    );
  }
}
