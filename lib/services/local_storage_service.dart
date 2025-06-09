import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// 로컬 저장소 서비스
/// 
/// 앱의 설정과 기본 데이터를 로컬에 저장하고 관리합니다.
class LocalStorageService {
  static SharedPreferences? _prefs;
  
  // 싱글톤 인스턴스
  static LocalStorageService? _instance;
  static LocalStorageService get instance => _instance ??= LocalStorageService._();
  
  // 초기화 플래그
  bool _initialized = false;
  bool get isInitialized => _initialized;
  
  // 비공개 생성자
  LocalStorageService._();
  
  /// 로컬 저장소 서비스 초기화
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      AppLogger.info('LocalStorageService: Initialized successfully');
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to initialize - $e');
      rethrow;
    }
  }
  
  /// 문자열 값 저장
  Future<bool> setString(String key, String value) async {
    _checkInitialized();
    try {
      final result = await _prefs!.setString(key, value);
      AppLogger.debug('LocalStorageService: Set string - $key: $value');
      return result;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to set string - $key: $e');
      return false;
    }
  }
  
  /// 문자열 값 가져오기
  String? getString(String key) {
    _checkInitialized();
    try {
      final value = _prefs!.getString(key);
      AppLogger.debug('LocalStorageService: Get string - $key: $value');
      return value;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to get string - $key: $e');
      return null;
    }
  }
  
  /// 불리언 값 저장
  Future<bool> setBool(String key, bool value) async {
    _checkInitialized();
    try {
      final result = await _prefs!.setBool(key, value);
      AppLogger.debug('LocalStorageService: Set bool - $key: $value');
      return result;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to set bool - $key: $e');
      return false;
    }
  }
  
  /// 불리언 값 가져오기
  bool? getBool(String key) {
    _checkInitialized();
    try {
      final value = _prefs!.getBool(key);
      AppLogger.debug('LocalStorageService: Get bool - $key: $value');
      return value;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to get bool - $key: $e');
      return null;
    }
  }
  
  /// 기본값이 있는 불리언 값 가져오기
  bool getBoolWithDefault(String key, bool defaultValue) {
    return getBool(key) ?? defaultValue;
  }
  
  /// 정수 값 저장
  Future<bool> setInt(String key, int value) async {
    _checkInitialized();
    try {
      final result = await _prefs!.setInt(key, value);
      AppLogger.debug('LocalStorageService: Set int - $key: $value');
      return result;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to set int - $key: $e');
      return false;
    }
  }
  
  /// 정수 값 가져오기
  int? getInt(String key) {
    _checkInitialized();
    try {
      final value = _prefs!.getInt(key);
      AppLogger.debug('LocalStorageService: Get int - $key: $value');
      return value;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to get int - $key: $e');
      return null;
    }
  }
  
  /// 더블 값 저장
  Future<bool> setDouble(String key, double value) async {
    _checkInitialized();
    try {
      final result = await _prefs!.setDouble(key, value);
      AppLogger.debug('LocalStorageService: Set double - $key: $value');
      return result;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to set double - $key: $e');
      return false;
    }
  }
  
  /// 더블 값 가져오기
  double? getDouble(String key) {
    _checkInitialized();
    try {
      final value = _prefs!.getDouble(key);
      AppLogger.debug('LocalStorageService: Get double - $key: $value');
      return value;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to get double - $key: $e');
      return null;
    }
  }
  
  /// 문자열 리스트 저장
  Future<bool> setStringList(String key, List<String> value) async {
    _checkInitialized();
    try {
      final result = await _prefs!.setStringList(key, value);
      AppLogger.debug('LocalStorageService: Set string list - $key: $value');
      return result;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to set string list - $key: $e');
      return false;
    }
  }
  
  /// 문자열 리스트 가져오기
  List<String>? getStringList(String key) {
    _checkInitialized();
    try {
      final value = _prefs!.getStringList(key);
      AppLogger.debug('LocalStorageService: Get string list - $key: $value');
      return value;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to get string list - $key: $e');
      return null;
    }
  }
  
  /// JSON 객체 저장
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    _checkInitialized();
    try {
      final jsonString = jsonEncode(value);
      final result = await _prefs!.setString(key, jsonString);
      AppLogger.debug('LocalStorageService: Set JSON - $key: $value');
      return result;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to set JSON - $key: $e');
      return false;
    }
  }
  
  /// JSON 객체 가져오기
  Map<String, dynamic>? getJson(String key) {
    _checkInitialized();
    try {
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) return null;
      final value = jsonDecode(jsonString) as Map<String, dynamic>;
      AppLogger.debug('LocalStorageService: Get JSON - $key: $value');
      return value;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to get JSON - $key: $e');
      return null;
    }
  }
  
  /// 키 삭제
  Future<bool> remove(String key) async {
    _checkInitialized();
    try {
      final result = await _prefs!.remove(key);
      AppLogger.debug('LocalStorageService: Removed key - $key');
      return result;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to remove key - $key: $e');
      return false;
    }
  }
  
  /// 모든 키 삭제
  Future<bool> clear() async {
    _checkInitialized();
    try {
      final result = await _prefs!.clear();
      AppLogger.debug('LocalStorageService: Cleared all keys');
      return result;
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to clear all keys - $e');
      return false;
    }
  }
  
  /// 키 존재 여부 확인
  bool containsKey(String key) {
    _checkInitialized();
    return _prefs!.containsKey(key);
  }
  
  /// 모든 키 가져오기
  Set<String> getKeys() {
    _checkInitialized();
    return _prefs!.getKeys();
  }
  
  /// 초기화 여부 확인
  void _checkInitialized() {
    if (!_initialized) {
      AppLogger.error('LocalStorageService: Service is not initialized');
      throw Exception('LocalStorageService is not initialized');
    }
  }
  
  /// 사용자 토큰 저장
  Future<bool> setUserToken(String token) async {
    return setString(StorageKeys.userToken, token);
  }
  
  /// 사용자 토큰 가져오기
  String? getUserToken() {
    return getString(StorageKeys.userToken);
  }
  
  /// 사용자 ID 저장
  Future<bool> setUserId(String userId) async {
    return setString(StorageKeys.userId, userId);
  }
  
  /// 사용자 ID 가져오기
  String? getUserId() {
    return getString(StorageKeys.userId);
  }
  
  /// 다크 모드 설정 저장
  Future<bool> setDarkMode(bool enabled) async {
    return setBool(StorageKeys.darkModeEnabled, enabled);
  }
  
  /// 다크 모드 설정 가져오기
  bool getDarkMode() {
    return getBoolWithDefault(StorageKeys.darkModeEnabled, false);
  }
  
  /// 알림 활성화 상태 저장
  Future<bool> setNotificationsEnabled(bool enabled) async {
    return setBool(StorageKeys.notificationsEnabled, enabled);
  }
  
  /// 알림 활성화 상태 가져오기
  bool getNotificationsEnabled() {
    return getBoolWithDefault(StorageKeys.notificationsEnabled, true);
  }
  
  /// 온보딩 완료 상태 저장
  Future<bool> setOnboardingCompleted(bool completed) async {
    return setBool(StorageKeys.isOnboardingCompleted, completed);
  }
  
  /// 온보딩 완료 상태 가져오기
  bool getOnboardingCompleted() {
    return getBoolWithDefault(StorageKeys.isOnboardingCompleted, false);
  }
  
  /// 최근 감정 기록 날짜 저장
  Future<bool> setLastMoodRecordDate(DateTime date) async {
    return setString(StorageKeys.lastMoodRecordDate, date.toIso8601String());
  }
  
  /// 최근 감정 기록 날짜 가져오기
  DateTime? getLastMoodRecordDate() {
    final dateStr = getString(StorageKeys.lastMoodRecordDate);
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      AppLogger.error('LocalStorageService: Failed to parse date - $dateStr: $e');
      return null;
    }
  }
  
  /// 최근 대화 ID 리스트 저장
  Future<bool> setRecentConversationIds(List<String> ids) async {
    return setStringList(StorageKeys.recentConversationIds, ids);
  }
  
  /// 최근 대화 ID 리스트 가져오기
  List<String> getRecentConversationIds() {
    return getStringList(StorageKeys.recentConversationIds) ?? [];
  }
  
  /// 선호하는 에이전트 ID 저장
  Future<bool> setPreferredAgentId(String agentId) async {
    return setString(StorageKeys.preferredAgentId, agentId);
  }
  
  /// 선호하는 에이전트 ID 가져오기
  String? getPreferredAgentId() {
    return getString(StorageKeys.preferredAgentId);
  }
  
  /// 사용자 설정 저장
  Future<bool> saveUserSettings(Map<String, dynamic> settings) async {
    return setJson('user_settings', settings);
  }
  
  /// 사용자 설정 가져오기
  Map<String, dynamic> getUserSettings() {
    return getJson('user_settings') ?? {};
  }
}
