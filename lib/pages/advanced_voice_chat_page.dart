import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../services/voice_assistant_service.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';
import '../services/voice_service.dart';
import '../design_system/colors.dart';
import '../design_system/typography.dart';

class AdvancedVoiceChatPage extends ConsumerStatefulWidget {
  const AdvancedVoiceChatPage({super.key});

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

    // 초기화 및 환영 메시지
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final voiceAssistant = ref.read(voiceAssistantServiceProvider);
      final conversationService = ref.read(conversationServiceProvider);

      // 서비스 참조 저장
      _voiceAssistantService = voiceAssistant;
      _voiceService = ref.read(voiceServiceProvider);
      _servicesInitialized = true;

      // 새 대화 생성
      final userId = ref.read(authServiceProvider).getCurrentUserId();
      if (userId != null) {
        final conversation = await conversationService.createConversation(plantId: null);
        _conversationId = conversation.id;

        // 음성 비서 대화 시작
        await voiceAssistant.startConversation(_conversationId!);

        // 환영 메시지 추가
        _addAIMessage('안녕하세요! 저는 틔운의 AI 버디입니다. 아래 마이크 버튼을 눌러 음성으로 편하게 대화해보세요! 🎤');

        setState(() {
          _currentStatus = '음성 버튼을 눌러 대화를 시작하세요';
        });
      }
    } catch (e) {
      print('서비스 초기화 오류: $e');
      _addSystemMessage('서비스 초기화 중 오류가 발생했습니다: $e');
    }
  }

  void _toggleVoiceRecording() async {
    // mounted 체크 추가
    if (!mounted || !_servicesInitialized) return;

    if (_isListening) {
      // 음성 인식 중지
      await _stopListening();
    } else if (_isProcessing) {
      // 처리 중에는 새로운 요청 차단
      _addSystemMessage('현재 응답을 처리 중입니다. 잠시만 기다려주세요.');
      return;
    } else {
      // 음성 인식 시작
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    // mounted 체크 추가
    if (!mounted || !_servicesInitialized || _voiceAssistantService == null) return;

    try {
      final voiceAssistant = _voiceAssistantService;

      setState(() {
        _isListening = true;
        _currentTranscription = '';
        _currentStatus = '음성을 인식하고 있습니다... 말씀해주세요';
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
          setState(() {
            _isListening = false;
            _currentStatus = '음성 인식 오류: $error';
          });
          _pulseController.stop();
        },
        onDone: () {
          print('음성 인식 스트림 종료');
        },
      );

    } catch (e) {
      print('음성 인식 시작 오류: $e');
      setState(() {
        _isListening = false;
        _currentStatus = '음성 인식 시작 실패: $e';
      });
      _pulseController.stop();
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
      return;
    }

    // mounted 체크 추가
    if (!mounted || !_servicesInitialized || _voiceAssistantService == null) return;

    try {
      final voiceAssistant = _voiceAssistantService;

      setState(() {
        _isProcessing = true;
        _currentStatus = '틔운이 답변을 생각하고 있습니다...';
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
          setState(() {
            _isProcessing = false;
            _currentStatus = 'AI 응답 오류: $error';
          });
          _waveController.stop();
          _addSystemMessage('응답 생성 중 오류가 발생했습니다: $error');
        },
        onDone: () {
          print('AI 응답 처리 완료');
        },
      );

    } catch (e) {
      print('AI 응답 처리 시작 오류: $e');
      setState(() {
        _isProcessing = false;
        _currentStatus = '응답 처리 시작 실패: $e';
      });
      _waveController.stop();
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
        _currentStatus = '응답 완료! 음성을 재생합니다...';
      });

      _waveController.stop();

      // AI 메시지 추가
      _addAIMessage(aiText);

      // 음성 재생
      if (audioPath != null && audioPath.isNotEmpty) {
        _playAIResponse(audioPath);
      } else {
        setState(() {
          _currentStatus = '음성 버튼을 눌러 대화를 계속하세요';
        });
      }

    } else if (status == 'error') {
      // 오류
      setState(() {
        _isProcessing = false;
        _currentStatus = '오류: ${responseData['message']}';
      });
      _waveController.stop();
      _addSystemMessage('응답 생성 실패: ${responseData['message']}');
    }
  }

  void _playAIResponse(String audioPath) async {
    // mounted 체크 추가
    if (!mounted || !_servicesInitialized || _voiceService == null) return;

    try {
      setState(() {
        _isPlaying = true;
        _currentStatus = '틔운이 말하고 있습니다... 🎵';
      });

      final voiceService = _voiceService;
      await voiceService.playAudio(
        audioPath,
        isLocalFile: true,
        onComplete: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _currentStatus = '음성 버튼을 눌러 대화를 계속하세요';
            });
          }
        },
      );

    } catch (e) {
      print('음성 재생 오류: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentStatus = '음성 재생 오류: $e';
        });
      }
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
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.main100,
      body: Container(
        // 화면 절반 크기 적용 (폭은 전체, 높이는 위에서부터 절반)
        width: double.infinity,
        height: screenSize.height * 1,
        child: Column(
          children: [
            // 상태 표시 영역
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.main600, AppColors.main500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.main300.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // 헤더
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/motion_waiting');
                          },
                          icon: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '틔운 AI 버디 - 고급 음성 대화',
                            style: AppTypography.h4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Icon(
                          Icons.psychology,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 상태 메시지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentStatus,
                        style: AppTypography.b2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 채팅 메시지 영역
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 틔운 웃는 아바타
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.main100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.main300,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: SvgPicture.asset(
                            'assets/images/logos/tiiun_happy.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '고급 AI와 음성 대화',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.main700,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LangChain 기반 지능형 대화 시스템',
                      style: AppTypography.b2.copyWith(
                        color: AppColors.main500,
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
                  // 틔운의 말과 시스템 메시지만 표시, 사용자 메시지는 완전히 숨김
                  return ChatMessageWidget(message: message);
                },
              ),
            ),

            // 음성 입력 영역
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
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
                      color: AppColors.main100,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppColors.main300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 16,
                          color: AppColors.main600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI 모드',
                          style: AppTypography.b3.copyWith(
                            color: AppColors.main600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 음성 버튼
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleVoiceRecording,
                      child: AnimatedBuilder(
                        animation: _isListening ? _pulseAnimation :
                        _isProcessing ? _waveAnimation :
                        const AlwaysStoppedAnimation(1.0),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isListening ? _pulseAnimation.value : 1.0,
                            child: Container(
                              height: 60,
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
                                        ? '음성 인식 중지'
                                        : _isProcessing
                                        ? '생각 중...'
                                        : _isPlaying
                                        ? '재생 중...'
                                        : '말하기',
                                    style: AppTypography.b1.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
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

    // 사용자 메시지는 완전히 숨김 (표시하지 않음)
    if (message.isUser) {
      return const SizedBox.shrink();
    }

    // AI 메시지 - 고급 디자인
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 틔운 웃는 아바타
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.main100, AppColors.main200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.main400,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.main300.withOpacity(0.3),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SvgPicture.asset(
                  'assets/images/logos/tiiun_happy.svg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

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