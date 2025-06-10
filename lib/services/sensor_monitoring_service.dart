// lib/services/sensor_monitoring_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/sensor_data_model.dart';
import '../models/message_model.dart';
import '../utils/logger.dart';
import 'voice_assistant_service.dart';
import 'conversation_service.dart';
import 'auth_service.dart';

// Sensor Monitoring 서비스 Provider
final sensorMonitoringServiceProvider = Provider<SensorMonitoringService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final voiceAssistantService = ref.watch(voiceAssistantServiceProvider);
  final conversationService = ref.watch(conversationServiceProvider);

  return SensorMonitoringService(
    authService,
    voiceAssistantService,
    conversationService,
  );
});

/// 센서 데이터 상태 관리
class SensorState {
  final List<SensorData> sensorDataList;
  final SensorData? latestData;
  final bool isConversationActive;
  final String status;
  final String? error;

  SensorState({
    this.sensorDataList = const [],
    this.latestData,
    this.isConversationActive = false,
    this.status = 'initializing',
    this.error,
  });

  SensorState copyWith({
    List<SensorData>? sensorDataList,
    SensorData? latestData,
    bool? isConversationActive,
    String? status,
    String? error,
  }) {
    return SensorState(
      sensorDataList: sensorDataList ?? this.sensorDataList,
      latestData: latestData ?? this.latestData,
      isConversationActive: isConversationActive ?? this.isConversationActive,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

/// Firebase Realtime Database에서 센서 데이터를 모니터링하고 motion 값에 따라 대화를 제어하는 서비스
class SensorMonitoringService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final AuthService _authService;
  final VoiceAssistantService _voiceAssistantService;
  final ConversationService _conversationService;

  // 구독 관리
  StreamSubscription? _sensorSubscription;
  StreamSubscription? _transcriptionSubscription;
  StreamController<SensorState>? _stateController;

  // 상태 관리
  SensorState _currentState = SensorState();
  String? _currentConversationId;
  int? _previousMotionValue;

  // 대화 타이머 관리
  Timer? _conversationTimer;
  static const Duration _conversationTimeout = Duration(seconds: 30);

  SensorMonitoringService(
      this._authService,
      this._voiceAssistantService,
      this._conversationService,
      );

  /// 센서 데이터 모니터링 시작
  Stream<SensorState> startMonitoring() {
    _stateController = StreamController<SensorState>.broadcast();

    try {
      AppLogger.info('SensorMonitoringService: Starting sensor monitoring...');

      // test 경로 모니터링 (Firebase 구조에 맞춤)
      final sensorRef = _database.ref('test');

      _sensorSubscription = sensorRef.onValue.listen(
            (event) => _handleSensorDataUpdate(event),
        onError: (error) => _handleError(error),
      );

      _updateState(status: 'monitoring', error: null);

    } catch (e, stackTrace) {
      AppLogger.error('SensorMonitoringService: Error starting monitoring: $e', e, stackTrace);
      _updateState(status: 'error', error: e.toString());
    }

    return _stateController!.stream;
  }

  /// 센서 데이터 업데이트 처리
  void _handleSensorDataUpdate(DatabaseEvent event) {
    try {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        // test 경로의 단일 센서 데이터 파싱
        try {
          final sensorData = SensorData.fromJson('test', data);

          AppLogger.info('SensorMonitoringService: Parsed sensor data: $sensorData');
          AppLogger.info('SensorMonitoringService: Current motion value: ${sensorData.motion}');

          // motion 값 변화 감지 및 대화 제어
          _handleMotionChange(sensorData);

          // 상태 업데이트
          _updateState(
            sensorDataList: [sensorData], // 단일 데이터를 리스트로 감싸기
            latestData: sensorData,
            status: 'monitoring',
          );

        } catch (e) {
          AppLogger.warning('SensorMonitoringService: Error parsing sensor data: $e');
          _updateState(status: 'parsing_error', error: e.toString());
        }

      } else {
        AppLogger.warning('SensorMonitoringService: No sensor data found');
        _updateState(
          sensorDataList: [],
          latestData: null,
          status: 'no_data',
        );
      }

    } catch (e, stackTrace) {
      AppLogger.error('SensorMonitoringService: Error handling sensor data update: $e', e, stackTrace);
      _updateState(status: 'error', error: e.toString());
    }
  }

  /// Motion 값 변화에 따른 대화 제어
  void _handleMotionChange(SensorData? latestData) {
    if (latestData == null) return;

    final currentMotion = latestData.motion;

    // motion 값이 변경되었는지 확인
    if (_previousMotionValue != currentMotion) {
      AppLogger.info('SensorMonitoringService: Motion value changed: $_previousMotionValue → $currentMotion');

      _previousMotionValue = currentMotion;

      // motion이 1이고 대화가 비활성 상태이면 대화 시작
      if (currentMotion == 1 && !_currentState.isConversationActive) {
        _startConversation(latestData);
      }
      // motion 값이 변경되어도 대화는 30초 무음성으로만 종료됨
    }
  }

  /// 대화 시작
  Future<void> _startConversation(SensorData triggerData) async {
    try {
      AppLogger.info('SensorMonitoringService: Starting conversation triggered by motion=1');

      // 사용자 확인
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다');
      }

      // 새 대화 생성
      final conversation = await _conversationService.createConversation(
        plantId: null, // plant_id는 null로 설정
      );

      _currentConversationId = conversation.id;

      // 음성 비서 초기화
      await _voiceAssistantService.startConversation(_currentConversationId!);

      // 상태 업데이트
      _updateState(isConversationActive: true, status: 'conversation_active');

      // 초기 인사말
      final greeting = "안녕하세요! 움직임이 감지되어 대화를 시작합니다. "
          "현재 습도는 ${triggerData.humidity}%입니다. 무엇을 도와드릴까요?";

      // AI 인사말 음성 재생
      await _voiceAssistantService.speak(greeting, 'default');

      // 대화 저장
      await _conversationService.addMessage(
        conversationId: _currentConversationId!,
        content: greeting,
        sender: MessageSender.agent,
      );

      // 실시간 음성 대화 시작
      _startVoiceConversation();

      // 30초 무음성 타이머 시작
      _startConversationTimer();

      AppLogger.info('SensorMonitoringService: Conversation started successfully');

    } catch (e, stackTrace) {
      AppLogger.error('SensorMonitoringService: Error starting conversation: $e', e, stackTrace);
      _updateState(status: 'conversation_error', error: e.toString());
    }
  }

