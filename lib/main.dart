import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:tiiun/firebase_options.dart';
import 'package:tiiun/pages/realtime_chat_page.dart';
import 'package:tiiun/pages/onboarding/login_page.dart';
import 'package:tiiun/pages/onboarding/signup_page.dart';
import 'package:tiiun/pages/onboarding/splash_page.dart';
import 'package:tiiun/pages/settings/voice_settings_page.dart'; // 추가
import 'package:tiiun/pages/settings/langchain_test_page.dart'; // 추가
import 'package:tiiun/pages/sensor_monitor_page.dart'; // 센서 모니터링 페이지 추가
import 'package:tiiun/pages/conversation_list_page.dart'; // 대화 목록 페이지 추가
import 'package:tiiun/design_system/colors.dart';
import 'package:tiiun/design_system/typography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('🚀 Flutter 초기화 시작...');
    
    // Firebase 초기화
    print('🔥 Firebase 초기화 시작...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('✅ Firebase Core 초기화 완료');

    // Firebase Realtime Database 초기화
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      print('✅ Firebase Realtime Database initialized');
    } catch (e) {
      print('❌ Firebase Realtime Database initialization failed: $e');
    }

    // Firebase Remote Config 초기화
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      await remoteConfig.setDefaults({
        'openai_api_key': '',
        'trigger_path': 'conversation_trigger',
        'trigger_value': 'start_conversation',
        'reset_value': 'idle',
      });
      
      await remoteConfig.fetchAndActivate();
      
      final apiKey = remoteConfig.getString('openai_api_key');
      if (apiKey.isNotEmpty) {
        print('✅ OpenAI API Key loaded from Remote Config');
      } else {
        print('⚠️ OpenAI API Key not found - using device speech recognition');
      }
      
      print('✅ Remote Config initialized successfully');
    } catch (e) {
      print('❌ Remote Config initialization failed: $e');
      print('🔄 App will use fallback configurations');
    }

    print('🎯 앱 시작 준비 완료');
    runApp(const ProviderScope(child: RealtimeChatApp()));
    
  } catch (e, stackTrace) {
    print('💥 CRITICAL ERROR in main(): $e');
    print('Stack trace: $stackTrace');
    
    // 최소한의 앱이라도 실행
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('초기화 오류: $e'),
        ),
      ),
    ));
  }
}

class RealtimeChatApp extends StatelessWidget {
  const RealtimeChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime Chat AI',
      theme: ThemeData(
        fontFamily: AppTypography.fontFamily,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.main800,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashPage(), // 직접 SplashPage 사용
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const RealtimeChatPage(), // 홈 라우트 추가
        '/realtime_chat': (context) => const RealtimeChatPage(), 
        '/conversation_list': (context) => const ConversationListPage(), // 대화 목록 라우트 추가
        '/voice_settings': (context) => const VoiceSettingsPage(), // 목소리 설정 라우트 추가
        '/langchain_test': (context) => const LangChainTestPage(), // LangChain 테스트 라우트 추가
      },
    );
  }
}
