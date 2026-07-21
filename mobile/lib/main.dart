import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/coordinator_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => CoordinatorProvider(),
      child: const SEGApp(),
    ),
  );
}

class SEGApp extends StatelessWidget {
  const SEGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEG Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C5F8A),
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<CoordinatorProvider>(context, listen: false)
            .checkLoginStatus());
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = Provider.of<CoordinatorProvider>(context);
    return coordinator.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}