// lib/pages/realtime_chat_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart'; // SVG 지원 추가
import '../services/realtime_database_service.dart';
import '../services/auth_service.dart';
import '../services/voice_service.dart'; // 추가
import '../services/remote_config_service.dart'; // Remote Config 서비스 추가
import '../design_system/colors.dart';
import '../design_system/typography.dart';

class RealtimeChatPage extends ConsumerStatefulWidget {
  const RealtimeChatPage({super.key});

  @override
  ConsumerState<RealtimeChatPage> createState() => _RealtimeChatPageState();
}

class _RealtimeChatPageState extends ConsumerState<RealtimeChatPage> {
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isListening = false;
  bool _isConnected = false;
  String _connectionStatus = '연결 대기 중...';

  // Firebase Remote Config에서 설정값 가져오기
  String _triggerPath = 'conversation_trigger';
  String _triggerValue = 'start_conversation';
  String _resetValue = 'idle';

  @override
  void initState() {
    super.initState();

    // 페이지 로드 시 즉시 사용자가 다가왔다는 인사말 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addAIMessage('안녕하세요! 움직임이 감지되어 대화를 시작합니다. 무엇을 도와드릴까요?');
    });

    _loadConfigAndStartListening();
  }

  /// Firebase Remote Config에서 설정을 로드하고 트리거 리스닝 시작
  Future<void> _loadConfigAndStartListening() async {
    try {
      // 🎯 개선된 Remote Config 서비스 사용
      final remoteConfigService = ref.read(remoteConfigServiceProvider);
      await remoteConfigService.initialize(); // 초기화 확실히 실행

      final triggerConfig = remoteConfigService.getTriggerConfig();
      _triggerPath = triggerConfig['trigger_path'] ?? 'conversation_trigger';
      _triggerValue = triggerConfig['trigger_value'] ?? 'start_conversation';
      _resetValue = triggerConfig['reset_value'] ?? 'idle';

      print('🔧 Trigger Settings - Path: $_triggerPath, Value: $_triggerValue, Reset: $_resetValue');

      // OpenAI API 키 확인
      final apiKey = remoteConfigService.getOpenAIApiKey();
      if (apiKey.isNotEmpty) {
        print('✅ OpenAI API Key loaded from Remote Config');
        _addSystemMessage('✅ OpenAI API 키가 설정되었습니다.');
      } else {
        print('⚠️ OpenAI API Key not found - using device speech recognition');
        _addSystemMessage('⚠️ OpenAI API 키가 설정되지 않았습니다. 디바이스 음성 인식을 사용합니다.');
      }

      // 트리거 리스닝 시작
      _startTriggerListening();

    } catch (e) {
      print('❌ Error loading config: $e');
      _addSystemMessage('설정 로드 실패: $e');

      // 기본값으로 시작
      _startTriggerListening();
    }
  }

  /// Firebase Realtime Database 트리거 리스닝 시작
  void _startTriggerListening() {
    final realtimeDbService = ref.read(realtimeDbServiceProvider);

    setState(() {
      _isConnected = true;
      _connectionStatus = '트리거 대기 중...';
    });

    _addSystemMessage('🔗 Firebase Realtime Database에 연결되었습니다.');
    _addSystemMessage('📡 경로 "$_triggerPath"에서 값 "$_triggerValue" 감지 대기 중...');

    try {
      final triggerStream = realtimeDbService.listenForTrigger(
        triggerPath: _triggerPath,
        triggerValue: _triggerValue,
        resetValue: _resetValue,
      );

      triggerStream.listen(
            (data) => _handleTriggerEvent(data),
        onError: (error) => _handleTriggerError(error),
      );

    } catch (e) {
      _addSystemMessage('❌ 트리거 리스닝 시작 실패: $e');
      setState(() {
        _isConnected = false;
        _connectionStatus = '연결 실패';
      });
    }
  }

  /// 트리거 이벤트 처리
  void _handleTriggerEvent(Map<String, dynamic> data) {
    setState(() {
      _connectionStatus = data['status'] ?? '알 수 없음';
    });

    switch (data['status']) {
      case 'trigger_detected':
        _addSystemMessage('🎯 트리거 감지! 대화를 시작합니다...');
        setState(() {
          _isListening = true;
        });
        break;

      case 'conversation_started':
        _addSystemMessage('💬 대화가 시작되었습니다.');
        break;

      case 'ai_greeting':
        _addAIMessage(data['message'] ?? '안녕하세요!');
        break;

      case 'listening_started':
        _addSystemMessage('🎤 음성 인식을 시작합니다...');
        break;

      case 'user_message':
      // 사용자 메시지는 추가하지만 UI에서 숨기기 위해 isUser=true 그대로 유지
        _addUserMessage(data['message'] ?? '');
        break;

      case 'ai_message':
        _addAIMessage(data['message'] ?? '');
        break;

      case 'ai_processing':
        _addSystemMessage('🤖 AI가 응답을 생성하고 있습니다...');
        break;

      case 'conversation_ending':
        _addAIMessage(data['message'] ?? '대화를 종료합니다.');
        break;

      case 'conversation_ended':
        _addSystemMessage('✅ 대화가 종료되었습니다.');
        setState(() {
          _isListening = false;
        });
        break;

      case 'error':
      case 'conversation_error':
      case 'voice_conversation_error':
      case 'interaction_error':
      case 'ai_response_error':
        _addSystemMessage('❌ 오류: ${data['message'] ?? '알 수 없는 오류'}');
        setState(() {
          _isListening = false;
        });
        break;

      case 'value_changed':
      // 값 변경 시 UI 업데이트 (선택적)
        if (data['value'] != null) {
          setState(() {
            _connectionStatus = '값: ${data['value']} (대화 ${data['conversation_active'] == true ? '활성' : '비활성'})';
          });
        }
        break;

      default:
      // 기타 상태 정보
        print('📊 Status Update: ${data['status']} - ${data['message'] ?? ''}');
    }
  }

  /// 트리거 에러 처리
  void _handleTriggerError(dynamic error) {
    _addSystemMessage('❌ 트리거 에러: $error');
    setState(() {
      _isConnected = false;
      _connectionStatus = '연결 오류';
      _isListening = false;
    });
  }

  /// 시스템 메시지 추가
  void _addSystemMessage(String message) {
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

  /// 사용자 메시지 추가
  void _addUserMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        message: message,
        isUser: true, // isUser는 true로 유지하여 실제 사용자 메시지임을 나타냄.
        isSystem: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  /// AI 메시지 추가
  void _addAIMessage(String message) {
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

  /// 채팅 목록을 맨 아래로 스크롤
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

  /// 수동 대화 종료
  void _endConversation() async {
    final realtimeDbService = ref.read(realtimeDbServiceProvider);
    await realtimeDbService.endConversation();
    _addSystemMessage('🛑 대화를 수동으로 종료했습니다.');
  }

  /// 로그아웃
  void _logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  /// TTS 테스트
  Future<void> _testTTS() async {
    try {
      final voiceService = ref.read(voiceServiceProvider);
      await voiceService.speak('안녕하세요! 음성 어시스턴트가 정상적으로 작동하고 있습니다.');

      _addSystemMessage('🔊 TTS 테스트 완료');
    } catch (e) {
      _addSystemMessage('❌ TTS 테스트 실패: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.main500,
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
                color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: _isConnected ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.wifi : Icons.wifi_off,
                        color: _isConnected ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _connectionStatus,
                          style: AppTypography.b2.copyWith(
                            color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // 대기 페이지로 돌아가기 버튼
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/motion_waiting');
                        },
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppColors.main600,
                        ),
                        tooltip: '대기 페이지로 돌아가기',
                      ),
                    ],
                  ),

                  if (user != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '사용자: ${user.email ?? '알 수 없음'}',
                      style: AppTypography.b3.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],

                  if (_isListening) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.mic,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '음성 대화 진행 중...',
                          style: AppTypography.b3.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
                      '틔운이 대화를 준비하고 있어요!',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.main700,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '곧 인사를 드릴게요 😊',
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

            // 대기 페이지로 돌아가기 버튼
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/motion_waiting');
                },
                icon: Icon(Icons.arrow_back),
                label: Text('대기 페이지로 돌아가기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main500,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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

    // AI 메시지
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // AI 메시지는 항상 왼쪽 정렬
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 틔운 웃는 아바타
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.main100,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.main300,
                width: 2,
              ),
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
                // 틔운 이름
                Text(
                  '틔운',
                  style: AppTypography.b3.copyWith(
                    color: AppColors.main700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),

                // 메시지 버블
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: AppColors.main200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.main100.withOpacity(0.3),
                        blurRadius: 4,
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
                      const SizedBox(height: 6),
                      Text(
                        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.b3.copyWith(
                          color: Colors.grey.shade500,
                        ),
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
