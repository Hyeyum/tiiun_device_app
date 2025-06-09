import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/simple_speech_recognizer.dart';
import '../utils/logger.dart'; // Import AppLogger

/// 음성 인식(STT) 서비스
/// 음성 메시지 기능을 위한 서비스 클래스
class SpeechToTextService {
  // 싱글톤 패턴 구현
  static final SpeechToTextService _instance = SpeechToTextService._internal();

  factory SpeechToTextService() => _instance;

  SpeechToTextService._internal();

  // 음성 인식기
  final SimpleSpeechRecognizer _recognizer = SimpleSpeechRecognizer();

  // 마지막으로 인식된 텍스트
  String _lastRecognizedText = '';

  // 상태 관련 컨트롤러
  final StreamController<SpeechRecognitionState> _stateController =
      StreamController<SpeechRecognitionState>.broadcast();

  // 상태 스트림
  Stream<SpeechRecognitionState> get stateStream => _stateController.stream;

  // 초기화 여부
  bool get isInitialized => _recognizer.isInitialized;

  // 현재 인식 상태
  bool get isListening => _recognizer.isListening;

  // 초기화 중인지 여부
  bool get isInitializing => _recognizer.isInitializing;

  /// 서비스 초기화
  Future<bool> initialize() async {
    try {
      AppLogger.info('SpeechToTextService: Initializing...');
      final result = await _recognizer.initialize();
      if (result) {
        _setupRecognitionListener();
        AppLogger.info('SpeechToTextService: Initialization successful.');
      } else {
        AppLogger.warning('SpeechToTextService: Initialization failed.');
      }
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('SpeechToTextService: Error during initialization.', e, stackTrace);
      return false;
    }
  }

  /// 음성 인식 시작
  Future<bool> startListening() async {
    try {
      AppLogger.debug('SpeechToTextService: Request to start listening.');

      if (isListening) {
        AppLogger.debug('SpeechToTextService: Already listening. Stopping and restarting.');
        await stopListening();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!isInitialized) {
        final initialized = await initialize();
        if (!initialized) {
          _stateController.add(
            SpeechRecognitionState(
              status: SpeechStatus.error,
              error: '음성 인식을 초기화할 수 없습니다',
            ),
          );
          return false;
        }
      }

      _lastRecognizedText = '';
      _stateController.add(
        SpeechRecognitionState(
          status: SpeechStatus.listening,
          text: '',
          isInterim: true,
        ),
      );

      final result = await _recognizer.startListening();
      AppLogger.debug('SpeechToTextService: Start listening result: $result');
      return result;
    } catch (e, stackTrace) {
      AppLogger.error('SpeechToTextService: Error starting listening.', e, stackTrace);
      _stateController.add(
        SpeechRecognitionState(
          status: SpeechStatus.error,
          error: '음성 인식을 시작할 수 없습니다: ${e.toString()}',
        ),
      );
      return false;
    }
  }

  /// 음성 인식 중지
  Future<String> stopListening() async {
    AppLogger.debug('SpeechToTextService: Stopping listening.');
    await _recognizer.stopListening();
    return _lastRecognizedText;
  }

  /// 음성 인식 리스너 설정
  void _setupRecognitionListener() {
    AppLogger.debug('SpeechToTextService: Setting up recognition listener.');
    _recognizer.transcriptionStream.listen((result) {
      if (result.startsWith('[interim]')) {
        final text = result.substring(9);
        AppLogger.debug('SpeechToTextService: Interim result: $text');
        _stateController.add(
          SpeechRecognitionState(
            status: SpeechStatus.listening,
            text: text,
            isInterim: true,
          ),
        );
      } else if (result.startsWith('[error]')) {
        final error = result.substring(7);
        AppLogger.error('SpeechToTextService: Error received from recognizer: $error');
        _stateController.add(
          SpeechRecognitionState(
            status: SpeechStatus.error,
            error: error,
          ),
        );
      } else if (result == '[listening_stopped]') {
        AppLogger.debug('SpeechToTextService: Listener stopped.');
        _stateController.add(
          SpeechRecognitionState(
            status: SpeechStatus.notListening,
            text: _lastRecognizedText,
          ),
        );
      } else {
        _lastRecognizedText = result;
        AppLogger.info('SpeechToTextService: Final result: $_lastRecognizedText');
        _stateController.add(
          SpeechRecognitionState(
            status: SpeechStatus.result,
            text: result,
            isInterim: false,
          ),
        );
      }
    });
  }

  /// 리소스 해제
  Future<void> dispose() async {
    AppLogger.info('SpeechToTextService: Disposing resources.');
    await _recognizer.dispose();
    await _stateController.close();
  }

  /// 한국어 지원 여부 확인
  Future<bool> isKoreanSupported() async {
    return await _recognizer.isKoreanSupported();
  }

  /// 현재 상태 진단 정보 가져오기
  Map<String, dynamic> getDiagnosticInfo() {
    return {
      'isInitialized': isInitialized,
      'isListening': isListening,
      'isInitializing': isInitializing,
      'lastRecognizedText': _lastRecognizedText,
    };
  }
}

/// 음성 인식 상태 열거형
enum SpeechStatus {
  notListening,   // 인식 중이 아님
  listening,      // 인식 중
  result,         // 결과 받음
  error,          // 오류 발생
}

/// 음성 인식 상태 클래스
class SpeechRecognitionState {
  final SpeechStatus status;
  final String text;
  final String? error;
  final bool isInterim;

  SpeechRecognitionState({
    required this.status,
    this.text = '',
    this.error,
    this.isInterim = false,
  });

  @override
  String toString() {
    return 'SpeechRecognitionState(status: $status, text: $text, error: $error, isInterim: $isInterim)';
  }
}