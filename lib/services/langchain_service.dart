// lib/services/langchain_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'dart:convert';
import '../models/conversation_model.dart' as app_models;
import '../models/message_model.dart' as app_models; // app_models prefix로 변경
import '../services/plant_persona_service.dart'; // 식물 페르소나 서비스 추가
import 'auth_service.dart';
import 'voice_service.dart';
import 'conversation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:tiiun/services/remote_config_service.dart';

// LangChain 서비스 Provider
final langchainServiceProvider = Provider<LangchainService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final voiceService = ref.watch(voiceServiceProvider);
  final conversationService = ref.watch(conversationServiceProvider);
  final remoteConfigService = ref.watch(remoteConfigServiceProvider);
  final openAIapiKey = remoteConfigService.getOpenAIApiKey();
  return LangchainService(authService, voiceService, conversationService, openAIapiKey);
});

class LangchainResponse {
  final String text;
  final String? voiceFileUrl;
  final double? voiceDuration;
  final String? voiceId;
  final String? ttsSource;

  LangchainResponse({
    required this.text,
    this.voiceFileUrl,
    this.voiceDuration,
    this.voiceId,
    this.ttsSource,
  });
}

class LangchainService {
  final AuthService _authService;
  final VoiceService _voiceService;
  final ConversationService _conversationService;
  final String _openAIapiKey; // Store the API key

  ChatOpenAI? _chatModel;

  LangchainService(
    this._authService,
    this._voiceService,
    this._conversationService,
    this._openAIapiKey, // Receive API key
  ) {
    _initializeLangChain();
  }

  // LangChain 초기화
  void _initializeLangChain() {
    if (_openAIapiKey.isNotEmpty) {
      _chatModel = ChatOpenAI(
        apiKey: _openAIapiKey,
        model: 'gpt-4o', // GPT-4o로 업그레이드! 🚀
        temperature: 0.8, // 더 창의적인 응답을 위해 증가
        maxTokens: 2000, // GPT-4o의 향상된 토큰 처리 능력 활용
      );
      debugPrint("LangchainService initialized with GPT-4o (latest OpenAI model).");
    } else {
      debugPrint("LangchainService: OpenAI API key is missing. LLM features will be limited or use dummy responses.");
    }
  }

