import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Sesuaikan "tubes" dengan nama project di pubspec.yaml Anda
import 'package:tubes/screens/splash_screen.dart';
import 'package:tubes/screens/home_screen.dart';
import 'package:tubes/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://behgklcedtclmdghxxxm.supabase.co/',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlaGdrbGNlZHRjbG1kZ2h4eHhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzOTk0MzMsImV4cCI6MjA5Njk3NTQzM30.7rXiTJGi56TZQBvwsk8slqz-HWEUbCIeGfZMdQ_2Kd8',
  );

  runApp(const SmartAssetTrackerApp());
}

class SmartAssetTrackerApp extends StatelessWidget {
  const SmartAssetTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}