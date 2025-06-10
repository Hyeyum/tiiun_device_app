import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tiiun/design_system/colors.dart';
import 'package:tiiun/design_system/typography.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // 2초 대기 (스플래시 화면 표시)
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Firebase Auth 상태 확인
      final currentUser = FirebaseAuth.instance.currentUser;
      print('🔍 Current user in splash: ${currentUser?.email ?? "null"}');

      if (currentUser != null) {
        // 로그인된 사용자 - TiiunWaitingPage로 이동
        print('🔍 User logged in, going to tiiun waiting');
        Navigator.pushReplacementNamed(context, '/tiiun_waiting');
      } else {
        // 로그인되지 않은 사용자 - 로그인 페이지로 이동
        print('🔍 User not logged in, going to login');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('❌ Splash navigation error: $e');
      // 에러 발생 시 로그인 페이지로 이동
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.main800,
              Color(0xFF4A90E2),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 앱 아이콘
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 60,
                  color: AppColors.main800,
                ),
              ),

              const SizedBox(height: 32),

              // 앱 제목
              Text(
                'Realtime Chat AI',
                style: AppTypography.h1.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // 부제목
              Text(
                'AI와 실시간 음성 대화',
                style: AppTypography.b1.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Firebase Realtime Database 트리거 기반',
                style: AppTypography.b2.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),

              const SizedBox(height: 50),

              // 로딩 인디케이터
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                '로딩 중...',
                style: AppTypography.b2.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
