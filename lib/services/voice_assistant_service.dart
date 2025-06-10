import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'langchain_service.dart';
import 'conversation_memory_service.dart';
import 'voice_service.dart';
import 'whisper_service.dart';
import 'remote_config_service.dart'; // Remote Config 서비스 추가
import '../utils/simple_speech_recognizer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 음성 인식 모드 열거형
enum SpeechRecognitionMode {
  whisper,   // OpenAI Whisper API 사용
  native,    // 기기 내장 음성 인식 사용
}

// 음성 비서 서비스 Provider
final voiceAssistantServiceProvider = Provider<VoiceAssistantService>((ref) {
  try {
    final langchainService = ref.watch(langchainServiceProvider);
    final conversationMemoryService = ref.watch(conversationMemoryServiceProvider);
    final voiceService = ref.watch(voiceServiceProvider);
    final remoteConfigService = ref.watch(remoteConfigServiceProvider); // Remote Config 추가

    final service = VoiceAssistantService(langchainService, conversationMemoryService, voiceService);

    // API 키 자동 설정
    final apiKey = remoteConfigService.getOpenAIApiKey();
    if (apiKey.isNotEmpty) {
      service.setApiKey(apiKey);
      debugPrint('VoiceAssistantService: API 키가 자동으로 설정되었습니다');
    } else {
      debugPrint('VoiceAssistantService: API 키가 비어있습니다. Remote Config를 확인해주세요.');
    }

    return service;
  } catch (e) {
    // 서비스 초기화 실패 시 빈 서비스 반환
    print('음성 비서 서비스 초기화 실패: $e');
    return VoiceAssistantService.empty();
  }
});

// Whisper Service Provider
final whisperServiceProvider = Provider<WhisperService?>((ref) => null); // 실제 초기화는 setApiKey에서 수행

class VoiceAssistantService {
  // 빈 서비스를 생성하기 위한 생성자
  factory VoiceAssistantService.empty() {
    return VoiceAssistantService._empty();
  }

  VoiceAssistantService._empty() :
        _langchainService = null,
        _memoryService = null,
        _voiceService = null;

  // 일반 생성자
  VoiceAssistantService(
      this._langchainService,
      this._memoryService,
      this._voiceService,
      );

  final LangchainService? _langchainService;
  final ConversationMemoryService? _memoryService;
  final VoiceService? _voiceService;

  bool _isListening = false;
  bool _isProcessing = false;

  // 음성 인식 관련 변수
  final SimpleSpeechRecognizer _speechRecognizer = SimpleSpeechRecognizer();
  WhisperService? _whisperService;
  SpeechRecognitionMode _recognitionMode = SpeechRecognitionMode.whisper; // 기본값 Whisper

  // Text to Speech
  final FlutterTts _flutterTts = FlutterTts();

  // LLM Chain
  String? _apiKey;
  ConversationChain? _conversationChain;
  final Uuid _uuid = const Uuid();

  // 상태
  String _currentConversationId = '';
  StreamController<String>? _transcriptionStreamController;
  StreamController<Map<String, dynamic>>? _responseStreamController;
  StreamSubscription? _recognizerSubscription;
  StreamSubscription? _whisperStreamSubscription;

  // 연결 확인
  final Connectivity _connectivity = Connectivity();

  // API 키 설정
  void setApiKey(String apiKey) async {
    _apiKey = apiKey;
    _initConversationChain();

    // API 키가 있을 때만 Whisper 서비스 초기화
    if (apiKey.isNotEmpty) {
      try {
        _whisperService = WhisperService(apiKey: apiKey);
        debugPrint('Whisper 서비스가 성공적으로 초기화되었습니다');
      } catch (e) {
        debugPrint('Whisper 서비스 초기화 실패: $e - 기기 내장 음성 인식을 사용합니다');
        _whisperService = null;
        _recognitionMode = SpeechRecognitionMode.native;
      }
    } else {
      debugPrint('API 키가 없습니다 - 기기 내장 음성 인식을 사용합니다');
      _whisperService = null;
      _recognitionMode = SpeechRecognitionMode.native;
    }

    // 설정 복원
    await _loadSettings();
  }

