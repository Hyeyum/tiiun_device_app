// lib/services/ai_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart' as app_message; // Message 모델 import with prefix
import 'auth_service.dart'; // Ensure this import is present and correct
import 'voice_service.dart';
import 'conversation_service.dart';
import 'langchain_service.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:tiiun/services/remote_config_service.dart'; // Import RemoteConfigService

// AI 응답 클래스
class AIResponse {
  final String text;
  final String? voiceFileUrl;
  final double? voiceDuration;
  final String? voiceId;
  final String? ttsSource; // Added to match LangchainResponse

  AIResponse({
    required this.text,
    this.voiceFileUrl,
    this.voiceDuration,
    this.voiceId,
    this.ttsSource,
  });
}

class AiService {
  final AuthService _authService;
  // final VoiceService _voiceService; // Potentially not needed if LangchainService handles TTS
  final ConversationService _conversationService;
  final LangchainService _langchainService;
  // final Uuid _uuid = const Uuid(); // No longer directly used here

  // API 키 및 엔드포인트 설정 - API key is now managed by LangchainService and VoiceService internally
  // final String _apiEndpoint = 'https://api.openai.com/v1/chat/completions'; // Not used for chat here
  // String? _apiKey; // Removed, LangchainService handles its own API key

  AiService(
    this._authService,
    // this._voiceService, // Removed if LangchainService is the sole voice interaction point for AI responses
    this._conversationService,
    this._langchainService,
  );

  // API 키 설정 - Removed, LangchainService handles its own API key via its constructor now
  // void setApiKey(String apiKey) {
  //   _apiKey = apiKey;
  //   // _langchainService.setApiKey(apiKey); // LangchainService gets key via constructor now
  // }

  // 사용자 메시지에 대한 AI 응답 생성
  // 내부적으로 LangchainService 사용
  Future<AIResponse> getResponse({
    required String conversationId,
    required String userMessage,
  }) async {
    // Check if LangchainService is properly initialized (has API key for LLM)
    // This check might be implicit in how LangchainService handles getResponse
    // For example, LangchainService itself might return a specific error or dummy response if not initialized.
    debugPrint("AiService: Requesting response from LangchainService.");
    try {
      // LangchainService를 사용하여 응답 생성
      // userMessage는 LangchainService로 전달되고, LangchainService 내에서 LLM에 전달되므로 Base64 인코딩/디코딩은 LangchainService의 책임
      final langchainResponse = await _langchainService.getResponse(
        conversationId: conversationId,
        userMessage: userMessage,
      );

      // LangchainResponse를 AIResponse로 변환
      // langchainResponse.text는 이미 디코딩된 상태로 넘어올 것으로 예상
      return AIResponse(
        text: langchainResponse.text,
        voiceFileUrl: langchainResponse.voiceFileUrl,
        voiceDuration: langchainResponse.voiceDuration,
        voiceId: langchainResponse.voiceId,
        ttsSource: langchainResponse.ttsSource, // Pass through ttsSource
      );
    } catch (e) {
      debugPrint('AiService: Error getting response from LangchainService: $e');
      // Provide a fallback or rethrow a more specific AiServiceException
      throw Exception('AI 응답을 생성하는 중 오류가 발생했습니다: $e');
    }
  }

  // 대화 기록 가져오기 - This seems like a duplicate of what LangchainService might do.
  // If LangchainService already fetches history, this might be redundant here.
  // If AiService has other uses for it.
  Future<List<app_message.Message>> _getConversationHistory(String conversationId) async {
    // getConversationMessages는 이미 Message 모델에서 디코딩을 처리
    final messagesStream = _conversationService.getConversationMessages(conversationId);
    final messages = await messagesStream.first;
    if (messages.length > 10) {
      return messages.sublist(messages.length - 10);
    }
    return messages;
  }

  // 메시지를 OpenAI API 형식으로 변환 - This is specific to direct OpenAI chat calls.
  // If AiService is only using LangchainService for chat, this method might not be used.
  // If AiService were to make direct calls to OpenAI chat completions, it would need its own API key and this method.
  Map<String, dynamic> _messageToJson(app_message.Message msg) {
    String role;
    if (msg.sender == app_message.MessageSender.user) {
      role = 'user';
    } else if (msg.sender == app_message.MessageSender.agent) {
      role = 'assistant';
    } else {
      role = 'system';
    }
    // msg.content는 이미 Message 모델에서 디코딩된 상태
    return {
      'content': msg.content,
      'role': role,
    };
  }

  // 감정 분석 - Delegated to LangchainService
  Future<Map<String, dynamic>> analyzeSentiment(String text) async {
    try {
      // text는 이미 디코딩된 상태로 전달
      return await _langchainService.analyzeSentimentWithLangChain(text);
    } catch (e) {
      debugPrint('AiService: Error analyzing sentiment via LangchainService: $e');
      throw Exception('감정 분석 중 오류가 발생했습니다: $e');
    }
  }
}

// Provider for the AI service
// Moved to after class definition
final aiServiceProvider = Provider<AiService>((ref) {
  final authService = ref.watch(authServiceProvider);
  // VoiceService is already managed by its own provider (voiceServiceProvider)
  // final voiceService = ref.watch(voiceServiceProvider);
  final conversationService = ref.watch(conversationServiceProvider);
  final langchainService = ref.watch(langchainServiceProvider);
  final remoteConfigService = ref.watch(remoteConfigServiceProvider); // remoteConfigService 추가
  final openAIapiKey = remoteConfigService.getOpenAIApiKey(); // API Key 가져오기

  // AiService doesn't directly need VoiceService if LangchainService handles TTS calls.
  // If AiService had other direct voice interactions, it would need it.
  // For now, assuming LangchainService is the primary interface for AI responses including voice.
  return AiService(authService, conversationService, langchainService);
});