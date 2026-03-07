import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tindako/app/router.dart';
import 'package:tindako/app/theme.dart';
import 'package:tindako/app/splash_screen.dart';
import 'package:tindako/app/providers.dart';

class TindaKoApp extends ConsumerStatefulWidget {
  const TindaKoApp({super.key});

  @override
  ConsumerState<TindaKoApp> createState() => _TindaKoAppState();
}

class _TindaKoAppState extends ConsumerState<TindaKoApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize database
    ref.read(databaseProvider);
    // Simulate minimum splash time for better UX
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TindaKo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _isInitialized ? const MainShell() : const SplashScreen(),
    );
  }
}