  /// 실시간 음성 대화 처리
  void _startVoiceConversation() {
    // 여기서는 실제 음성 대화 로직을 구현
    // 기존 voice_assistant_service의 기능을 활용
    AppLogger.info('SensorMonitoringService: Voice conversation started');

    // 음성 인식 스트림을 구독하여 음성 입력 감지 시 타이머 리셋
    _startVoiceActivityMonitoring();
  }

  /// 음성 활동 모니터링 시작
  void _startVoiceActivityMonitoring() {
    try {
      AppLogger.debug('SensorMonitoringService: Starting voice activity monitoring...');

      // 음성 인식 시작
      final transcriptionStream = _voiceAssistantService.startListening();

      // 음성 인식 결과 구독
      _transcriptionSubscription = transcriptionStream.listen(
            (transcriptionResult) {
          _handleVoiceTranscription(transcriptionResult);
        },
        onError: (error) {
          AppLogger.error('SensorMonitoringService: Voice transcription error: $error');
        },
        onDone: () {
          AppLogger.debug('SensorMonitoringService: Voice transcription stream closed');
        },
      );

    } catch (e, stackTrace) {
      AppLogger.error('SensorMonitoringService: Error starting voice activity monitoring: $e', e, stackTrace);
    }
  }

  /// 음성 인식 결과 처리
  void _handleVoiceTranscription(String transcriptionResult) {
    // 에러 메시지는 무시
    if (transcriptionResult.startsWith('[error]')) {
      AppLogger.warning('SensorMonitoringService: Voice transcription error: $transcriptionResult');
      return;
    }

    // 인식 중지 메시지는 무시
    if (transcriptionResult.startsWith('[listening_stopped]')) {
      AppLogger.debug('SensorMonitoringService: Voice listening stopped');
      return;
    }

    // 중간 결과도 음성 활동으로 간주하여 타이머 리셋
    if (transcriptionResult.startsWith('[interim]')) {
      AppLogger.debug('SensorMonitoringService: Interim voice result detected - resetting timer');
      _resetConversationTimer();
      return;
    }

    // 실제 음성 입력이 감지된 경우
    if (transcriptionResult.isNotEmpty && !transcriptionResult.startsWith('[')) {
      AppLogger.info('SensorMonitoringService: Voice input detected: "$transcriptionResult" - resetting timer');
      _resetConversationTimer();

      // 사용자 메시지 처리
      _processUserVoiceInput(transcriptionResult);
    }
  }