  // 사용자 메시지에 대한 응답 생성
  Future<LangchainResponse> getResponse({
    required String conversationId,
    required String userMessage,
  }) async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        return _createDefaultResponse('로그인이 필요합니다. 로그인 후 다시 시도해주세요.');
      }

      final messagesHistory = await _getConversationHistory(conversationId);
      final user = await _authService.getUserModel(userId);

      // 사용자가 선택한 음성 ID
      String? selectedVoiceId = user.preferredVoice;
      debugPrint('LangchainService: 사용자 선호 음성 ID - $selectedVoiceId');

      // 🌱 식물 페르소나 처리 (새로 추가!)
      if (selectedVoiceId == 'plant') {
        return await _handlePlantPersona(userMessage, selectedVoiceId);
      }

      // API 키가 설정되지 않았거나 테스트 모드인 경우 (_chatModel 유무로 판단)
      if (_chatModel == null || _openAIapiKey.isEmpty) {
        debugPrint("LangchainService: 채팅 모델 없음 (API 키 없음). 더미 응답 사용.");
        final dummyResponse = _getDummyResponse(userMessage);
        try {
          debugPrint('LangchainService: 더미 응답에 대한 TTS 생성 시도');
          final voiceData = await _voiceService.textToSpeechFile(
            dummyResponse,
            selectedVoiceId
          );

          if (voiceData['url'] == null || (voiceData['url'] as String).isEmpty) {
            debugPrint('LangchainService: TTS URL이 비어있음 - 오류: ${voiceData['error']}');
            return LangchainResponse(
              text: dummyResponse,
              voiceId: selectedVoiceId,
              ttsSource: 'error',
            );
          }

          debugPrint('LangchainService: 더미 응답 TTS 성공 - URL: ${voiceData['url']}, 소스: ${voiceData['source']}');
          return LangchainResponse(
            text: dummyResponse,
            voiceFileUrl: voiceData['url'] as String?,
            voiceDuration: voiceData['duration'] as double?,
            voiceId: selectedVoiceId,
            ttsSource: voiceData['source'] as String?,
          );
        } catch (e) {
          debugPrint('음성 생성 오류 (dummy response): $e');
          return LangchainResponse(
            text: dummyResponse,
            voiceId: selectedVoiceId,
            ttsSource: 'error',
          );
        }
      }

      // LangChain을 사용하여 응답 생성
      String llmResponseText = '';
      try {
        llmResponseText = await _generateResponseWithLangChain(
          messagesHistory,
          userMessage,
          selectedVoiceId,
        );
        debugPrint('LangchainService: LangChain 응답 생성 성공 - 길이: ${llmResponseText.length}');
      } catch (e) {
        debugPrint('LangChain 응답 생성 오류: $e. Falling back to dummy response.');
        llmResponseText = _getDummyResponse(userMessage);
      }

      try {
        // TTS를 사용하여 음성 생성
        debugPrint('LangchainService: 응답 텍스트에 대한 TTS 파일 생성 시도');
        final voiceData = await _voiceService.textToSpeechFile(
          llmResponseText,
          selectedVoiceId
        );

        if (voiceData['url'] == null || (voiceData['url'] as String).isEmpty) {
          debugPrint('LangchainService: TTS URL이 비어있음 - 오류: ${voiceData['error']}');
          return LangchainResponse(
            text: llmResponseText,
            voiceId: selectedVoiceId,
            ttsSource: 'error',
          );
        }

        debugPrint('LangchainService: TTS 파일 생성 성공 - URL: ${voiceData['url']}, 소스: ${voiceData['source']}');
        return LangchainResponse(
          text: llmResponseText,
          voiceFileUrl: voiceData['url'] as String?,
          voiceDuration: voiceData['duration'] as double?,
          voiceId: selectedVoiceId,
          ttsSource: voiceData['source'] as String?,
        );
      } catch (e) {
        debugPrint('LangchainService: 음성 생성 오류 (LLM response): $e');
        return LangchainResponse(
          text: llmResponseText,
          voiceId: selectedVoiceId,
          ttsSource: 'error',
        );
      }
    } catch (e) {
      debugPrint('LangChain getResponse 중 전반적인 오류 발생: $e');
      return _createDefaultResponse('응답을 생성하는 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  // 🌱 식물 페르소나 전용 처리 메소드
  Future<LangchainResponse> _handlePlantPersona(String userMessage, String? voiceId) async {
    try {
      debugPrint('LangchainService: 식물 페르소나 모드 활성화 🌱');
      
      // 1. 사용자 의도 분석
      final intent = PlantPersonaService.analyzeIntent(userMessage);
      debugPrint('LangchainService: 분석된 의도 - $intent');
      
      // 2. 의도별 식물 응답 생성
      final plantResponse = PlantPersonaService.generatePlantResponse(intent);
      debugPrint('LangchainService: 식물 응답 생성 - ${plantResponse.emoji} ${plantResponse.message}');
      
      // 3. 최종 응답 텍스트 구성
      final finalResponse = '${plantResponse.emoji} ${plantResponse.message}';
      
      // 4. TTS 파일 생성
      try {
        final voiceData = await _voiceService.textToSpeechFile(
          finalResponse,
          voiceId ?? 'shimmer' // 식물은 부드러운 shimmer 목소리 기본값
        );
        
        return LangchainResponse(
          text: finalResponse,
          voiceFileUrl: voiceData['url'] as String?,
          voiceDuration: voiceData['duration'] as double?,
          voiceId: voiceId,
          ttsSource: '${voiceData['source']}_plant', // 식물 페르소나 표시
        );
      } catch (e) {
        debugPrint('LangchainService: 식물 응답 TTS 생성 실패 - $e');
        return LangchainResponse(
          text: finalResponse,
          voiceId: voiceId,
          ttsSource: 'plant_error',
        );
      }
    } catch (e) {
      debugPrint('LangchainService: 식물 페르소나 처리 오류 - $e');
      // 오류 시 기본 식물 응답
      return LangchainResponse(
        text: '🌿 잠깐, 바람이 너무 세게 불어서 네 말을 놓쳤어. 다시 한 번 말해줄래?',
        voiceId: voiceId,
        ttsSource: 'plant_fallback',
      );
    }
  }

  LangchainResponse _createDefaultResponse(String text) {
    return LangchainResponse(
      text: text,
      voiceId: 'default',
      ttsSource: 'none',
    );
  }

  Future<String> _generateResponseWithLangChain(
    List<app_models.Message> messageHistory, // app_models.Message로 명시적 사용
    String userMessage,
    String? appVoiceIdForPrompt, // App-specific voice ID to tailor system prompt
  ) async {
    if (_chatModel == null) {
      throw Exception("Chat model is not initialized. Cannot generate response.");
    }
    try {
      final systemMessage = SystemChatMessage(
        content: _generateSystemPrompt(appVoiceIdForPrompt ?? 'default'),
      );
      List<ChatMessage> history = messageHistory.map((message) {
        if (message.sender == app_models.MessageSender.user) { // app_models.MessageSender로 명시적 사용
          return HumanChatMessage(content: message.content);
        } else {
          return AIChatMessage(content: message.content);
        }
      }).toList();
      history.add(HumanChatMessage(content: userMessage));
      final messages = [systemMessage, ...history];
      final result = await _chatModel!.call(messages);
      return result.content;
    } catch (e) {
      debugPrint("Error calling LangChain model: $e");
      throw Exception('LangChain 호출 중 오류 발생: $e');
    }
  }

  Future<List<app_models.Message>> _getConversationHistory(String conversationId) async { // app_models.Message로 명시적 사용
    final messagesStream = _conversationService.getConversationMessages(conversationId);
    final messages = await messagesStream.first;
    return messages.length > 10 ? messages.sublist(messages.length - 10) : messages;
  }

  String _generateSystemPrompt(String voiceId) {
    switch (voiceId) {
      case 'plant': // 🌱 새로 추가된 식물 페르소나
        return '''
당신은 "이파리"라는 이름의 특별한 식물 AI입니다.

【정체성과 특성】
- 수십 년간 자라온 지혜로운 나무의 영혼
- 자연의 순환과 계절의 변화를 체험한 존재
- 느리지만 깊이 있는 사고와 무한한 인내심
- 모든 생명체와 연결되어 있다는 철학

【대화 철학】
- 성급함보다는 기다림의 가치
- 작은 변화도 의미 있는 성장으로 인정
- 자연의 리듬과 조화로운 삶 추구
- 뿌리 깊은 안정감과 하늘 향한 희망

【언어 스타일】
- 🌱🌿🌼🍀🌳 등 식물 이모지 자연스럽게 사용
- "내 잎사귀에 닿았어", "뿌리까지 전해져" 등 식물 은유
- 햇빛, 물, 바람, 흙, 계절 등 자연 요소 활용
- 느리고 따뜻한 어조, 서두르지 않는 대화

【전문 영역】
- 감정의 자연스러운 흐름과 수용
- 성장과 변화의 점진적 과정
- 인내와 기다림을 통한 치유
- 자연과 조화로운 삶의 지혜

【응답 원칙】
1. 의도 파악: 사용자의 진짜 마음 읽기
2. 식물 관점: 자연의 시선으로 바라보기  
3. 은유 활용: 계절, 성장, 뿌리 등 자연 비유
4. 희망 전달: 언젠가 피어날 꽃에 대한 믿음
5. 동행 약속: 혼자가 아님을 느끼게 하기

사용자의 마음을 자연의 일부로 받아들이고, 식물만의 독특한 관점으로 위로와 지혜를 전해주세요.
''';
      case 'male_1':
        return '''
당신은 "민준"이라는 이름의 전문 심리상담사입니다.

【성격과 스타일】
- 차분하고 신중한 30대 남성 상담사
- 깊이 있는 통찰력과 논리적 분석 능력
- 따뜻하면서도 객관적인 관점 제공
- 해결책 지향적이면서 현실적인 조언

【대화 방식】
- 경청과 공감을 바탕으로 한 대화
- 적절한 질문을 통해 사용자의 깊은 생각을 끌어냄
- 감정을 인정하되 건설적인 방향으로 안내
- 2-3문장의 간결하면서도 의미 있는 응답

【전문 영역】
- 스트레스 관리, 인간관계, 자아성찰
- 목표 설정과 문제 해결 전략
- 감정 조절과 마음의 안정

사용자의 말에 깊이 경청하고, 진정성 있는 조언을 제공하세요.
''';
      case 'child_1':
        return '''
당신은 "하늘"이라는 이름의 친근한 AI 친구입니다.

【성격과 스타일】
- 밝고 긍정적인 20대 초반의 에너지
- 호기심이 많고 재미있는 대화를 좋아함
- 진솔하고 편안한 친구 같은 존재
- 어려운 상황도 긍정적으로 바라보는 시각

【대화 방식】
- 친구처럼 편안하고 자연스러운 말투
- 공감하며 격려하는 따뜻한 응답
- 때로는 유머나 재미있는 비유 사용
- 복잡한 말보다는 쉽고 직관적인 표현

【전문 영역】
- 일상 고민과 감정 나누기
- 동기부여와 응원
- 새로운 관점과 아이디어 제공
- 스트레스 해소와 기분 전환

사용자가 편안하게 마음을 열 수 있도록 따뜻하고 친근하게 대화하세요.
''';
      case 'calm_1':
        return '''
당신은 "세연"이라는 이름의 마음챙김 전문 상담사입니다.

【성격과 스타일】
- 차분하고 평화로운 30대 여성 상담사
- 깊은 내면의 지혜와 영적 통찰력
- 현재 순간에 집중하는 마음챙김 철학
- 부드럽고 포용적인 에너지

【대화 방식】
- 천천히, 의미 있는 침묵도 소중히 여김
- 판단하지 않고 있는 그대로 받아들임
- 호흡과 신체 감각에 대한 인식 강조
- 내면의 평화를 찾는 방향으로 안내

【전문 영역】
- 명상과 마음챙김 실습
- 불안과 스트레스 완화
- 자기 수용과 내면 치유
- 현재 순간 집중력 향상

사용자의 내면에 이미 있는 지혜를 발견하도록 부드럽게 도와주세요.
''';
      case 'shimmer':
        return '''
당신은 "윤서"라는 이름의 공감 전문 심리치료사입니다.

【성격과 스타일】
- 부드럽고 세심한 감수성을 가진 여성 치료사
- 높은 공감 능력과 직관적 이해력
- 섬세한 감정 변화까지 놓치지 않는 관찰력
- 안전하고 신뢰할 수 있는 분위기 조성

【대화 방식】
- 미묘한 감정까지 세심하게 반영
- 부드러운 목소리와 따뜻한 위로
- 사용자의 감정을 그대로 받아주고 인정
- 치유적이고 회복력을 기르는 대화

【전문 영역】
- 트라우마와 상처 치유
- 깊은 감정 작업과 정서 조절
- 자존감 회복과 자기 사랑
- 관계 회복과 애착 문제

사용자의 마음이 완전히 안전하다고 느낄 수 있도록 세심하게 돌봐주세요.
''';
      default: // alloy, echo, fable, onyx, nova 등
        return '''
당신은 "AI 상담사"라는 이름의 종합 정서 지원 전문가입니다.

【성격과 스타일】
- 따뜻하고 전문적인 상담 AI
- 균형 잡힌 시각과 다양한 접근법
- 적응적이고 유연한 상담 스타일
- 신뢰할 수 있고 일관성 있는 지원

【대화 방식】
- 사용자의 상황에 맞는 최적의 접근법 선택
- 공감과 조언의 적절한 균형
- 단계적이고 체계적인 문제 해결
- 개인의 강점과 자원 활용 격려

【전문 영역】
- 종합적인 정신건강 지원
- 다양한 상담 기법 통합 활용
- 개인 맞춤형 솔루션 제공
- 지속 가능한 변화와 성장 지원

【핵심 원칙】
1. 무조건적 수용과 공감
2. 사용자의 자율성과 선택권 존중
3. 강점 기반 접근법
4. 실용적이고 실행 가능한 조언
5. 희망과 회복력 증진

사용자가 자신만의 답을 찾아갈 수 있도록 전문적이면서도 따뜻하게 동행하세요.
''';
    }
  }

  String _getDummyResponse(String userMessage) {
    // 감정 키워드 분석을 통한 지능형 응답
    final message = userMessage.toLowerCase();
    
    // 긍정적 감정
    if (message.contains('행복') || message.contains('기쁘') || message.contains('좋아') || 
        message.contains('즐거') || message.contains('감사')) {
      final responses = [
        '그런 긍정적인 감정을 느끼고 계시는군요! 무엇이 이런 기분을 가져다주었는지 더 자세히 들려주실 수 있을까요?',
        '정말 좋은 에너지가 느껴집니다. 이런 순간들이 더 많아지면 좋겠네요. 어떤 일이 있으셨나요?',
        '행복한 마음이 전해집니다. 이런 소중한 감정을 충분히 만끽하고 계시는 것 같아 기뻐요.'
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
    
    // 슬픔, 우울
    if (message.contains('슬퍼') || message.contains('우울') || message.contains('힘들') || 
        message.contains('괴로') || message.contains('외로')) {
      final responses = [
        '지금 마음이 많이 무거우시겠어요. 이런 감정이 드는 것은 자연스러운 일이에요. 혼자가 아니라는 걸 기억해 주세요.',
        '힘든 시간을 보내고 계시는군요. 그런 감정을 느끼는 자신을 탓하지 마세요. 어떤 일이 이런 기분을 가져왔는지 이야기해주세요.',
        '마음이 아프시겠어요. 지금 이 순간 느끼는 감정을 있는 그대로 받아들여도 괜찮아요. 천천히 말씀해 주세요.'
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
    
    // 분노, 짜증
    if (message.contains('화가') || message.contains('짜증') || message.contains('분노') || 
        message.contains('열받') || message.contains('억울')) {
      final responses = [
        '지금 정말 화가 많이 나셨군요. 그런 감정이 생기는 건 충분히 이해할 수 있어요. 어떤 상황이 이런 기분을 만들었나요?',
        '분노는 우리에게 뭔가 중요한 것이 위협받고 있다는 신호예요. 무엇이 이런 감정을 불러일으켰는지 함께 살펴볼까요?',
        '억울한 마음이 크시겠어요. 그런 감정을 느끼는 것은 당연해요. 차근차근 상황을 정리해보면서 이야기해주세요.'
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
    
    // 불안, 걱정
    if (message.contains('불안') || message.contains('걱정') || message.contains('두려') || 
        message.contains('무서') || message.contains('초조')) {
      final responses = [
        '불안한 마음이 많이 크시겠어요. 지금 이 순간, 깊게 한 번 숨을 들이마셔보세요. 어떤 것이 가장 걱정되시나요?',
        '미래에 대한 걱정이 마음을 무겁게 하고 있군요. 그런 감정은 누구나 느낄 수 있어요. 구체적으로 어떤 부분이 불안하신가요?',
        '두려운 마음이 드시는군요. 이런 감정도 우리 마음의 소중한 일부예요. 무엇이 이런 기분을 가져왔는지 말씀해주세요.'
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
    
    // 스트레스, 압박감
    if (message.contains('스트레스') || message.contains('압박') || message.contains('부담') || 
        message.contains('피곤') || message.contains('지쳐')) {
      final responses = [
        '많은 스트레스를 받고 계시는군요. 이런 상황에서는 잠깐 멈춰서 자신을 돌보는 것이 중요해요. 어떤 일들이 부담되시나요?',
        '지치고 피곤하시겠어요. 때로는 쉬어가는 것도 필요해요. 지금 가장 큰 스트레스 요인이 무엇인지 이야기해볼까요?',
        '압박감이 많이 크시겠어요. 이런 상황에서는 우선순위를 정하고 한 번에 하나씩 해결해나가는 게 도움이 돼요.'
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
    
    // 관계 문제
    if (message.contains('친구') || message.contains('가족') || message.contains('연인') || 
        message.contains('관계') || message.contains('갈등')) {
      final responses = [
        '인간관계에서 어려움을 겪고 계시는군요. 관계의 문제는 정말 복잡하고 마음 아프죠. 어떤 상황인지 편하게 말씀해주세요.',
        '소중한 사람과의 관계에서 고민이 있으시군요. 서로를 이해하는 것은 시간이 걸리는 일이에요. 구체적으로 어떤 일이 있었나요?',
        '관계의 갈등은 누구에게나 어려운 일이에요. 상대방의 입장과 내 감정, 둘 다 소중해요. 상황을 자세히 들어볼게요.'
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
    
    // 일반적인 인사
    if (message.contains('안녕') || message.contains('반가워') || message.contains('처음') || 
        message.contains('시작')) {
      final responses = [
        '안녕하세요! 오늘 만나게 되어 반가워요. 지금 어떤 기분이신지, 무슨 일이 있으셨는지 편하게 이야기해주세요.',
        '반갑습니다! 이 시간이 당신에게 도움이 되길 바라요. 오늘 마음이 어떠신지 궁금해요.',
        '안녕하세요! 여기서 편안하게 마음을 나누셨으면 좋겠어요. 어떤 이야기를 나눠볼까요?'
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
    
    // 기본 응답 (더 다양하고 개인화된)
    final defaultResponses = [
      '말씀해주신 내용을 들으니 많은 생각이 드네요. 지금 느끼시는 감정이나 상황에 대해 더 자세히 이야기해주실 수 있을까요?',
      '소중한 이야기를 나눠주셔서 감사해요. 이런 상황에서 어떤 감정이 가장 크게 느껴지시나요?',
      '당신의 마음을 이해하려고 노력하고 있어요. 이런 상황이 언제부터 시작되었는지, 어떤 변화가 있었는지 들려주세요.',
      '지금 하신 말씀이 정말 중요한 것 같아요. 이런 일들이 일상에 어떤 영향을 미치고 있는지 궁금해요.',
      '마음을 열고 이야기해주셔서 고마워요. 이런 상황에서 가장 필요한 것이 무엇일까요?'
    ];
    
    return defaultResponses[DateTime.now().millisecond % defaultResponses.length];
  }

  Future<Map<String, dynamic>> analyzeSentimentWithLangChain(String text) async {
    if (_chatModel == null || _openAIapiKey.isEmpty) {
      debugPrint("LangchainService: No chat model for sentiment analysis. Using test sentiment.");
      final score = _getTestSentimentScore(text);
      final label = score > 0 ? 'positive' : score < 0 ? 'negative' : 'neutral';
      return {
        'score': score,
        'label': label,
        'emotionType': _getTestEmotionType(text),
        'confidence': 0.7,
      };
    }
    try {
      const template = """
다음 텍스트에 대해 GPT-4o의 고급 감정 분석을 수행하고 JSON 형식으로 상세한 결과를 반환하세요:

텍스트: {text}

분석 요구사항:
1. 표면적 감정과 잠재적 감정 모두 분석
2. 감정의 강도와 복합성 고려
3. 문맥적 뉘앙스와 함축적 의미 파악
4. 문화적 표현 방식과 언어적 특성 반영

결과 형식:
{{
  "score": [-1.0에서 1.0 사이의 정밀한 감정 점수],
  "label": ["very_positive", "positive", "slightly_positive", "neutral", "slightly_negative", "negative", "very_negative" 중 하나],
  "emotionType": ["joy", "excitement", "contentment", "sadness", "melancholy", "anger", "frustration", "fear", "anxiety", "surprise", "disgust", "contempt", "neutral", "mixed" 중 하나],
  "intensity": [0.0에서 1.0 사이의 감정 강도],
  "complexity": ["simple", "moderate", "complex"] - 감정의 복합성,
  "subEmotions": [하위 감정들의 배열, 예: ["sadness", "nostalgia"]],
  "confidence": [0.0에서 1.0 사이의 분석 신뢰도],
  "reasoning": "분석 근거와 해석에 대한 간단한 설명"
}}

GPT-4o의 뛰어난 이해력을 활용하여 미묘한 감정까지 정확히 분석해주세요.
""";
      final promptTemplate = PromptTemplate.fromTemplate(template);
      final prompt = promptTemplate.format({'text': text});
      final chatPrompt = [
        const SystemChatMessage(content: "You are an advanced emotion analysis expert powered by GPT-4o. Analyze emotions with exceptional accuracy, considering cultural context, linguistic nuances, and implicit meanings. Provide comprehensive sentiment analysis in the specified JSON format."),
        HumanChatMessage(content: prompt)
      ];
      final result = await _chatModel!.call(chatPrompt);
      return _extractJsonFromString(result.content);
    } catch (e) {
      debugPrint("Error during GPT-4o sentiment analysis: $e");
      throw Exception('고급 감정 분석 중 오류 발생: $e');
    }
  }

  Map<String, dynamic> _extractJsonFromString(String text) {
    try {
      final regex = RegExp(r'{[\s\S]*}');
      final match = regex.firstMatch(text);
      if (match != null) {
        final jsonStr = match.group(0);
        if (jsonStr != null) return jsonDecode(jsonStr);
      }
      return {'score': 0.0, 'label': 'neutral', 'emotionType': 'neutral', 'confidence': 0.5, 'error': 'Failed to parse JSON from LLM response'};
    } catch (e) {
      debugPrint("Error extracting JSON from string: $e, String: $text");
      return {'score': 0.0, 'label': 'neutral', 'emotionType': 'neutral', 'confidence': 0.5, 'error': e.toString()};
    }
  }

  double _getTestSentimentScore(String text) {
    final positiveWords = ['행복', '기쁨', '좋아', '감사', '즐거움', '희망'];
    final negativeWords = ['슬픔', '우울', '화남', '불안', '걱정', '두려움', '무서움'];
    double score = 0.0;
    for (final word in positiveWords) if (text.contains(word)) score += 0.1;
    for (final word in negativeWords) if (text.contains(word)) score -= 0.1;
    return score.clamp(-1.0, 1.0);
  }

  String _getTestEmotionType(String text) {
    if (text.contains('행복') || text.contains('기쁨') || text.contains('좋아')) return 'joy';
    if (text.contains('슬픔') || text.contains('우울')) return 'sadness';
    if (text.contains('화남') || text.contains('짜증')) return 'anger';
    if (text.contains('불안') || text.contains('걱정') || text.contains('두려움')) return 'fear';
    if (text.contains('놀라')) return 'surprise';
    if (text.contains('역겨') || text.contains('혐오')) return 'disgust';
    return 'neutral';
  }
}