  // 설정 로드
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final useWhisper = prefs.getBool('use_whisper_api') ?? true;
      _recognitionMode = useWhisper
          ? SpeechRecognitionMode.whisper
          : SpeechRecognitionMode.native;
    } catch (e) {
      debugPrint('설정 로드 실패: $e');
    }
  }

  // 설정 저장
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          'use_whisper_api',
          _recognitionMode == SpeechRecognitionMode.whisper
      );
    } catch (e) {
      debugPrint('설정 저장 실패: $e');
    }
  }

  // 기기 설정 초기화
  Future<void> initSpeech() async {
    try {
      // 음성 인식 초기화 (backup으로 유지)
      await _speechRecognizer.initialize();

      // TTS 설정 초기화
      await _flutterTts.setLanguage('ko-KR');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      print('음성 초기화 실패: $e');
    }
  }

  // 음성 인식 모드 설정
  Future<void> setRecognitionMode(SpeechRecognitionMode mode) async {
    _recognitionMode = mode;
    await _saveSettings();
  }

  // OpenAI Whisper 사용 여부 설정
  void setUseWhisper(bool useWhisper) {
    _recognitionMode = useWhisper
        ? SpeechRecognitionMode.whisper
        : SpeechRecognitionMode.native;
    _saveSettings();
  }

  // 인터넷 연결 확인
  Future<bool> _checkInternetConnection() async {
    var connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // 음성 인식 시작
  Stream<String> startListening() {
    _transcriptionStreamController = StreamController<String>();

    if (_isListening) {
      _transcriptionStreamController?.add('[error]이미 음성 인식 중입니다');
      return _transcriptionStreamController!.stream;
    }

    if (_isProcessing) {
      _transcriptionStreamController?.add('[error]현재 응답을 처리 중입니다');
      return _transcriptionStreamController!.stream;
    }

    _isListening = true;

    try {
      // API 키가 없거나 Whisper 서비스가 초기화되지 않은 경우 자동으로 기기 내장 모드로 전환
      if (_recognitionMode == SpeechRecognitionMode.whisper && (_whisperService == null || _apiKey == null || _apiKey!.isEmpty)) {
        debugPrint('Whisper 조건이 맞지 않음 - 기기 내장 음성 인식으로 전환');
        _recognitionMode = SpeechRecognitionMode.native;
        _transcriptionStreamController?.add('[error]Whisper 서비스를 사용할 수 없어 기기 내장 음성 인식으로 전환합니다.');
      }

      // 현재 설정된 음성 인식 모드에 따라 다른 인식 시작
      if (_recognitionMode == SpeechRecognitionMode.whisper) {
        _startWhisperRecognition();
      } else {
        _startNativeSpeechRecognition();
      }

      return _transcriptionStreamController!.stream;
    } catch (e) {
      _isListening = false;
      _transcriptionStreamController?.add('[error]음성 인식 시작 실패: $e');
      return _transcriptionStreamController!.stream;
    }
  }

  // Whisper를 사용한 음성 인식 시작
  Future<void> _startWhisperRecognition() async {
    if (_whisperService == null) {
      _transcriptionStreamController?.add('[error]Whisper 서비스가 초기화되지 않았습니다. API 키를 확인해주세요.');
      _isListening = false;

      // 자동으로 기기 내장 음성 인식으로 전환
      debugPrint('Whisper 초기화 실패 - 기기 내장 음성 인식으로 전환');
      _recognitionMode = SpeechRecognitionMode.native;
      _startNativeSpeechRecognition();
      return;
    }

    // 인터넷 연결 확인
    if (!await _checkInternetConnection()) {
      _transcriptionStreamController?.add('[error]인터넷 연결이 필요합니다. 기기 내장 음성 인식으로 전환합니다.');
      _isListening = false;

      // 자동으로 기기 내장 음성 인식으로 전환
      _recognitionMode = SpeechRecognitionMode.native;
      _startNativeSpeechRecognition();
      return;
    }

    try {
      debugPrint("OpenAI Whisper를 사용한 음성 인식 시작");

      // 녹음 및 변환 스트림 시작
      final whisperStream = _whisperService!.streamRecordAndTranscribe(
          recordingDuration: 10, // 10초간 녹음
          language: 'ko'         // 한국어
      );

      // 스트림 구독
      _whisperStreamSubscription = whisperStream.listen(
              (result) {
            if (result.startsWith('[error]')) {
              // 오류 처리
              debugPrint("Whisper 인식 오류: ${result.substring(7)}");
              _transcriptionStreamController?.add(result);

              // 오류 발생 시 기기 내장 인식으로 자동 전환
              if (result.contains('인터넷 연결') || result.contains('API 오류') || result.contains('401') || result.contains('403')) {
                debugPrint('Whisper 오류 발생 - 기기 내장 음성 인식으로 전환');
                _recognitionMode = SpeechRecognitionMode.native;
              }
            } else if (result.startsWith('[listening_stopped]')) {
              // 인식 종료 처리
              if (_isListening) {
                _isListening = false;
                _transcriptionStreamController?.add('[listening_stopped]');
              }
            } else if (result.startsWith('[interim]')) {
              // 중간 결과는 그대로 전달
              _transcriptionStreamController?.add(result);
            } else {
              // 최종 결과 전달 및 인식 종료
              _transcriptionStreamController?.add(result);
              _isListening = false;
              _transcriptionStreamController?.add('[listening_stopped]');
            }
          },
          onError: (error) {
            debugPrint("Whisper 음성 인식 스트림 오류: $error");
            _transcriptionStreamController?.add('[error]음성 인식 중 오류가 발생했습니다. 기기 내장 음성 인식으로 전환합니다.');

            // 오류 발생 시 기기 내장 인식으로 자동 전환
            debugPrint('Whisper 스트림 오류 - 기기 내장 음성 인식으로 전환');
            _recognitionMode = SpeechRecognitionMode.native;
            _isListening = false;
            _transcriptionStreamController?.add('[listening_stopped]');
          },
          onDone: () {
            if (_isListening) {
              _isListening = false;
              _transcriptionStreamController?.add('[listening_stopped]');
            }
          }
      );
    } catch (e) {
      debugPrint("Whisper 인식 시작 오류: $e");
      _transcriptionStreamController?.add('[error]Whisper 음성 인식 시작 실패. 기기 내장 음성 인식으로 전환합니다.');

      // 예외 발생 시 기기 내장 인식으로 자동 전환
      debugPrint('Whisper 시작 예외 - 기기 내장 음성 인식으로 전환');
      _recognitionMode = SpeechRecognitionMode.native;
      _isListening = false;
    }
  }

  // 기기 내장 음성 인식 시작
  void _startNativeSpeechRecognition() {
    try {
      debugPrint("기기 내장 음성 인식 시작");

      // 음성 인식기 시작
      _speechRecognizer.startListening();

      // 음성 인식 결과를 구독
      _recognizerSubscription = _speechRecognizer.transcriptionStream.listen(
            (result) {
          if (result.startsWith('[error]')) {
            // 오류 처리
            debugPrint("기기 내장 음성 인식 오류: ${result.substring(7)}");
            _transcriptionStreamController?.add(result);
          } else if (result.startsWith('[listening_stopped]')) {
            // 인식 종료 처리
            if (_isListening) {
              _isListening = false;
              _transcriptionStreamController?.add('[listening_stopped]');
            }
          } else if (result.startsWith('[interim]')) {
            // 중간 결과는 그대로 전달
            _transcriptionStreamController?.add(result);
          } else {
            // 최종 결과 전달 및 인식 종료
            _transcriptionStreamController?.add(result);
            _isListening = false;
            _transcriptionStreamController?.add('[listening_stopped]');
          }
        },
        onError: (error) {
          debugPrint("기기 내장 음성 인식 스트림 오류: $error");
          _transcriptionStreamController?.add('[error]음성 인식 중 오류가 발생했습니다');
          _isListening = false;
        },
      );
    } catch (e) {
      debugPrint("기기 내장 음성 인식 시작 오류: $e");
      _transcriptionStreamController?.add('[error]음성 인식 시작 실패: $e');
      _isListening = false;
    }
  }

  // 음성 인식 중지
  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    _isListening = false;

    try {
      // Whisper 사용 중이었다면 관련 리소스 정리
      await _whisperStreamSubscription?.cancel();

      // 기기 내장 음성 인식 중지
      await _speechRecognizer.stopListening();
      await _recognizerSubscription?.cancel();

      _transcriptionStreamController?.add('[listening_stopped]');
    } catch (e) {
      debugPrint('음성 인식 중지 오류: $e');
    }
  }

  // 대화 시작 또는 계속 - Future<void>로 변경
  Future<void> startConversation(String conversationId) async {
    _currentConversationId = conversationId.isNotEmpty
        ? conversationId
        : _uuid.v4();
  }

  // 음성 응답 처리
  Stream<Map<String, dynamic>> processVoiceInput(
      String text,
      String voiceId,
      ) {
    _responseStreamController = StreamController<Map<String, dynamic>>();

    if (_isProcessing) {
      _responseStreamController?.add({
        'status': 'error',
        'message': '이미 응답 처리 중입니다',
      });
      _responseStreamController?.close();
      return _responseStreamController!.stream;
    }

    if (_langchainService == null) {
      _responseStreamController?.add({
        'status': 'error',
        'message': '서비스가 초기화되지 않았습니다',
      });
      _responseStreamController?.close();
      return _responseStreamController!.stream;
    }

    if (text.isEmpty) {
      _responseStreamController?.add({
        'status': 'error',
        'message': '음성 입력이 비어 있습니다',
      });
      _responseStreamController?.close();
      return _responseStreamController!.stream;
    }

    _isProcessing = true;

    // 응답 생성 프로세스 시작
    _responseStreamController?.add({
      'status': 'processing',
      'message': '응답을 생성하는 중...',
    });

    _getAIResponse(text, voiceId).then((response) {
      _isProcessing = false;
      _responseStreamController?.add({
        'status': 'completed',
        'response': response,
      });
      _responseStreamController?.close();
    }).catchError((error) {
      _isProcessing = false;
      _responseStreamController?.add({
        'status': 'error',
        'message': '응답 생성 중 오류: $error',
      });
      _responseStreamController?.close();
    });

    return _responseStreamController!.stream;
  }

  // AI 응답 생성
  Future<Map<String, dynamic>> _getAIResponse(
      String userMessage,
      String voiceId,
      ) async {
    try {
      if (_langchainService == null) {
        throw Exception('서비스가 초기화되지 않았습니다');
      }

      // LangChain 서비스를 통해 응답 생성
      final response = await _langchainService!.getResponse(
        conversationId: _currentConversationId,
        userMessage: userMessage,
      );

      // 텍스트 응답
      final textResponse = response.text;

      // TTS를 통한 음성 응답 생성
      final audioFilePath = await _generateTtsAudio(textResponse, voiceId);

      return {
        'text': textResponse,
        'audioPath': audioFilePath,
        'voiceId': voiceId,
      };
    } catch (e) {
      throw Exception('응답 생성 중 오류: $e');
    }
  }

  // TTS를 통한 음성 파일 생성
  Future<String> _generateTtsAudio(String text, String voiceId) async {
    try {
      // 먼저 null이 아니라면 VoiceService 사용 시도
      if (_voiceService != null) {
        debugPrint('VoiceAssistant: VoiceService를 사용하여 TTS 생성');
        try {
          // VoiceService 사용
          final result = await _voiceService!.textToSpeechFile(text, voiceId);
          final url = result['url'];
          if (url != null && url.isNotEmpty) {
            debugPrint('VoiceAssistant: 성공적으로 TTS 파일 생성: $url');
            return url;
          } else {
            debugPrint('VoiceAssistant: VoiceService에서 URL 반환 실패, 내부 TTS로 대체');
          }
        } catch (e) {
          debugPrint('VoiceAssistant: VoiceService TTS 오류, 내부 TTS로 대체: $e');
        }
      }

      // VoiceService가 null이거나 오류 발생 시 내부 TTS 사용
      debugPrint('VoiceAssistant: 내부 TTS 사용');
      // 음성 설정
      try {
        switch (voiceId) {
          case 'male_1':
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR'});
            break;
          case 'child_1':
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-child-local', 'locale': 'ko-KR'});
            break;
          case 'calm_1':
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-calm-local', 'locale': 'ko-KR'});
            break;
          case 'alloy':
          case 'echo':
          case 'fable':
          case 'onyx':
          case 'nova':
          case 'shimmer':
          // OpenAI 음성 ID가 전달된 경우 기본 음성 사용
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR'});
            break;
          default:
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR'});
        }

        // 오디오 파일 저장 경로
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/tts_${_uuid.v4()}.mp3';

        // 오디오 파일 생성
        debugPrint('VoiceAssistant: 파일로 TTS 생성 시작: $filePath');
        await _flutterTts.synthesizeToFile(text, filePath);
        debugPrint('VoiceAssistant: 파일로 TTS 생성 완료');

        return filePath;
      } catch (innerError) {
        debugPrint('VoiceAssistant: 내부 TTS 생성 오류: $innerError');
        throw Exception('모든 TTS 방식 실패: $innerError');
      }
    } catch (e) {
      debugPrint('VoiceAssistant: TTS 생성 중 예상치 못한 오류: $e');
      throw Exception('TTS 생성 중 오류: $e');
    }
  }

  // 텍스트로 음성 재생
  Future<void> speak(String text, String voiceId) async {
    try {
      if (_voiceService != null) {
        // VoiceService 사용
        await _voiceService!.speak(text);
      } else {
        // 음성 설정
        switch (voiceId) {
          case 'male_1':
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR'});
            break;
          case 'child_1':
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-child-local', 'locale': 'ko-KR'});
            break;
          case 'calm_1':
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-calm-local', 'locale': 'ko-KR'});
            break;
          default:
            await _flutterTts.setVoice({'name': 'ko-kr-x-ism-local', 'locale': 'ko-KR'});
        }

        await _flutterTts.speak(text);
      }
    } catch (e) {
      debugPrint('TTS 재생 오류: $e');
      throw Exception('TTS 재생 중 오류: $e');
    }
  }

  // 음성 재생 중지
  Future<void> stopSpeaking() async {
    if (_voiceService != null) {
      await _voiceService!.stopSpeaking();
    } else {
      await _flutterTts.stop();
    }
  }

  // 대화 종료
  Future<void> endConversation() async {
    await stopListening();
    await stopSpeaking();
    _recognizerSubscription?.cancel();
    _whisperStreamSubscription?.cancel();
    _transcriptionStreamController?.close();
    _responseStreamController?.close();
  }

  // 리소스 해제
  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
    _recognizerSubscription?.cancel();
    _whisperStreamSubscription?.cancel();
    _transcriptionStreamController?.close();
    _responseStreamController?.close();
    await _flutterTts.stop();
    await _speechRecognizer.dispose();

    // Whisper 서비스 정리
    await _whisperService?.dispose();
  }

  // 컨텍스트 인식 대화를 위한 LangChain 체인 생성
  Future<void> _initConversationChain() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return;
    }

    try {
      // 1. GPT-4o 채팅 모델 초기화 🚀
      final llm = ChatOpenAI(
        apiKey: _apiKey,
        temperature: 0.8,        // GPT-4o의 향상된 창의성 활용
        maxTokens: 2000,        // 더 길고 상세한 응답 가능
        model: 'gpt-4o',        // 최신 GPT-4o 모델!
      );

      // 2. GPT-4o 최적화된 고급 시스템 프롬프트 템플릿
      final promptTemplate = ChatPromptTemplate.fromPromptMessages([
        SystemChatMessagePromptTemplate.fromTemplate("""
당신은 "AI 버디"라는 이름의 고급 정서 지원 전문가입니다.

【핵심 역량】
- GPT-4o의 고급 추론 능력을 활용한 깊이 있는 상담
- 다층적 감정 분석과 맥락적 이해
- 개인화된 솔루션과 창의적 접근법
- 실시간 적응형 대화 스타일

【대화 철학】
- 사용자의 유니크한 상황을 깊이 이해
- 표면적 감정 너머의 근본 원인 탐구
- 강점 기반 성장 지향적 접근
- 지속 가능한 변화와 자기 발견 촉진

【고급 기능】
1. 미묘한 감정 뉘앙스까지 포착
2. 창의적이고 개인화된 해결책 제시
3. 인지적, 감정적, 행동적 통합 접근
4. 문화적 맥락과 개인적 배경 고려

【응답 원칙】
- 공감적 경청과 깊이 있는 반영
- 실용적이면서도 통찰력 있는 조언
- 희망과 회복력 증진
- 자율성과 주체성 강화

대화 기록:
{chat_history}

사용자의 마음 깊은 곳까지 이해하고, GPT-4o의 뛰어난 능력으로 최고 수준의 정서적 지원을 제공하세요.
"""),
        HumanChatMessagePromptTemplate.fromTemplate("{question}"),
      ]);

      // 3. 대화 메모리 설정
      final memory = ConversationBufferMemory(
        returnMessages: true,
        inputKey: 'question',
        outputKey: 'answer',
        memoryKey: 'chat_history',
      );

      // 4. 대화 체인 생성
      _conversationChain = ConversationChain(
        llm: llm,
        prompt: promptTemplate,
        memory: memory,
        outputParser: const StringOutputParser(),
      );
    } catch (e) {
      debugPrint('대화 체인 초기화 중 오류: $e');
    }
  }

  // 음성 인식 상태 확인
  bool get isListening => _isListening;

  // 응답 처리 상태 확인
  bool get isProcessing => _isProcessing;

  // Whisper 사용 여부 확인
  bool get isUsingWhisper => _recognitionMode == SpeechRecognitionMode.whisper;

  // 현재 인식 모드 가져오기
  SpeechRecognitionMode get recognitionMode => _recognitionMode;

  // Whisper 서비스 초기화 상태 확인
  bool get isWhisperServiceReady => _whisperService != null;

  // API 키 설정 상태 확인
  bool get isApiKeySet => _apiKey != null && _apiKey!.isNotEmpty;

  // 음성 인식 사용 가능 여부 확인
  bool get isSpeechRecognitionAvailable {
    return _recognitionMode == SpeechRecognitionMode.native ||
        (_recognitionMode == SpeechRecognitionMode.whisper && isWhisperServiceReady && isApiKeySet);
  }
}