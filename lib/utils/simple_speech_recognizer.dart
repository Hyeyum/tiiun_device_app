import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 간소화된 음성 인식 처리 클래스
class SimpleSpeechRecognizer {
  final StreamController<String> _transcriptionController = StreamController<String>.broadcast();
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isInitializing = false;
  final List<String> _supportedLocales = [];
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  // 초기화 재시도 카운터 및 설정
  int _initRetryCount = 0;
  static const int _maxInitRetries = 3;
  
  /// 음성 인식 초기화
  Future<bool> initialize() async {
    // 이미 초기화 중이면 완료될 때까지 대기
    if (_isInitializing) {
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isInitialized) return true;
      }
      return false;
    }
    
    // 이미 초기화되었다면 바로 결과 반환
    if (_isInitialized) return true;
    
    _isInitializing = true;
    
    try {
      debugPrint('STT 서비스 초기화 시작');
      // 디버그 로깅 활성화 및 초기화
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('STT 서비스 초기화 오류: ${error.errorMsg}');
          _handleError(error.errorMsg);
        },
        onStatus: (status) {
          debugPrint('STT 서비스 상태: $status');
          _handleStatusChange(status);
        },
        debugLogging: true,
      );
      
      if (_isInitialized) {
        debugPrint('STT 서비스 초기화 성공');
        _initRetryCount = 0;
        // 지원 언어 목록 로드
        await _loadSupportedLocales();
      } else {
        debugPrint('STT 서비스 초기화 실패');
        // 초기화 재시도 로직
        if (_initRetryCount < _maxInitRetries) {
          _initRetryCount++;
          _isInitializing = false;
          debugPrint('STT 서비스 초기화 재시도 ($_initRetryCount/$_maxInitRetries)');
          await Future.delayed(const Duration(seconds: 1));
          return initialize();
        }
      }
      
      _isInitializing = false;
      return _isInitialized;
    } on PlatformException catch (e) {
      debugPrint('STT 서비스 초기화 PlatformException: ${e.message}');
      _handleError("음성 인식 초기화 실패: ${e.message}");
      _isInitializing = false;
      return false;
    } catch (e) {
      debugPrint('STT 서비스 초기화 예외: $e');
      _handleError("음성 인식 초기화 중 예상치 못한 오류: $e");
      _isInitializing = false;
      return false;
    }
  }
  
  /// 지원되는 언어 목록 로드
  Future<void> _loadSupportedLocales() async {
    try {
      final locales = await _speech.locales();
      _supportedLocales.clear();
      for (var locale in locales) {
        _supportedLocales.add(locale.localeId);
      }
      debugPrint('지원되는 언어: $_supportedLocales');
    } catch (e) {
      debugPrint('언어 목록 로드 오류: $e');
    }
  }
  
  /// 음성 인식 시작 - 간소화 및 개선된 버전
  Future<bool> startListening() async {
    // 이미 리스닝 중이면 true 반환
    if (_isListening) {
      debugPrint('이미 음성 인식 중입니다');
      return true;
    }
    
    // 초기화 확인
    if (!_isInitialized) {
      debugPrint('음성 인식이 초기화되지 않았습니다. 초기화를 시도합니다.');
      final initialized = await initialize();
      if (!initialized) {
        _handleError("음성 인식을 초기화할 수 없습니다");
        return false;
      }
    }
    
    try {
      // 가장 적합한 언어 선택
      String localeId = _getPreferredLocale();
      debugPrint('선택된 언어: $localeId');
      
      // 더 간단한 설정으로 시작 - dictation 모드 사용
      debugPrint('음성 인식 시작 시도...');
      _isListening = await _speech.listen(
        onResult: _handleRecognitionResult,
        localeId: localeId,
        listenMode: stt.ListenMode.dictation, // dictation 모드 사용
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 60), // 인식 시간 증가
        pauseFor: const Duration(seconds: 10), // 일시 중지 시간 증가
      );
      
      if (_isListening) {
        debugPrint('음성 인식 시작 성공');
        _transcriptionController.add('[interim]음성을 인식하는 중입니다...');
        
        // 60초 후 자동 종료 타이머 설정
        Future.delayed(const Duration(seconds: 60), () {
          if (_isListening) {
            debugPrint('60초 제한 시간 도달. 음성 인식 중지.');
            stopListening();
          }
        });
      } else {
        debugPrint('음성 인식 시작 실패');
        _handleError("음성 인식을 시작할 수 없습니다");
      }
      
      return _isListening;
    } on PlatformException catch (e) {
      debugPrint('음성 인식 시작 PlatformException: ${e.message}');
      _handleError("음성 인식 시작 실패: ${e.message}");
      _isListening = false;
      return false;
    } catch (e) {
      debugPrint('음성 인식 시작 예외: $e');
      _handleError("음성 인식 시작 중 예상치 못한 오류: $e");
      _isListening = false;
      return false;
    }
  }
  
  /// 선호하는 로케일 선택
  String _getPreferredLocale() {
    // 한국어 지원 확인
    if (_supportedLocales.contains('ko_KR')) {
      return 'ko_KR';
    }
    if (_supportedLocales.any((locale) => locale.startsWith('ko'))) {
      return _supportedLocales.firstWhere((locale) => locale.startsWith('ko'));
    }
    
    // 영어 지원 확인
    if (_supportedLocales.contains('en_US')) {
      return 'en_US';
    }
    if (_supportedLocales.any((locale) => locale.startsWith('en'))) {
      return _supportedLocales.firstWhere((locale) => locale.startsWith('en'));
    }
    
    // 지원되는 첫 번째 언어 반환 (비어있으면 기본값 반환)
    return _supportedLocales.isNotEmpty ? _supportedLocales.first : 'ko_KR';
  }
  
  /// 음성 인식 결과 처리
  void _handleRecognitionResult(SpeechRecognitionResult result) {
    debugPrint('인식 결과: 단어=${result.recognizedWords}, 신뢰도=${result.confidence}, 최종=${result.finalResult}');
    
    if (_isListening) {
      // 중간 결과
      if (!result.finalResult) {
        if (result.recognizedWords.isNotEmpty) {
          _transcriptionController.add('[interim]${result.recognizedWords}');
        }
      } else {
        // 최종 결과
        final text = result.recognizedWords;
        if (text.isNotEmpty) {
          _transcriptionController.add(text);
          debugPrint('최종 인식 결과: $text, 신뢰도: ${result.confidence}');
        } else {
          _handleError("인식된 텍스트가 없습니다");
        }
        
        // 최종 결과 후 인식 종료
        _isListening = false;
        _transcriptionController.add('[listening_stopped]');
      }
    }
  }
  
  /// 상태 변경 처리
  void _handleStatusChange(String status) {
    // 주요 상태만 로깅
    if (status == 'done' || status == 'notListening' || status == 'error') {
      debugPrint('음성 인식 상태: $status');
    }
    
    // 특정 상태에 대한 처리
    switch (status) {
      case 'done':
      case 'notListening':
        if (_isListening) {
          _isListening = false;
          _transcriptionController.add('[listening_stopped]');
        }
        break;
        
      case 'doneNoResult':
        if (_isListening) {
          _isListening = false;
          _handleError("인식 결과가 없습니다");
          _transcriptionController.add('[listening_stopped]');
        }
        break;
        
      case 'error':
        if (_isListening) {
          _isListening = false;
          _handleError("음성 인식 중 오류가 발생했습니다");
          _transcriptionController.add('[listening_stopped]');
        }
        break;
    }
  }
  
  /// 에러 처리
  void _handleError(String errorMessage) {
    debugPrint('음성 인식 오류: $errorMessage');
    
    // 특정 에러 메시지에 대한 사용자 친화적 메시지
    String userFriendlyError;
    
    if (errorMessage.contains('error_speech_timeout')) {
      userFriendlyError = '음성 인식 시간이 초과되었습니다. 다시 시도해주세요.';
    } else if (errorMessage.contains('error_no_match')) {
      userFriendlyError = '목소리를 인식하지 못했습니다. 더 크고 천천히 말씀해주세요.';
    } else if (errorMessage.contains('error_network')) {
      userFriendlyError = '네트워크 연결이 필요합니다. 인터넷 연결을 확인해주세요.';
    } else if (errorMessage.contains('error_not_recognized')) {
      userFriendlyError = '음성을 인식하지 못했습니다. 다시 시도해주세요.';
    } else if (errorMessage.contains('error_busy')) {
      userFriendlyError = '음성 인식 서비스가 현재 사용 중입니다. 잠시 후 다시 시도해주세요.';
    } else if (errorMessage.contains('error_permission')) {
      userFriendlyError = '마이크 사용 권한이 필요합니다. 설정에서 권한을 확인해주세요.';
    } else if (errorMessage.contains('Unknown calling package')) {
      userFriendlyError = 'Google 음성 인식 서비스 연결에 문제가 있습니다. 앱 권한을 확인해주세요.';
    } else {
      userFriendlyError = '음성 인식 중 오류가 발생했습니다. 다시 시도해주세요.';
    }
    
    _transcriptionController.add('[error]$userFriendlyError');
    
    if (_isListening) {
      _isListening = false;
      _transcriptionController.add('[listening_stopped]');
    }
  }
  
  /// 음성 인식 중지
  Future<void> stopListening() async {
    if (!_isListening) {
      debugPrint('이미 인식이 중지되어 있습니다');
      return;
    }
    
    try {
      debugPrint('음성 인식 중지 시도');
      await _speech.stop();
      _isListening = false;
      _transcriptionController.add('[listening_stopped]');
      debugPrint('음성 인식 중지 성공');
    } catch (e) {
      debugPrint('음성 인식 중지 오류: $e');
      _handleError("음성 인식 중지 중 오류: $e");
      _isListening = false;
    }
  }
  
  /// 현재 인식 중인지 확인
  bool get isListening => _isListening;
  
  /// 초기화 되었는지 확인
  bool get isInitialized => _isInitialized;
  
  /// 초기화 중인지 확인
  bool get isInitializing => _isInitializing;
  
  /// 한국어 지원 여부 확인 - 메서드 추가
  Future<bool> isKoreanSupported() async {
    // 초기화되지 않았다면 초기화
    if (!_isInitialized && !_isInitializing) {
      await initialize();
    }
    
    // 아직 초기화 중이면 결과 기다림
    while (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (_supportedLocales.isEmpty) {
      await _loadSupportedLocales();
    }
    
    // 한국어 지원 확인
    return _supportedLocales.any((locale) => locale.startsWith('ko'));
  }
  
  /// 리소스 해제
  Future<void> dispose() async {
    await stopListening();
    await _transcriptionController.close();
  }
}
