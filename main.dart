import 'package:classico/Welcome_Screen.dart';
import 'package:classico/Register_screen.dart';
import 'package:classico/Forget_password.dart';
import 'package:classico/Home_Screen.dart';
import 'package:classico/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppSettings _settings = AppSettings();
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () { if (mounted) setState(() {}); };
    _settings.addListener(_listener);
  }

  @override
  void dispose() {
    _settings.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _settings.themeData,
      locale: _settings.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), Locale('hi'), Locale('fr'),
        Locale('de'), Locale('zh'), Locale('ja'),
      ],
      initialRoute: 'Welcome_Screen',
      routes: {
        'Welcome_Screen': (context) => const WelcomeScreen(),
        'Register_screen': (context) => const MyRegister(),
        'Forget_password': (context) => const ForgetPassword(),
        'Home_Screen': (context) => const HomeScreen(),
      },
    );
  }
}
