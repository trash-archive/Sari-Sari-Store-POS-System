import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sari_pos/app/router.dart';
import 'package:sari_pos/app/theme.dart';
import 'package:sari_pos/app/splash_screen.dart';
import 'package:sari_pos/app/providers.dart';

class SariPosApp extends ConsumerStatefulWidget {
  const SariPosApp({super.key});

  @override
  ConsumerState<SariPosApp> createState() => _SariPosAppState();
}

class _SariPosAppState extends ConsumerState<SariPosApp> {
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
      title: 'Sari POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _isInitialized ? const MainShell() : const SplashScreen(),
    );
  }
}