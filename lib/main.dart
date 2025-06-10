import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:tiiun/firebase_options.dart';
import 'package:tiiun/pages/realtime_chat_page.dart';
import 'package:tiiun/pages/advanced_voice_chat_page.dart'; // 새로운 고급 음성 대화 페이지 추가
// 제거됨: motion_waiting_page.dart, motion_waiting_page_simple.dart, motion_waiting_page_zflip.dart - 사용하지 않음
import 'package:tiiun/pages/tiiun_waiting_page.dart'; // 새로운 틔운 대기화면
import 'package:tiiun/pages/foldable_demo_page.dart'; // 폴더블 데모 페이지 추가
import 'package:tiiun/services/foldable_device_service.dart'; // 폴더블 디바이스 서비스 추가
import 'package:tiiun/pages/onboarding/login_page.dart';
import 'package:tiiun/pages/onboarding/signup_page.dart';
import 'package:tiiun/pages/onboarding/splash_page.dart';
import 'package:tiiun/pages/settings/voice_settings_page.dart'; // 추가
import 'package:tiiun/pages/settings/langchain_test_page.dart'; // 추가
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

    // 폴더블 디바이스 서비스 초기화 (백그라운드에서)
    _initializeFoldableService();

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

/// 폴더블 디바이스 서비스 초기화 (백그라운드)
void _initializeFoldableService() async {
  try {
    print('📱 폴더블 디바이스 서비스 초기화 시작...');
    // 여기서는 Provider를 사용할 수 없으므로
    // 실제 초기화는 위젯에서 수행됨
    print('✅ 폴더블 디바이스 서비스 연결 준비 완료');
  } catch (e) {
    print('⚠️ 폴더블 디바이스 서비스 초기화 실패: $e');
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
      home: const TiiunWaitingPage(), // 새로운 틔운 대기화면으로 변경
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),

        '/tiiun_waiting': (context) => const TiiunWaitingPage(), // 새로운 틔운 대기화면
        '/foldable_demo': (context) => const FoldableDemoPage(), // 폴더블 데모 페이지 라우트
        '/home': (context) => const AdvancedVoiceChatPage(), // 고급 음성 대화 페이지로 변경
        '/realtime_chat': (context) => const RealtimeChatPage(),
        '/advanced_voice_chat': (context) => const AdvancedVoiceChatPage(), // 고급 음성 대화 라우트 추가
        '/conversation_list': (context) => const ConversationListPage(), // 대화 목록 라우트 추가
        '/voice_settings': (context) => const VoiceSettingsPage(), // 목소리 설정 라우트 추가
        '/langchain_test': (context) => const LangChainTestPage(), // LangChain 테스트 라우트 추가
      },
    );
  }
}