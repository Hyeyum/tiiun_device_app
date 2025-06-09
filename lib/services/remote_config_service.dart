// lib/services/remote_config_service.dart
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      // 🎯 방법 1: 기존 구조 유지 - 트리거 시스템용 기본값 설정
      await _remoteConfig.setDefaults({
        'openai_api_key': '', // OpenAI API 키
        'trigger_path': 'conversation_trigger', // 트리거 감지 경로
        'trigger_value': 'start_conversation',  // 대화 시작 트리거 값
        'reset_value': 'idle',                 // 트리거 후 리셋 값
      });
      
      await _remoteConfig.fetchAndActivate();
      debugPrint('✅ Remote Config initialized and fetched.');
      
      // 설정값 로그 출력
      debugPrint('🔧 Remote Config Values:');
      debugPrint('   - OpenAI API Key: ${getOpenAIApiKey().isNotEmpty ? "설정됨" : "미설정"}');
      debugPrint('   - Trigger Path: ${getTriggerPath()}');
      debugPrint('   - Trigger Value: ${getTriggerValue()}');
      debugPrint('   - Reset Value: ${getResetValue()}');
      
    } catch (e) {
      debugPrint('❌ Error initializing or fetching Remote Config: $e');
    }
  }

  // OpenAI API 키 가져오기
  String getOpenAIApiKey() {
    return _remoteConfig.getString('openai_api_key');
  }

  // 🎯 트리거 시스템 설정값들
  String getTriggerPath() {
    return _remoteConfig.getString('trigger_path');
  }

  String getTriggerValue() {
    return _remoteConfig.getString('trigger_value');
  }

  String getResetValue() {
    return _remoteConfig.getString('reset_value');
  }

  // 전체 트리거 설정을 한번에 가져오기
  Map<String, String> getTriggerConfig() {
    return {
      'trigger_path': getTriggerPath(),
      'trigger_value': getTriggerValue(),
      'reset_value': getResetValue(),
    };
  }

  // 설정 새로고침
  Future<bool> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
      debugPrint('✅ Remote Config refreshed');
      return true;
    } catch (e) {
      debugPrint('❌ Error refreshing Remote Config: $e');
      return false;
    }
  }
}