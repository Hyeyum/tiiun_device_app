import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 앱 로깅 유틸리티
/// 
/// 앱 전체에서 일관된 로깅을 위한 클래스입니다.
/// 개발 중에는 상세한 로그를 출력하고, 프로덕션 환경에서는 중요한 로그만 출력합니다.
class AppLogger {
  // 싱글톤 구현
  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;
  
  // 로거 인스턴스
  late Logger _logger;
  
  // 현재 로그 레벨
  static Level _currentLevel = kDebugMode ? Level.debug : Level.info;
  
  // 로그 출력 활성화 여부
  static bool _enabled = true;
  
  // 비공개 생성자
  AppLogger._() {
    // 로거 설정
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: _currentLevel,
    );
  }
  
  // 로그 레벨 설정
  static void setLevel(Level level) {
    _currentLevel = level;
    _instance._logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: level,
    );
  }
  
  // 로그 출력 활성화/비활성화
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  
  // 디버그 로그
  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _instance._logger.d(message, error: error, stackTrace: stackTrace);
  }
  
  // 정보 로그
  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _instance._logger.i(message, error: error, stackTrace: stackTrace);
  }
  
  // 경고 로그
  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _instance._logger.w(message, error: error, stackTrace: stackTrace);
  }
  
  // 오류 로그
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _instance._logger.e(message, error: error, stackTrace: stackTrace);
  }
  
  // 심각한 오류 로그
  static void severe(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    _instance._logger.wtf(message, error: error, stackTrace: stackTrace);
  }
  
  // 로그 그룹 시작
  static void group(String name) {
    if (!_enabled) return;
    info('┌── $name ───────────────────────────────────');
  }
  
  // 로그 그룹 종료
  static void groupEnd() {
    if (!_enabled) return;
    info('└────────────────────────────────────────────');
  }
  
  // 메서드 호출 로깅
  static void logMethod(String className, String methodName, [Map<String, dynamic>? params]) {
    if (!_enabled) return;
    if (params != null) {
      debug('$className.$methodName(${params.entries.map((e) => '${e.key}: ${e.value}').join(', ')})');
    } else {
      debug('$className.$methodName()');
    }
  }
  
  // API 호출 로깅
  static void logApiCall(String method, String url, {Map<String, dynamic>? headers, dynamic body, int? statusCode, dynamic response}) {
    if (!_enabled) return;
    
    group('API Call');
    
    info('$method $url');
    
    if (headers != null) {
      debug('Headers: $headers');
    }
    
    if (body != null) {
      debug('Request: $body');
    }
    
    if (statusCode != null) {
      if (statusCode >= 200 && statusCode < 300) {
        info('Status: $statusCode');
      } else {
        warning('Status: $statusCode');
      }
    }
    
    if (response != null) {
      debug('Response: $response');
    }
    
    groupEnd();
  }
  
  // 오류 및 예외 로깅
  static void logException(String source, dynamic exception, [StackTrace? stackTrace]) {
    if (!_enabled) return;
    error('Exception in $source: $exception', exception, stackTrace);
  }
  
  // 성능 측정 로깅
  static Stopwatch startPerformanceLogging(String operation) {
    final stopwatch = Stopwatch()..start();
    if (_enabled) {
      debug('Starting $operation');
    }
    return stopwatch;
  }
  
  static void endPerformanceLogging(Stopwatch stopwatch, String operation) {
    stopwatch.stop();
    if (_enabled) {
      info('$operation completed in ${stopwatch.elapsedMilliseconds}ms');
    }
  }
}
