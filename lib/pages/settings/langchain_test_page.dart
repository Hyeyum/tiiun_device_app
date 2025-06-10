import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiiun/design_system/colors.dart';
import 'package:tiiun/design_system/typography.dart';
import 'package:tiiun/services/langchain_service.dart';
import 'package:tiiun/services/voice_assistant_service.dart';
import 'package:uuid/uuid.dart';

class LangChainTestPage extends ConsumerStatefulWidget {
  const LangChainTestPage({super.key});

  @override
  ConsumerState<LangChainTestPage> createState() => _LangChainTestPageState();
}

class _LangChainTestPageState extends ConsumerState<LangChainTestPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<TestMessage> _messages = [];
  bool _isLoading = false;
  final String _conversationId = const Uuid().v4();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(TestMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final langchainService = ref.read(langchainServiceProvider);
      final response = await langchainService.getResponse(
        conversationId: _conversationId,
        userMessage: message,
      );

      setState(() {
        _messages.add(TestMessage(
          text: response.text,
          isUser: false,
          timestamp: DateTime.now(),
          voiceFileUrl: response.voiceFileUrl,
          ttsSource: response.ttsSource,
        ));
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(TestMessage(
          text: '오류가 발생했습니다: $e',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _testSentimentAnalysis() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final langchainService = ref.read(langchainServiceProvider);
      final sentiment = await langchainService.analyzeSentimentWithLangChain(message);

      setState(() {
        _messages.add(TestMessage(
          text: '감정 분석 결과:\n'
              '점수: ${sentiment['score']}\n'
              '라벨: ${sentiment['label']}\n'
              '감정: ${sentiment['emotionType']}\n'
              '신뢰도: ${sentiment['confidence']}',
          isUser: false,
          timestamp: DateTime.now(),
          isAnalysis: true,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(TestMessage(
          text: '감정 분석 실패: $e',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'LangChain 테스트',
          style: AppTypography.b2.withColor(Colors.white),
        ),
        backgroundColor: AppColors.main800,
        elevation: 0,
      ),
      body: Column(
        children: [
          // LangChain 상태 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.main600, AppColors.main500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🚀 GPT-4o 모델',
                        style: AppTypography.b3.withColor(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'OpenAI GPT-4o 연결됨',
                  style: AppTypography.label.withColor(Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '최신 멀티모달 AI • 향상된 추론력 • 고급 감정 분석',
                  style: AppTypography.b2.withColor(Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),

          // 메시지 영역
          Expanded(
            child: _messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.eco, // 식물 아이콘 추가
                    size: 64,
                    color: AppColors.grey400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GPT-4o AI와 대화해보세요!',
                    style: AppTypography.label.withColor(AppColors.grey600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '고급 감정 분석 • 깊이 있는 상담 • 맞춤형 솔루션 • 🌱 식물 페르소나',
                    style: AppTypography.c2.withColor(AppColors.grey500),
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
                return TestMessageWidget(message: message);
              },
            ),
          ),

          // 로딩 표시
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'GPT-4o가 고급 분석을 수행하고 있습니다...',
                    style: AppTypography.b2.withColor(AppColors.grey600),
                  ),
                ],
              ),
            ),

          // 입력 영역
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.grey200),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: '메시지를 입력하세요...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.grey300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppColors.main500),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: Icon(
                        Icons.send,
                        color: _isLoading ? AppColors.grey400 : AppColors.main500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testSentimentAnalysis,
                  icon: Icon(Icons.psychology_outlined),
                  label: Text('GPT-4o 고급 감정 분석'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main100,
                    foregroundColor: AppColors.main700,
                    minimumSize: Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

class TestMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? voiceFileUrl;
  final String? ttsSource;
  final bool isError;
  final bool isAnalysis;

  TestMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.voiceFileUrl,
    this.ttsSource,
    this.isError = false,
    this.isAnalysis = false,
  });
}

class TestMessageWidget extends StatelessWidget {
  final TestMessage message;

  const TestMessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: message.isError
                    ? Colors.red.shade100
                    : message.isAnalysis
                    ? Colors.purple.shade100
                    : message.ttsSource?.contains('plant') == true
                    ? Colors.green.shade100  // 식물 페르소나 배경
                    : AppColors.main100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                message.isError
                    ? Icons.error_outline
                    : message.isAnalysis
                    ? Icons.psychology
                    : message.ttsSource?.contains('plant') == true
                    ? Icons.eco  // 식물 페르소나 아이콘
                    : Icons.smart_toy,
                size: 18,
                color: message.isError
                    ? Colors.red.shade700
                    : message.isAnalysis
                    ? Colors.purple.shade700
                    : message.ttsSource?.contains('plant') == true
                    ? Colors.green.shade700  // 식물 페르소나 색상
                    : AppColors.main700,
              ),
            ),

          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppColors.main500
                    : message.isError
                    ? Colors.red.shade50
                    : message.isAnalysis
                    ? Colors.purple.shade50
                    : message.ttsSource?.contains('plant') == true
                    ? Colors.green.shade50  // 식물 페르소나 메시지 배경
                    : AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: AppTypography.b2.withColor(
                      message.isUser ? Colors.white : AppColors.grey900,
                    ),
                  ),
                  if (message.voiceFileUrl != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: message.ttsSource?.contains('plant') == true
                            ? Colors.green.shade200  // 식물 페르소나 TTS 태그
                            : AppColors.main200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        message.ttsSource?.contains('plant') == true
                            ? '🌱 식물 AI: ${message.ttsSource?.replaceAll('_plant', '')}'
                            : '🔊 TTS: ${message.ttsSource}',
                        style: AppTypography.b3.withColor(
                          message.ttsSource?.contains('plant') == true
                              ? Colors.green.shade800
                              : AppColors.main800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (message.isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppColors.main200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person,
                size: 18,
                color: AppColors.main800,
              ),
            ),
        ],
      ),
    );
  }
}
