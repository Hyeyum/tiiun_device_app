import 'package:shared_preferences/shared_preferences.dart';

class VoicePreferences {
  static const String _selectedVoiceKey = 'selected_voice';
  static const String _defaultVoice = 'alloy';

  /// 현재 선택된 목소리 ID를 가져옵니다
  static Future<String> getSelectedVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedVoiceKey) ?? _defaultVoice;
  }

  /// 목소리 ID를 저장합니다
  static Future<void> setSelectedVoiceId(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedVoiceKey, voiceId);
  }

  /// 사용 가능한 목소리 목록을 반환합니다
  static Map<String, String> getAvailableVoices() {
    return {
      'plant': '🌱 이파리 (자연의 지혜로 위로하는 식물 AI)',
      'alloy': '앨로이 (중성적이고 부드러운)',
      'echo': '에코 (남성적이고 깊은)',
      'fable': '페이블 (여성적이고 따뜻한)',
      'onyx': '오닉스 (남성적이고 힘 있는)',
      'nova': '노바 (젊고 활기찬)',
      'shimmer': '시머 (부드럽고 차분한)',
    };
  }
}