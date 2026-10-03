import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/ss_theme.dart';

/// A01 — chỉ logo; chuyển ngay khi kiểm tra phiên xong.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // TODO: kiểm tra session + AppGate từ backend, rồi go('/welcome') hoặc go('/home').
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.radio_button_checked_rounded, color: cs.onPrimary, size: 36),
          ),
          const SizedBox(height: SsSpace.lg),
          Text('SaveStream', style: context.tt.titleLarge),
        ]),
      ),
    );
  }
}
