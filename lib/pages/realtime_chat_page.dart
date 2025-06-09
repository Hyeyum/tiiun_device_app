// lib/pages/realtime_chat_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Realtime Chat AI',
          style: AppTypography.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.main800,
        elevation: 0,
        actions: [
          // 연결 상태 표시
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          
          // 메뉴
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'conversation_list':
                  Navigator.pushNamed(context, '/conversation_list');
                  break;
                case 'sensor_monitor':
                  Navigator.pushNamed(context, '/sensor_monitor');
                  break;
                case 'voice_settings':
                  Navigator.pushNamed(context, '/voice_settings');
                  break;
                case 'langchain_test':
                  Navigator.pushNamed(context, '/langchain_test');
                  break;
                case 'end_conversation':
                  _endConversation();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'conversation_list',
                child: ListTile(
                  leading: Icon(Icons.chat_bubble_outline),
                  title: Text('대화 목록'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'sensor_monitor',
                child: ListTile(
                  leading: Icon(Icons.sensors),
                  title: Text('센서 모니터링'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'voice_settings',
                child: ListTile(
                  leading: Icon(Icons.record_voice_over),
                  title: Text('목소리 설정'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'langchain_test',
                child: ListTile(
                  leading: Icon(Icons.psychology),
                  title: Text('LangChain 테스트'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'end_conversation',
                child: ListTile(
                  leading: Icon(Icons.stop),
                  title: Text('대화 종료'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('로그아웃'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      
      body: Column(
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
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Firebase Realtime Database 트리거 대기 중...',
                          style: AppTypography.b1.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '경로: $_triggerPath\n값: $_triggerValue',
                          style: AppTypography.b3.copyWith(
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      // 틔운의 말만 나오도록 사용자 메시지는 표시하지 않음
                      if (message.isUser) {
                        return const SizedBox.shrink(); // 사용자 메시지 UI 숨기기
                      }
                      return ChatMessageWidget(message: message);
                    },
                  ),
          ),
          
          // TTS 테스트 버튼
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _testTTS,
              icon: Icon(Icons.volume_up),
              label: Text('음성 테스트'),
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
      // 시스템 메시지
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.message,
          style: AppTypography.b3.copyWith(
            color: Colors.grey.shade700,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 사용자 메시지는 여기에서 표시되지 않음 (위의 ListView.builder에서 이미 걸러짐)
    // AI 메시지
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // AI 메시지는 항상 왼쪽 정렬
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.main800,
            child: Text( // 틔운 이모지
              '🌿', // 방긋 웃는 잎사귀 이모지
              style: TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200, // AI 메시지 배경색
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: AppTypography.b2.copyWith(
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: AppTypography.b3.copyWith(
                      color: Colors.grey.shade600,
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
}