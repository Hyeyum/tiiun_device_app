import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:ui';
import '../../services/voice_assistant_service.dart';
import '../../services/conversation_service.dart';
import '../../services/auth_service.dart';
import '../../services/voice_service.dart';
import '../../design_system/colors.dart';
import '../../design_system/typography.dart';

class AdvancedVoiceChatPage extends ConsumerStatefulWidget {
  final bool autoStart; // 자동으로 음성 대화 시작 여부

  const AdvancedVoiceChatPage({super.key, this.autoStart = false});

  @override
  ConsumerState<AdvancedVoiceChatPage> createState() => _AdvancedVoiceChatPageState();
}

class _AdvancedVoiceChatPageState extends ConsumerState<AdvancedVoiceChatPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isPlaying = false;
  String _currentTranscription = '';
  String _currentStatus = '음성 버튼을 눌러 대화를 시작하세요';
  String _currentAISpeech = ''; // AI가 현재 말하고 있는 내용
  String _currentExpression = 'basic.png'; // 현재 틔운 표정
  String _lastUserMessage = ''; // 마지막 사용자 메시지 (표정 분석용)

  StreamSubscription? _transcriptionSubscription;
  StreamSubscription? _responseSubscription;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  String? _conversationId;

  // 서비스 참조를 저장할 변수들
  dynamic _voiceAssistantService;
  dynamic _voiceService;
  bool _servicesInitialized = false;

  // 자동 재시작 타이머
  Timer? _autoRestartTimer;
  bool _shouldAutoRestart = false;
  int _autoRestartAttempts = 0; // 자동 재시작 시도 횟수
  static const int _maxAutoRestartAttempts = 3; // 최대 자동 재시작 시도 횟수

  // 대기 페이지로 돌아가는 타이머
  Timer? _returnToWaitingTimer;
  static const Duration _returnToWaitingTimeout = Duration(seconds: 10); // 테스트용 10초 (나중에 1분으로 변경) Duration(minutes: 1)

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    // autoStart 모드 설정
    _shouldAutoRestart = widget.autoStart;
    print('🔧 autoStart 모드 설정: $_shouldAutoRestart');

    // 초기화 및 환영 메시지
    _initializeServices();
  }

  // 처리 중 상태를 강제로 리셋하는 메서드
  void _forceResetProcessingState() {
    setState(() {
      _isProcessing = false;
      _isListening = false;
      _isPlaying = false;
    });

    // 애니메이션 중지
    _pulseController.stop();
    _waveController.stop();

    // 스트림 구독 취소
    _transcriptionSubscription?.cancel();
    _responseSubscription?.cancel();

    // 자동 재시작 타이머 취소 및 시도 횟수 리셋
    _autoRestartTimer?.cancel();
    _autoRestartAttempts = 0;
    print('🔄 처리 상태 리셋 - 자동 재시작 시도 횟수도 리셋: $_autoRestartAttempts');
  }

  Future<void> _initializeServices() async {
    print('🚀 _initializeServices 시작 - autoStart: ${widget.autoStart}');
    
    try {
      final voiceAssistant = ref.read(voiceAssistantServiceProvider);
      final conversationService = ref.read(conversationServiceProvider);

      // 서비스 참조 저장
      _voiceAssistantService = voiceAssistant;
      _voiceService = ref.read(voiceServiceProvider);
      _servicesInitialized = true;
      print('✅ 서비스 참조 저장 완료');

      // 새 대화 생성
      final userId = ref.read(authServiceProvider).getCurrentUserId();
      if (userId != null) {
        print('🔄 새 대화 생성 중...');
        final conversation = await conversationService.createConversation(plantId: null);
        _conversationId = conversation.id;
        print('✅ 대화 생성 완료: $_conversationId');

        // 음성 비서 대화 시작
        print('🔄 음성 비서 대화 시작 중...');
        await voiceAssistant.startConversation(_conversationId!);
        print('✅ 음성 비서 대화 시작 완료');

        // autoStart에 따라 다른 환영 메시지
        if (widget.autoStart) {
          // motion 감지로 시작된 경우 - 환영 메시지 추가하지 않음 (이미 waiting page에서 재생됨)
          print('🎤 autoStart 모드 감지됨 - 자동 음성 인식 준비');

          setState(() {
            _currentStatus = '잠시만 기다려주세요... 음성 인식을 준비하고 있어요 🎙️';
            _currentAISpeech = '버디가 대화 준비를 하고 있어요...';
          });

          // 서비스 초기화가 완료되면 바로 시작하도록 변경
          print('🎯 _scheduleAutoStartAfterInit 호출 예정');
          _scheduleAutoStartAfterInit();
          print('✅ _scheduleAutoStartAfterInit 호출 완료');
        } else {
          // 수동으로 시작된 경우
          print('🔧 수동 모드 - 환영 메시지 추가');
          _addAIMessage('안녕하세요! 저는 틔운의 AI 버디입니다. 아래 마이크 버튼을 눌러 음성으로 편하게 대화해보세요! 🎤');

          setState(() {
            _currentStatus = '음성 버튼을 눌러 대화를 시작하세요';
          });
        }
      } else {
        print('⚠️ userId가 null이지만 임시 대화 ID로 진행합니다');
        _conversationId = 'temp_conversation_${DateTime.now().millisecondsSinceEpoch}';
        
        // 임시 대화 시작 (userId 없이도 진행)
        try {
          await voiceAssistant.startConversation(_conversationId!);
          print('✅ 임시 음성 비서 대화 시작 완료');
        } catch (e) {
          print('⚠️ 임시 대화 시작 실패하지만 autoStart는 계속 진행: $e');
        }
      }

      // autoStart 로직 (userId와 무관하게 실행)
      if (widget.autoStart) {
        // motion 감지로 시작된 경우 - 환영 메시지 추가하지 않음 (이미 waiting page에서 재생됨)
        print('🎤 autoStart 모드 감지됨 - 자동 음성 인식 준비');

        setState(() {
          _currentStatus = '잠시만 기다려주세요... 음성 인식을 준비하고 있어요 🎙️';
          _currentAISpeech = '버디가 대화 준비를 하고 있어요...';
        });

        // 서비스 초기화가 완료되면 바로 시작하도록 변경
        print('🎯 _scheduleAutoStartAfterInit 호출 예정');
        _scheduleAutoStartAfterInit();
        print('✅ _scheduleAutoStartAfterInit 호출 완료');
      } else {
        // 수동으로 시작된 경우
        print('🔧 수동 모드 - 환영 메시지 추가');
        _addAIMessage('안녕하세요! 저는 틔운의 AI 버디입니다. 아래 마이크 버튼을 눌러 음성으로 편하게 대화해보세요! 🎤');

        setState(() {
          _currentStatus = '음성 버튼을 눌러 대화를 시작하세요';
        });
      }
    } catch (e) {
      print('🚨 서비스 초기화 오류: $e');
      _addSystemMessage('서비스 초기화 중 오류가 발생했습니다: $e');
    }
    
    print('🏁 _initializeServices 완료');
  }

  // 환영 메시지 재생 후 자동으로 음성 인식 시작
  Future<void> _playWelcomeMessageAndStartListening() async {
    if (!mounted || !_servicesInitialized || _voiceService == null) return;

    try {
      final welcomeMessage = '안녕하세요! 움직임이 감지되어 대화를 시작합니다. 현재 식물 상태를 확인하고 있어요. 무엇을 도와드릴까요?';

      setState(() {
        _currentStatus = '환영 인사를 들려드릴게요... 🎵';
      });

      // 환영 메시지 음성 재생
      final voiceService = _voiceService;
      await voiceService.speak(welcomeMessage);

      // 잠깐 대기 후 음성 인식 자동 시작
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        setState(() {
          _currentStatus = '자동으로 음성 인식을 시작합니다. 말씀해주세요!';
        });

        // 자동으로 음성 인식 시작
        await _startListening();
      }

    } catch (e) {
      print('환영 메시지 재생 오류: $e');
      if (mounted) {
        setState(() {
          _currentStatus = '환영 메시지 재생 중 오류가 발생했습니다. 마이크 버튼을 눌러 대화를 시작하세요.';
        });
      }
    }
  }

  void _toggleVoiceRecording() async {
    // mounted 체크 추가
    if (!mounted || !_servicesInitialized) return;

    // 사용자가 수동으로 버튼을 눌렀으므로 대기 페이지 복귀 타이머 취소
    _cancelReturnToWaitingTimer();
    
    // 자동 재시작 시도 횟수 리셋 (사용자가 직접 개입함)
    _autoRestartAttempts = 0;
    print('🔄 사용자 개입으로 자동 재시작 시도 횟수 리셋: $_autoRestartAttempts');

    if (_isListening) {
      // 음성 인식 중지
      await _stopListening();
    } else if (_isProcessing) {
      // 처리 중에는 강제로 중지하고 상태 리셋
      print('⚠️ 처리 중 상태를 강제로 리셋합니다.');
      _forceResetProcessingState();
      _addSystemMessage('처리를 중단하고 새로운 음성 인식을 시작합니다.');
      await Future.delayed(const Duration(milliseconds: 500));
      await _startListening();
    } else {
      // 음성 인식 시작
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    // mounted 체크 추가
    if (!mounted || !_servicesInitialized || _voiceAssistantService == null) return;

    // 혹시 모를 중복 호출 방지
    if (_isListening || _isProcessing) {
      print('⚠️ 이미 음성 인식 중이거나 처리 중입니다. 상태를 리셋합니다.');
      _forceResetProcessingState();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      final voiceAssistant = _voiceAssistantService;

      // 대기 페이지 복귀 타이머 취소 (활동 중이므로)
      _cancelReturnToWaitingTimer();

      setState(() {
        _isListening = true;
        _currentTranscription = '';
        _currentStatus = '👂 듣고 있어요! 편하게 말씀해주세요';
        _currentAISpeech = '🎧 버디가 집중해서 듣고 있어요!'; // 음성 인식 중 메시지
        _currentExpression = 'happy.png'; // 듣는 표정
      });

      // 펄스 애니메이션 시작
      _pulseController.repeat(reverse: true);

      // 음성 인식 시작
      final transcriptionStream = voiceAssistant.startListening();

      _transcriptionSubscription = transcriptionStream.listen(
            (result) {
          _handleTranscriptionResult(result);
        },
        onError: (error) {
          print('음성 인식 오류: $error');
          if (mounted) {
            setState(() {
              _isListening = false;
              _currentStatus = '음성 인식 오류: $error';
            });
          }
          _pulseController.stop();

          // autoStart 모드에서는 오류 후 자동 재시작
          if (_shouldAutoRestart && mounted) {
            _scheduleAutoRestart();
          }
        },
        onDone: () {
          print('음성 인식 스트림 종료');
        },
      );

    } catch (e) {
      print('음성 인식 시작 오류: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
          _currentStatus = '음성 인식 시작 실패: $e';
        });
      }
      _pulseController.stop();

      // autoStart 모드에서는 오류 후 자동 재시작
      if (_shouldAutoRestart && mounted) {
        _scheduleAutoRestart();
      } else {
        // 수동 모드에서는 대기 페이지 복귀 타이머 시작
        _startReturnToWaitingTimer();
      }
    }
  }

  Future<void> _stopListening() async {
    // mounted 체크 추가
    if (!mounted || !_servicesInitialized || _voiceAssistantService == null) return;

    try {
      final voiceAssistant = _voiceAssistantService;
      await voiceAssistant.stopListening();

      setState(() {
        _isListening = false;
        _currentStatus = '음성 인식을 중지했습니다';
      });

      _pulseController.stop();
      await _transcriptionSubscription?.cancel();
      _transcriptionSubscription = null;

      // 사용자가 강제 중지했으므로 10초 후 대기 페이지로 복귀
      print('🛑 사용자가 음성 인식을 강제 중지함 - 10초 후 대기 페이지로 복귀');
      _startReturnToWaitingTimer();

    } catch (e) {
      print('음성 인식 중지 오류: $e');
    }
  }

  void _handleTranscriptionResult(String result) {
    print('음성 인식 결과: $result');

    // mounted 체크 추가
    if (!mounted) return;

    if (result.startsWith('[error]')) {
      // 오류 메시지
      final errorMsg = result.substring(7);
      setState(() {
        _currentStatus = '오류: $errorMsg';
        _isListening = false;
      });
      _pulseController.stop();

      // autoStart 모드에서는 오류 후 자동 재시작 (최대 시도 횟수 확인)
      if (_shouldAutoRestart && _autoRestartAttempts < _maxAutoRestartAttempts) {
        _scheduleAutoRestart();
      } else {
        // 최대 시도 횟수 초과하거나 수동 모드에서는 대기 페이지로 복귀
        _startReturnToWaitingTimer();
      }

    } else if (result.startsWith('[listening_stopped]')) {
      // 인식 중지됨
      setState(() {
        _isListening = false;
        _currentStatus = '음성 인식이 완료되었습니다';
      });
      _pulseController.stop();

      // 최종 텍스트가 있으면 AI 응답 처리
      if (_currentTranscription.isNotEmpty) {
        _processUserInput(_currentTranscription);
      } else {
        // 텍스트가 없으면
        if (_shouldAutoRestart && _autoRestartAttempts < _maxAutoRestartAttempts) {
          // 자동 모드에서 텍스트가 없으면 재시작
          _scheduleAutoRestart();
        } else {
          // 수동 모드이거나 최대 시도 횟수 초과 시 대기 페이지 복귀
          print('🏠 음성 인식 결과 없음으로 대기 페이지 복귀 타이머 시작');
          _startReturnToWaitingTimer();
        }
      }

    } else if (result.startsWith('[interim]')) {
      // 중간 결과 (실시간 표시)
      final interimText = result.substring(9);
      setState(() {
        _currentTranscription = interimText;
        _currentStatus = '인식 중: "$interimText"';
      });

    } else {
      // 최종 결과
      setState(() {
        _currentTranscription = result;
        _currentStatus = '인식 완료: "$result"';
      });

      // 사용자 메시지 추가 (실제로는 UI에서 숨겨짐)
      _lastUserMessage = result; // 표정 분석을 위해 저장
      _addUserMessage(result);

      // AI 응답 처리 시작
      _processUserInput(result);
    }
  }

  void _processUserInput(String userInput) async {
    if (userInput.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _currentStatus = '음성이 인식되지 않았습니다. 다시 시도해주세요.';
        });
      }

      // autoStart 모드에서는 빈 입력 후 자동 재시작 (최대 시도 횟수 확인)
      if (_shouldAutoRestart && _autoRestartAttempts < _maxAutoRestartAttempts) {
        _scheduleAutoRestart();
      } else {
        // 최대 시도 횟수 초과하거나 수동 모드에서는 대기 페이지로 복귀
        _startReturnToWaitingTimer();
      }
      return;
    }

    // mounted 체크 추가
    if (!mounted || !_servicesInitialized || _voiceAssistantService == null) return;

    // 이미 처리 중인지 확인
    if (_isProcessing) {
      print('⚠️ 이미 처리 중입니다. 요청을 무시합니다.');
      return;
    }

    try {
      final voiceAssistant = _voiceAssistantService;

      setState(() {
        _isProcessing = true;
        _currentStatus = '🤔 잠깐만요! 버디가 생각 중이에요...';
        _currentAISpeech = '💭 좋은 답변을 준비하고 있어요!'; // AI 생각 중 메시지
        _currentExpression = 'happy.png'; // 생각하는 표정
      });

      // 웨이브 애니메이션 시작
      _waveController.repeat();

      // AI 응답 처리
      final responseStream = voiceAssistant.processVoiceInput(
        userInput,
        'shimmer', // 기본 음성 ID
      );

      _responseSubscription = responseStream.listen(
            (responseData) {
          _handleAIResponse(responseData);
        },
        onError: (error) {
          print('AI 응답 처리 오류: $error');
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _currentStatus = 'AI 응답 오류: $error';
            });
          }
          _waveController.stop();
          _addSystemMessage('응답 생성 중 오류가 발생했습니다: $error');

          // autoStart 모드에서는 오류 후 자동 재시작 (최대 시도 횟수 확인)
          if (_shouldAutoRestart && _autoRestartAttempts < _maxAutoRestartAttempts) {
            _scheduleAutoRestart();
          } else {
            // 최대 시도 횟수 초과하거나 수동 모드에서는 대기 페이지로 복귀
            _startReturnToWaitingTimer();
          }
        },
        onDone: () {
          print('AI 응답 처리 완료');
        },
      );

    } catch (e) {
      print('AI 응답 처리 시작 오류: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentStatus = '응답 처리 시작 실패: $e';
        });
      }
      _waveController.stop();

      // autoStart 모드에서는 오류 후 자동 재시작 (최대 시도 횟수 확인)
      if (_shouldAutoRestart && _autoRestartAttempts < _maxAutoRestartAttempts) {
        _scheduleAutoRestart();
      } else {
        // 최대 시도 횟수 초과하거나 수동 모드에서는 대기 페이지로 복귀
        _startReturnToWaitingTimer();
      }
    }
  }

  void _handleAIResponse(Map<String, dynamic> responseData) {
    print('AI 응답 데이터: $responseData');

    // mounted 체크 추가
    if (!mounted) return;

    final status = responseData['status'];

    if (status == 'processing') {
      // 처리 중
      setState(() {
        _currentStatus = responseData['message'] ?? '처리 중...';
      });

    } else if (status == 'completed') {
      // 응답 완료
      final response = responseData['response'];
      final aiText = response['text'];
      final audioPath = response['audioPath'];

      setState(() {
        _isProcessing = false;
        _currentStatus = '✨ 답변 준비 완료! 들어보세요';
        _currentAISpeech = aiText; // 상단에 AI 텍스트 표시
      });

      _waveController.stop();

      // AI 메시지 추가
      _addAIMessage(aiText);

      // 메시지 표시 시 기본 표정으로 변경
      setState(() {
        _currentExpression = 'basic.png';
      });
      print('🎭 메시지 표시 - 기본 표정으로 변경');

      // 음성 재생
      if (audioPath != null && audioPath.isNotEmpty) {
        print('🎵 AI 응답 음성 재생 시작');
        _playAIResponse(audioPath);
      } else {
        print('🔧 audioPath가 없음 - 직접 자동 재시작 처리');
        if (_shouldAutoRestart) {
          print('🔄 autoStart 모드 - audioPath 없이 자동 재시작 스케줄링');
          _scheduleAutoRestart();
        } else {
          print('🔧 수동 모드 - 버튼 클릭 대기');
          setState(() {
            _currentStatus = '음성 버튼을 눌러 대화를 계속하세요';
          });
        }
      }

    } else if (status == 'error') {
      // 오류
      setState(() {
        _isProcessing = false;
        _currentStatus = '오류: ${responseData['message']}';
      });
      _waveController.stop();
      _addSystemMessage('응답 생성 실패: ${responseData['message']}');

      // autoStart 모드에서는 오류 후 자동 재시작
      if (_shouldAutoRestart) {
        _scheduleAutoRestart();
      }
    }
  }

  void _playAIResponse(String audioPath) async {
    // mounted 체크 추가
    if (!mounted || !_servicesInitialized || _voiceService == null) return;

    try {
      setState(() {
        _isPlaying = true;
        _currentStatus = '🎵 버디가 답변해드리고 있어요!';
        _currentExpression = 'happy.png'; // 말하는 표정
      });

      final voiceService = _voiceService;
      await voiceService.playAudio(
        audioPath,
        isLocalFile: true,
        onComplete: () {
          print('🎵 음성 재생 완료 콜백 호출됨');
          if (mounted) {
            setState(() {
              _isPlaying = false;
              // _currentAISpeech = ''; // 음성 재생 완료 후에도 텍스트 유지
              _currentExpression = 'basic.png'; // 음성 재생 완료 후 기본 표정
            });
            print('🎭 음성 재생 완료 - 기본 표정으로 변경');
            print('🔧 _isPlaying을 false로 설정함');

            // autoStart 모드에서는 자동으로 다음 음성 인식 시작 (최대 시도 횟수 확인)
            if (_shouldAutoRestart && _autoRestartAttempts < _maxAutoRestartAttempts) {
              print('🔄 autoStart 모드 - 자동 재시작 스케줄링 (시도 횟수: $_autoRestartAttempts/$_maxAutoRestartAttempts)');
              setState(() {
                _currentStatus = '계속 대화해보세요! 언제든 말씀하세요 😊';
                _currentAISpeech = '당신의 이야기를 듣고 싶어요! (❁´◡`❁)';
              });
              _scheduleAutoRestart();
            } else {
              print('🔧 수동 모드이거나 최대 재시작 횟수 초과 - 대기 페이지 복귀 타이머 시작');
              setState(() {
                _currentStatus = '대화가 완료되었습니다. 잠시 후 대기 화면으로 돌아갑니다.';
              });
              _startReturnToWaitingTimer();
            }
          }
        },
      );

    } catch (e) {
      print('음성 재생 오류: $e');
      print('🔧 음성 재생 오류 - _isPlaying을 false로 설정');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          // _currentAISpeech = ''; // 오류 시에도 텍스트 유지
          _currentExpression = 'basic.png'; // 오류 시에도 기본 표정
        });

        if (_shouldAutoRestart && _autoRestartAttempts < _maxAutoRestartAttempts) {
          print('🔄 autoStart 모드 - 오류 후 자동 재시작 스케줄링 (시도 횟수: $_autoRestartAttempts/$_maxAutoRestartAttempts)');
          setState(() {
            _currentStatus = '음성 재생에 문제가 있었지만 계속 대화해보세요!';
            _currentAISpeech = '계속 말씀해주세요! 😊';
          });
          _scheduleAutoRestart();
        } else {
          setState(() {
            _currentStatus = '음성 재생 오류: $e';
          });
          _startReturnToWaitingTimer();
        }
      }
    }
  }

  // 대기 페이지로 돌아가는 타이머 시작
  void _startReturnToWaitingTimer() {
    print('⏰ 대기 페이지 복귀 타이머 시작 (${_returnToWaitingTimeout.inSeconds}초 후)');
    print('🔍 현재 상태: _isListening=$_isListening, _isProcessing=$_isProcessing, _isPlaying=$_isPlaying, _shouldAutoRestart=$_shouldAutoRestart');
    
    _returnToWaitingTimer?.cancel();
    _returnToWaitingTimer = Timer(_returnToWaitingTimeout, () {
      print('⏰ 타이머 실행됨 - 상태 재확인');
      print('🔍 타이머 실행 시 상태: mounted=$mounted, _isListening=$_isListening, _isProcessing=$_isProcessing, _isPlaying=$_isPlaying');
      
      if (mounted && !_isListening && !_isProcessing && !_isPlaying) {
        print('🔄 비활성 상태 지속으로 대기 페이지로 복귀');
        _returnToWaitingPage();
      } else {
        print('❌ 복귀 조건 미충족 - 타이머 재시작 안함');
      }
    });
  }

  // 대기 페이지로 돌아가는 타이머 취소
  void _cancelReturnToWaitingTimer() {
    if (_returnToWaitingTimer?.isActive == true) {
      print('⏰ 대기 페이지 복귀 타이머 취소');
    }
    _returnToWaitingTimer?.cancel();
    _returnToWaitingTimer = null;
  }

  // 대기 페이지로 복귀
  void _returnToWaitingPage() {
    if (!mounted) return;
    
    print('🏠 대기 페이지로 복귀 시작');
    
    // 모든 타이머와 스트림 정리
    _autoRestartTimer?.cancel();
    _returnToWaitingTimer?.cancel();
    _transcriptionSubscription?.cancel();
    _responseSubscription?.cancel();
    
    // 상태 리셋
    _forceResetProcessingState();
    
    // 음성 비서 정리
    if (_voiceAssistantService != null) {
      try {
        _voiceAssistantService.endConversation();
      } catch (e) {
        print('음성 비서 정리 중 오류: $e');
      }
    }
    
    // 대기 페이지로 이동
    try {
      Navigator.of(context).pushReplacementNamed('/tiiun_waiting');
      print('✅ 대기 페이지로 복귀 완료');
    } catch (e) {
      print('❌ 대기 페이지 복귀 실패: $e');
      // 대체 방법으로 pop을 시도
      try {
        Navigator.of(context).pop();
        print('✅ pop으로 대기 페이지 복귀 완료');
      } catch (e2) {
        print('❌ pop도 실패: $e2');
      }
    }
  }
  void _scheduleAutoRestart() {
    print('🔄 _scheduleAutoRestart 호출됨 - _shouldAutoRestart: $_shouldAutoRestart, mounted: $mounted, 시도 횟수: $_autoRestartAttempts/$_maxAutoRestartAttempts');
    
    if (!_shouldAutoRestart || !mounted) {
      print('❌ 자동 재시작 조건 미충족 - _shouldAutoRestart: $_shouldAutoRestart, mounted: $mounted');
      return;
    }

    // 최대 시도 횟수 확인
    if (_autoRestartAttempts >= _maxAutoRestartAttempts) {
      print('❌ 최대 자동 재시작 시도 횟수 초과 ($_autoRestartAttempts/$_maxAutoRestartAttempts) - 대기 페이지로 복귀');
      setState(() {
        _currentStatus = '대화가 완료되었습니다. 잠시 후 대기 화면으로 돌아갑니다.';
        _currentAISpeech = '수고하셨습니다! 🌟';
      });
      _startReturnToWaitingTimer();
      return;
    }

    _autoRestartTimer?.cancel();
    print('⏰ 2초 후 자동 재시작 타이머 설정 (시도 횟수: $_autoRestartAttempts/$_maxAutoRestartAttempts)');
    
    _autoRestartTimer = Timer(const Duration(milliseconds: 2000), () { // 5초에서 2초로 단축
      print('⏰ 타이머 실행됨 - 상태 확인');
      print('   mounted: $mounted');
      print('   _isListening: $_isListening');
      print('   _isProcessing: $_isProcessing');
      print('   _isPlaying: $_isPlaying');
      print('   시도 횟수: $_autoRestartAttempts/$_maxAutoRestartAttempts');
      
      if (mounted && !_isListening && !_isProcessing && !_isPlaying) {
        if (_autoRestartAttempts < _maxAutoRestartAttempts) {
          _autoRestartAttempts++; // 시도 횟수 증가
          print('🔄 자동으로 음성 인식을 재시작합니다 (시도 횟수: $_autoRestartAttempts/$_maxAutoRestartAttempts)');
          setState(() {
            _currentStatus = '계속 말씀해주세요... 🎤';
            _currentAISpeech = '버디가 듣고 있어요! 말씀하세요 😊';
          });
          _startListening();
        } else {
          print('❌ 최대 재시작 시도 횟수 초과 - 대기 페이지로 복귀');
          setState(() {
            _currentStatus = '대화가 완료되었습니다. 잠시 후 대기 화면으로 돌아갑니다.';
            _currentAISpeech = '수고하셨습니다! 🌟';
          });
          _startReturnToWaitingTimer();
        }
      } else {
        print('❌ 자동 재시작 조건 미충족 - 재시작하지 않음');
        if (_autoRestartAttempts >= _maxAutoRestartAttempts) {
          print('⚠️ 최대 시도 횟수 도달 - 대기 페이지로 복귀');
          setState(() {
            _currentStatus = '대화가 완료되었습니다. 잠시 후 대기 화면으로 돌아갑니다.';
          });
          _startReturnToWaitingTimer();
        }
      }
    });
  }

  // 대화 내용과 감정을 분석해서 적절한 표정 선택
  String _analyzeEmotionAndGetExpression(String userMessage, String aiResponse) {
    final lowerUserMessage = userMessage.toLowerCase();
    final lowerAiResponse = aiResponse.toLowerCase();
    
    // 사용자 메시지 감정 분석
    if (lowerUserMessage.contains('슬프') || lowerUserMessage.contains('우울') || 
        lowerUserMessage.contains('힘들') || lowerUserMessage.contains('아프') ||
        lowerUserMessage.contains('죽고싶') || lowerUserMessage.contains('괴로')) {
      return 'sad.png'; // 슬픈 표정
    }
    
    if (lowerUserMessage.contains('화나') || lowerUserMessage.contains('짜증') || 
        lowerUserMessage.contains('열받') || lowerUserMessage.contains('스트레스')) {
      return 'angry.png'; // 화난 표정
    }
    
    if (lowerUserMessage.contains('기뻐') || lowerUserMessage.contains('행복') || 
        lowerUserMessage.contains('좋아') || lowerUserMessage.contains('신나') ||
        lowerUserMessage.contains('즐거') || lowerUserMessage.contains('감사') ||
        lowerUserMessage.contains('고마') || lowerUserMessage.contains('웃겨') ||
        lowerUserMessage.contains('재밌') || lowerUserMessage.contains('하하')) {
      return 'laugh.png'; // 웃는 표정
    }
    
    if (lowerUserMessage.contains('사랑') || lowerUserMessage.contains('좋아해') ||
        lowerUserMessage.contains('예뻐') || lowerUserMessage.contains('귀여')) {
      return 'happy.png'; // 행복한 표정
    }
    
    if (lowerUserMessage.contains('놀라') || lowerUserMessage.contains('대박') ||
        lowerUserMessage.contains('어머') || lowerUserMessage.contains('와') ||
        lowerUserMessage.contains('헉') || lowerUserMessage.contains('어?')) {
      return 'surprise.png'; // 놀란 표정
    }
    
    // AI 응답 내용 분석
    if (lowerAiResponse.contains('위로') || lowerAiResponse.contains('괜찮') ||
        lowerAiResponse.contains('힘내') || lowerAiResponse.contains('도와드릴')) {
      return 'happy.png'; // 따뜻한 표정
    }
    
    if (lowerAiResponse.contains('축하') || lowerAiResponse.contains('잘했') ||
        lowerAiResponse.contains('멋져') || lowerAiResponse.contains('훌륭') ||
        lowerAiResponse.contains('대단') || lowerAiResponse.contains('완벽')) {
      return 'laugh.png'; // 웃는 표정
    }
    
    if (lowerAiResponse.contains('미안') || lowerAiResponse.contains('죄송') ||
        lowerAiResponse.contains('유감') || lowerAiResponse.contains('안타까')) {
      return 'sad.png'; // 미안한 표정
    }
    
    // 질문이나 궁금한 상황
    if (lowerAiResponse.contains('?') || lowerAiResponse.contains('궁금') ||
        lowerAiResponse.contains('어떤') || lowerAiResponse.contains('무엇')) {
      return 'surprise.png'; // 궁금한 표정
    }
    
    // 기본 표정
    return 'basic.png';
  }

  // autoStart 모드에서 서비스 초기화 완료 후 자동 시작을 스케줄링
  void _scheduleAutoStartAfterInit() {
    print('🔄 _scheduleAutoStartAfterInit 호출됨');
    
    // 500ms마다 서비스 상태를 체크하면서 준비되면 바로 시작
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      print('⏳ 자동시작 체크 (${timer.tick}/20): mounted=$mounted, _servicesInitialized=$_servicesInitialized');
      
      if (!mounted) {
        print('❌ Widget이 dispose됨 - 타이머 취소');
        timer.cancel();
        return;
      }
      
      if (timer.tick > 20) { // 10초 후 포기
        print('❌ 자동시작 타임아웃 - 타이머 취소');
        timer.cancel();
        if (mounted) {
          setState(() {
            _currentStatus = '서비스 준비에 시간이 걸리고 있어요. 음성 버튼을 직접 눌러보세요! 🎤';
            _currentAISpeech = '버튼을 눌러서 대화를 시작해주세요!';
          });
        }
        return;
      }
      
      if (_servicesInitialized && _voiceAssistantService != null && _voiceService != null) {
        print('✅ 모든 서비스 준비 완료! 자동 음성 인식 시작');
        timer.cancel();
        
        setState(() {
          _currentStatus = '음성 인식을 시작합니다... 🎤';
          _currentAISpeech = '버디가 준비 완료! 말씀해주세요 😊';
        });
        
        // 약간의 지연 후 시작 (UI 업데이트 시간 확보)
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            print('🎤 지연 후 _startListening 직접 호출');
            _startListening();
          }
        });
      }
    });
  }

  // autoStart 모드에서 안전하게 음성 인식 시작
  Future<void> _waitAndStartListening() async {
    print('🔄 _waitAndStartListening 시작');
    
    // 서비스가 완전히 초기화될 때까지 기다림
    for (int i = 0; i < 15; i++) { // 15번으로 증가
      await Future.delayed(const Duration(milliseconds: 300)); // 더 짧은 간격
      
      print('⏳ 서비스 상태 확인 (${i + 1}/15): mounted=$mounted, _servicesInitialized=$_servicesInitialized');
      
      if (!mounted) {
        print('❌ Widget이 dispose됨 - 중단');
        return;
      }
      
      if (_servicesInitialized && _voiceAssistantService != null && _voiceService != null) {
        print('✅ 모든 서비스 준비 완료!');
        
        // 추가 준비 시간
        setState(() {
          _currentStatus = '음성 인식을 시작합니다... 🎤';
          _currentAISpeech = '버디가 준비 완료! 말씀해주세요 😊';
        });
        
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) {
          print('🎤 autoStart 모드 - 서비스 초기화 완료 후 음성 인식 시작');
          await _startListening();
        }
        return;
      }
      
      print('⏳ 서비스 초기화 대기 중... (${i + 1}/15)');
    }
    
    // 15번 시도 후에도 초기화되지 않으면 에러 메시지
    print('❌ 서비스 초기화 실패');
    if (mounted) {
      setState(() {
        _currentStatus = '서비스 초기화에 실패했습니다. 음성 버튼을 직접 눌러주세요.';
        _currentAISpeech = '음성 버튼을 눌러 대화를 시작해주세요 🎤';
      });
    }
  }

  void _addSystemMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        message: message,
        isUser: false,
        isSystem: true,
        timestamp: DateTime.now(),
      ));
      // 시스템 메시지도 상단에 표시
      _currentAISpeech = message;
    });
    _scrollToBottom();
  }

  void _addUserMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        message: message,
        isUser: true,
        isSystem: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addAIMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        message: message,
        isUser: false,
        isSystem: false,
        timestamp: DateTime.now(),
      ));
      // AI 메시지도 상단에 표시 (음성 재생과 별개로)
      _currentAISpeech = message;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoRestartTimer?.cancel();
    _returnToWaitingTimer?.cancel(); // 대기 페이지 복귀 타이머도 정리
    _transcriptionSubscription?.cancel();
    _responseSubscription?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _scrollController.dispose();

    // 음성 비서 정리 - ref 대신 저장된 서비스 참조 사용
    if (_servicesInitialized && _voiceAssistantService != null) {
      try {
        _voiceAssistantService.endConversation();
      } catch (e) {
        print('음성 비서 정리 중 오류: $e');
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final hingeSpace = 20; // 힌지 공간
    final topHeight = (screenHeight / 2) - hingeSpace;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 상단 영역 (힌지 공간 위까지)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topHeight,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: _buildTopContent(),
            ),
          ),
          
          // 힌지 공간
          Positioned(
            top: topHeight,
            left: 0,
            right: 0,
            height: hingeSpace * 2, // 40px 총 높이
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.main100,
              ),
            ),
          ),
          
          // 하단 영역 (힌지 공간 아래)
          Positioned(
            top: topHeight + hingeSpace * 2,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              // padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.main200,
              ),
              child: Column(
                children: [
                  SizedBox(height: 6,),
                  // 상태 메시지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _currentStatus,
                      style: AppTypography.b3.copyWith(
                        color: AppColors.grey900,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 채팅 메시지 영역
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '고급 AI와 음성 대화',
                            style: AppTypography.h4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.autoStart ?
                            '자동 모드 - 연속 음성 대화' :
                            'LangChain 기반 지능형 대화 시스템',
                            style: AppTypography.b2.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        // 사용자 메시지와 AI 메시지 모두 표시
                        return ChatMessageWidget(message: message);
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 음성 입력 영역
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // 인식 모드 표시
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.autoStart ? Colors.green.shade50 : AppColors.main100,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: widget.autoStart ? Colors.green.shade300 : AppColors.main300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.autoStart ? Icons.auto_awesome : Icons.smart_toy,
                                size: 16,
                                color: widget.autoStart ? Colors.green.shade600 : AppColors.main600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.autoStart ? '자동 모드' : 'AI 모드',
                                style: AppTypography.b3.copyWith(
                                  color: widget.autoStart ? Colors.green.shade600 : AppColors.main600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: GestureDetector(
                            onTap: _toggleVoiceRecording,
                            child: AnimatedBuilder(
                              animation: _isListening ? _pulseAnimation :
                              _isProcessing ? _waveAnimation :
                              const AlwaysStoppedAnimation(1.0),
                              builder: (context, child) {
                                return Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isListening
                                          ? [Colors.red.shade400, Colors.red.shade600]
                                          : _isProcessing
                                          ? [Colors.orange.shade400, Colors.orange.shade600]
                                          : _isPlaying
                                          ? [Colors.blue.shade400, Colors.blue.shade600]
                                          : [AppColors.main500, AppColors.main600],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isListening ? Colors.red :
                                        _isProcessing ? Colors.orange :
                                        _isPlaying ? Colors.blue : AppColors.main500)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isListening
                                            ? Icons.stop
                                            : _isProcessing
                                            ? Icons.psychology
                                            : _isPlaying
                                            ? Icons.volume_up
                                            : Icons.mic,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isListening
                                            ? (widget.autoStart ? '음성 인식 중...' : '음성 인식 중지')
                                            : _isProcessing
                                            ? (_isProcessing && !widget.autoStart ? '강제 중지' : '생각 중...')
                                            : _isPlaying
                                            ? '재생 중...'
                                            : (widget.autoStart ? '자동 음성 대화' : '말하기'),
                                        style: AppTypography.s2.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 상단 영역 (틔운 메시지 + 얼굴)
  Widget _buildTopContent() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.hardEdge, // Stack만 클리핑
        children: [
          // 배경 이미지
          Positioned.fill(
            child: Image.asset(
              'assets/images/display/chat_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          // 틔운 마지막 메시지
          Positioned(
            left: 20,
            right: 20,
            top: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12),),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12), bottomLeft: Radius.circular(12),),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF131927).withOpacity(0.08),
                        offset: Offset(2, 8),
                        blurRadius: 8,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      _currentAISpeech.isEmpty 
                        ? (_isListening ? '(\u{1F3A7} 버디가 이야기를 듣고 있어요...)'
                           : _isProcessing ? '\u{1F4AD} 버디가 생각 중이에요...'
                           : _isPlaying ? '버디가 말하고 있어요...'
                           : '오늘 하루는 어떤가요?\n당신의 이야기를 듣고 싶어요! (❁´◡`❁)')
                        : _currentAISpeech,
                      style: AppTypography.b1.copyWith(
                        color: (_isListening || _isProcessing) ? AppColors.grey300 : AppColors.grey900,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 틔운 표정
          Positioned(
            left: 68,
            top: 132,
            child: Image.asset(
              'assets/images/display/$_currentExpression',
              filterQuality: FilterQuality.high,
              width: 224,
              height: 224,
              errorBuilder: (context, error, stackTrace) {
                // 이미지가 없으면 기본 표정 사용
                return Image.asset(
                  'assets/images/display/basic.png',
                  filterQuality: FilterQuality.high,
                  width: 224,
                  height: 224,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 채팅 메시지 데이터 클래스
class ChatMessage {
  final String message;
  final bool isUser;
  final bool isSystem;
  final DateTime timestamp;

  ChatMessage({
    required this.message,
    required this.isUser,
    required this.isSystem,
    required this.timestamp,
  });
}

/// 채팅 메시지 위젯
class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      // 시스템 메시지 - 더 깔끔한 디자인
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.main500,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.main200,
                width: 1,
              ),
            ),
            child: Text(
              message.message,
              style: AppTypography.b3.copyWith(
                color: AppColors.main600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // 사용자 메시지
    if (message.isUser) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.main500,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomRight: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.main300.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.message,
                  style: AppTypography.b2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 사용자 아바타
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.main200,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.main400,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.person,
                size: 20,
                color: AppColors.main600,
              ),
            ),
          ],
        ),
      );
    }

    // AI 메시지 - 고급 디자인
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 틔운 이름과 AI 배지
                Row(
                  children: [
                    Text(
                      '틔운 AI',
                      style: AppTypography.b3.copyWith(
                        color: AppColors.main700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.main500,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'LangChain',
                        style: AppTypography.c1.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 메시지 버블
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: AppColors.main200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.main100.withOpacity(0.5),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.message,
                        style: AppTypography.b2.copyWith(
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                            style: AppTypography.b3.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Icon(
                            Icons.smart_toy,
                            size: 14,
                            color: AppColors.main400,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