  /// 사용자 음성 입력 처리
  Future<void> _processUserVoiceInput(String userInput) async {
    try {
      AppLogger.info('SensorMonitoringService: Processing user voice input: "$userInput"');

      // 대화 종료 키워드 체크
      if (_isExitCommand(userInput)) {
        await _endConversation(reason: '사용자 요청');
        return;
      }

      // AI 응답 생성 및 처리
      await _processAIResponse(userInput);

    } catch (e, stackTrace) {
      AppLogger.error('SensorMonitoringService: Error processing user voice input: $e', e, stackTrace);
    }
  }

  /// AI 응답 처리
  Future<void> _processAIResponse(String userMessage) async {
    try {
      AppLogger.debug('SensorMonitoringService: Processing AI response for: "$userMessage"');

      // AI 응답 생성
      final responseStream = _voiceAssistantService.processVoiceInput(
        userMessage,
        'default', // 기본 음성 ID
      );

      await for (final responseData in responseStream) {
        if (responseData['status'] == 'completed') {
          final response = responseData['response'];
          final aiText = response['text'];

          AppLogger.info('SensorMonitoringService: AI responded: "$aiText"');

          // 대화를 Firestore에 저장
          await _saveConversationMessages(userMessage, aiText);

          // 다음 음성 입력을 위해 다시 음성 인식 시작
          _startVoiceActivityMonitoring();
          break;
        } else if (responseData['status'] == 'error') {
          throw Exception(responseData['message']);
        }
      }

    } catch (e, stackTrace) {
      AppLogger.error('SensorMonitoringService: Error processing AI response: $e', e, stackTrace);
    }
  }

  /// 대화 종료
  Future<void> _endConversation({String reason = '음성 감지 시간 초과'}) async {
    try {
      AppLogger.info('SensorMonitoringService: Ending conversation - Reason: $reason');

      if (_currentState.isConversationActive) {
        // 대화 타이머 중지
        _stopConversationTimer();

        // 음성 인식 중지
        await _transcriptionSubscription?.cancel();
        _transcriptionSubscription = null;

        // 종료 메시지
        final farewellMessage = reason == '음성 감지 시간 초과'
            ? "30초간 음성이 감지되지 않아 대화를 종료합니다. 좋은 하루 되세요!"
            : "대화를 종료합니다. 좋은 하루 되세요!";

        // 종료 메시지 음성 재생
        await _voiceAssistantService.speak(farewellMessage, 'default');

        // 대화 저장
        if (_currentConversationId != null) {
          await _conversationService.addMessage(
            conversationId: _currentConversationId!,
            content: farewellMessage,
            sender: MessageSender.agent,
          );
        }

        // 음성 비서 정리
        await _voiceAssistantService.endConversation();

        // 상태 업데이트
        _updateState(isConversationActive: false, status: 'monitoring');

        _currentConversationId = null;

        AppLogger.info('SensorMonitoringService: Conversation ended successfully');
      }

    } catch (e, stackTrace) {
      AppLogger.error('SensorMonitoringService: Error ending conversation: $e', e, stackTrace);
      _updateState(status: 'conversation_error', error: e.toString());
    }
  }

