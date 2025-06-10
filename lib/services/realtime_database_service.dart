// lib/services/realtime_database_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../models/message_model.dart';
import 'auth_service.dart';
import 'voice_assistant_service.dart';
import 'conversation_service.dart';

// Realtime Database 서비스 Provider
final realtimeDbServiceProvider = Provider<RealtimeDbService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final voiceAssistantService = ref.watch(voiceAssistantServiceProvider);
  final conversationService = ref.watch(conversationServiceProvider);

  return RealtimeDbService(
    authService,
    voiceAssistantService,
    conversationService,
  );
});

/// Firebase Realtime Database 트리거 기반 실시간 대화 서비스
///
/// 특정 값이 변경되면 자동으로 대화를 시작하고 음성 대화를 진행합니다.
class RealtimeDbService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final AuthService _authService;
  final VoiceAssistantService _voiceAssistantService;
  final ConversationService _conversationService;

  // 구독 관리
  StreamSubscription? _triggerSubscription;
  StreamSubscription? _transcriptionSubscription;
  StreamSubscription? _responseSubscription;

  // 대화 상태
  bool _isConversationActive = false;
  String? _currentConversationId;

  RealtimeDbService(
      this._authService,
      this._voiceAssistantService,
      this._conversationService,
      );

  /// 특정 경로의 값 변경을 감지하여 대화 트리거
  ///
  /// [triggerPath] - 감지할 Firebase Realtime Database 경로
  /// [triggerValue] - 대화를 시작할 특정 값
  /// [resetValue] - 트리거 후 초기화할 값 (선택사항)
  Stream<Map<String, dynamic>> listenForTrigger({
    required String triggerPath,
    required String triggerValue,
    String? resetValue,
  }) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    try {
      final ref = _database.ref(triggerPath);

      _triggerSubscription = ref.onValue.listen((event) async {
        try {
          final value = event.snapshot.value?.toString();

          AppLogger.info('RealtimeDbService: Value changed - Path: $triggerPath, Value: $value');

          if (value == triggerValue && !_isConversationActive) {
            AppLogger.info('RealtimeDbService: Trigger detected! Starting conversation...');

            controller.add({
              'status': 'trigger_detected',
              'path': triggerPath,
              'value': value,
              'timestamp': DateTime.now().toIso8601String(),
            });

            // 대화 시작
            await _startTriggeredConversation(controller);

            // 트리거 값 초기화 (선택사항)
            if (resetValue != null) {
              await ref.set(resetValue);
              AppLogger.debug('RealtimeDbService: Trigger value reset to: $resetValue');
            }
          } else {
            controller.add({
              'status': 'value_changed',
              'path': triggerPath,
              'value': value,
              'conversation_active': _isConversationActive,
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        } catch (e, stackTrace) {
          AppLogger.error('RealtimeDbService: Error processing trigger: $e', e, stackTrace);
          controller.add({
            'status': 'error',
            'message': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      });

    } catch (e, stackTrace) {
      AppLogger.error('RealtimeDbService: Error setting up trigger listener: $e', e, stackTrace);
      controller.add({
        'status': 'setup_error',
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    return controller.stream;
  }

  /// 트리거로 시작된 대화 처리
  Future<void> _startTriggeredConversation(StreamController<Map<String, dynamic>> controller) async {
    try {
      _isConversationActive = true;

      // 새 대화 생성
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다');
      }

      final conversation = await _conversationService.createConversation(
        title: '실시간 트리거 대화',
        agentId: 'trigger_agent',
      );

      _currentConversationId = conversation.id;

      controller.add({
        'status': 'conversation_started',
        'conversation_id': _currentConversationId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 음성 비서 초기화
      await _voiceAssistantService.startConversation(_currentConversationId!);

      // 초기 인사말
      final greeting = "안녕하세요! 트리거가 감지되어 대화를 시작합니다. 무엇을 도와드릴까요?";

      controller.add({
        'status': 'ai_greeting',
        'message': greeting,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // AI 인사말 음성 재생
      await _voiceAssistantService.speak(greeting, 'default');

      // 실시간 음성 대화 시작
      await _startRealTimeVoiceConversation(controller);

    } catch (e, stackTrace) {
      AppLogger.error('RealtimeDbService: Error starting triggered conversation: $e', e, stackTrace);
      _isConversationActive = false;
      controller.add({
        'status': 'conversation_error',
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// 실시간 음성 대화 처리
  Future<void> _startRealTimeVoiceConversation(StreamController<Map<String, dynamic>> controller) async {
    try {
      AppLogger.info('RealtimeDbService: Starting real-time voice conversation...');

      // 지속적인 음성 인식 루프
      while (_isConversationActive) {
        await _processSingleVoiceInteraction(controller);

        // 잠시 대기 (연속 인식 방지)
        await Future.delayed(const Duration(milliseconds: 500));
      }

    } catch (e, stackTrace) {
      AppLogger.error('RealtimeDbService: Error in real-time voice conversation: $e', e, stackTrace);
      controller.add({
        'status': 'voice_conversation_error',
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// 단일 음성 상호작용 처리
  Future<void> _processSingleVoiceInteraction(StreamController<Map<String, dynamic>> controller) async {
    try {
      controller.add({
        'status': 'listening_started',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 음성 인식 시작
      final transcriptionStream = _voiceAssistantService.startListening();

      await for (final transcriptionResult in transcriptionStream) {
        controller.add({
          'status': 'transcription_update',
          'result': transcriptionResult,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // 에러 처리
        if (transcriptionResult.startsWith('[error]')) {
          AppLogger.warning('RealtimeDbService: Transcription error: $transcriptionResult');
          continue;
        }

        // 인식 완료 처리
        if (transcriptionResult.startsWith('[listening_stopped]')) {
          break;
        }

        // 중간 결과는 무시
        if (transcriptionResult.startsWith('[interim]')) {
          continue;
        }

        // 최종 음성 인식 결과
        if (transcriptionResult.isNotEmpty && !transcriptionResult.startsWith('[')) {
          AppLogger.info('RealtimeDbService: User said: $transcriptionResult');

          controller.add({
            'status': 'user_message',
            'message': transcriptionResult,
            'timestamp': DateTime.now().toIso8601String(),
          });

          // 대화 종료 키워드 체크
          if (_isExitCommand(transcriptionResult)) {
            await _endConversation(controller);
            return;
          }

          // AI 응답 생성
          await _processAIResponse(transcriptionResult, controller);
          break;
        }
      }

    } catch (e, stackTrace) {
      AppLogger.error('RealtimeDbService: Error in voice interaction: $e', e, stackTrace);
      controller.add({
        'status': 'interaction_error',
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// AI 응답 처리
  Future<void> _processAIResponse(String userMessage, StreamController<Map<String, dynamic>> controller) async {
    try {
      controller.add({
        'status': 'ai_processing',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // AI 응답 생성
      final responseStream = _voiceAssistantService.processVoiceInput(
        userMessage,
        'default', // 기본 음성 ID
      );

      await for (final responseData in responseStream) {
        controller.add({
          'status': 'ai_response_update',
          'data': responseData,
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (responseData['status'] == 'completed') {
          final response = responseData['response'];
          final aiText = response['text'];

          AppLogger.info('RealtimeDbService: AI responded: $aiText');

          controller.add({
            'status': 'ai_message',
            'message': aiText,
            'timestamp': DateTime.now().toIso8601String(),
          });

          // 대화를 Firestore에 저장
          await _saveConversationMessages(userMessage, aiText);
          break;
        } else if (responseData['status'] == 'error') {
          throw Exception(responseData['message']);
        }
      }

    } catch (e, stackTrace) {
      AppLogger.error('RealtimeDbService: Error processing AI response: $e', e, stackTrace);
      controller.add({
        'status': 'ai_response_error',
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
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

      AppLogger.debug('RealtimeDbService: Messages saved to Firestore');

    } catch (e, stackTrace) {
      AppLogger.error('RealtimeDbService: Error saving messages: $e', e, stackTrace);
    }
  }

  /// 대화 종료 키워드 체크
  bool _isExitCommand(String message) {
    final lowerMessage = message.toLowerCase();
    final exitKeywords = [
      '종료',
      '끝',
      '대화 끝',
      '그만',
      '안녕',
      '바이',
      'bye',
      'exit',
      'quit',
      'stop',
    ];

    return exitKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  /// 대화 종료
  Future<void> _endConversation(StreamController<Map<String, dynamic>> controller) async {
    try {
      AppLogger.info('RealtimeDbService: Ending conversation...');

      _isConversationActive = false;

      // 종료 메시지
      const farewellMessage = "대화를 종료합니다. 좋은 하루 되세요!";

      controller.add({
        'status': 'conversation_ending',
        'message': farewellMessage,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 종료 메시지 음성 재생
      await _voiceAssistantService.speak(farewellMessage, 'default');

      // 음성 비서 정리
      await _voiceAssistantService.endConversation();

      controller.add({
        'status': 'conversation_ended',
        'conversation_id': _currentConversationId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _currentConversationId = null;

    } catch (e, stackTrace) {
      AppLogger.error('RealtimeDbService: Error ending conversation: $e', e, stackTrace);
      controller.add({
        'status': 'end_conversation_error',
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// 수동으로 대화 종료
  Future<void> endConversation() async {
    if (_isConversationActive) {
      _isConversationActive = false;
      await _voiceAssistantService.endConversation();
      _currentConversationId = null;
      AppLogger.info('RealtimeDbService: Conversation manually ended');
    }
  }

  /// 현재 대화 상태 확인
  bool get isConversationActive => _isConversationActive;

  /// 현재 대화 ID 확인
  String? get currentConversationId => _currentConversationId;

  /// 리소스 정리
  Future<void> dispose() async {
    AppLogger.info('RealtimeDbService: Disposing resources...');

    await _triggerSubscription?.cancel();
    await _transcriptionSubscription?.cancel();
    await _responseSubscription?.cancel();

    if (_isConversationActive) {
      await endConversation();
    }
  }
}