  /// 수동 대화 종료
  Future<void> forceEndConversation() async {
    if (_currentState.isConversationActive) {
      await _endConversation(reason: '수동 종료');
      AppLogger.info('SensorMonitoringService: Conversation manually ended');
    }
  }

  /// 30초 무음성 타이머 시작
  void _startConversationTimer() {
    _stopConversationTimer(); // 기존 타이머 중지

    _conversationTimer = Timer(_conversationTimeout, () {
      AppLogger.info('SensorMonitoringService: Conversation timeout (30s) - ending conversation');
      _endConversation(reason: '음성 감지 시간 초과');
    });

    AppLogger.debug('SensorMonitoringService: Conversation timer started (30s)');
  }

  /// 대화 타이머 중지
  void _stopConversationTimer() {
    _conversationTimer?.cancel();
    _conversationTimer = null;
    AppLogger.debug('SensorMonitoringService: Conversation timer stopped');
  }

  /// 대화 타이머 리셋 (음성 입력 감지 시)
  void _resetConversationTimer() {
    if (_currentState.isConversationActive) {
      AppLogger.debug('SensorMonitoringService: Resetting conversation timer due to voice activity');
      _startConversationTimer(); // 타이머 재시작
    }
  }

  /// 음성 입력 감지 시 호출 (외부에서 사용)
  void onVoiceActivityDetected() {
    _resetConversationTimer();
  }

  /// 상태 업데이트
  void _updateState({
    List<SensorData>? sensorDataList,
    SensorData? latestData,
    bool? isConversationActive,
    String? status,
    String? error,
  }) {
    _currentState = _currentState.copyWith(
      sensorDataList: sensorDataList,
      latestData: latestData,
      isConversationActive: isConversationActive,
      status: status,
      error: error,
    );

    _stateController?.add(_currentState);
  }

  /// 에러 처리
  void _handleError(dynamic error) {
    AppLogger.error('SensorMonitoringService: Database error: $error');
    _updateState(status: 'database_error', error: error.toString());
  }

  /// 현재 상태 반환
  SensorState get currentState => _currentState;

  /// 모니터링 중지
  void stopMonitoring() {
    AppLogger.info('SensorMonitoringService: Stopping sensor monitoring...');

    _sensorSubscription?.cancel();
    _sensorSubscription = null;

    // 대화 타이머 중지
    _stopConversationTimer();

    // 음성 인식 구독 중지
    _transcriptionSubscription?.cancel();
    _transcriptionSubscription = null;

    if (_currentState.isConversationActive) {
      forceEndConversation();
    }

    _stateController?.close();
    _stateController = null;

    _currentState = SensorState(status: 'stopped');
  }

  /// 대화 종료 키워드 체크
  bool _isExitCommand(String message) {
    final lowerMessage = message.toLowerCase().trim();
    final exitKeywords = [
      '종료',
      '끝',
      '대화 끝',
      '그만',
      '안녕',
      '다음에',
      '수고',
      '고마워',
      '바이',
      'bye',
      'exit',
      'quit',
      'stop',
      '좀 그만',
      '이만 끝',
      '이만 종료',
    ];

    return exitKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// 대화 내용을 Firestore에 저장
  Future<void> _saveConversationMessages(String userMessage, String aiMessage) async {
    try {
      if (_currentConversationId == null) return;

      // 사용자 메시지 저장
      await _conversationService.addMessage(
        conversationId: _currentConversationId!,
        content: userMessage,
        sender: MessageSender.user,
      );

      // AI 메시지 저장
      await _conversationService.addMessage(
        conversationId: _currentConversationId!,
        content: aiMessage,
        sender: MessageSender.agent,
      );

      AppLogger.debug('SensorMonitoringService: Messages saved to Firestore');

    } catch (e, stackTrace) {
      AppLogger.error('SensorMonitoringService: Error saving messages: $e', e, stackTrace);
    }
  }

  /// 리소스 정리
  void dispose() {
    stopMonitoring();
    _transcriptionSubscription?.cancel();
    _transcriptionSubscription = null;
    AppLogger.info('SensorMonitoringService: Disposed');
  }
}
