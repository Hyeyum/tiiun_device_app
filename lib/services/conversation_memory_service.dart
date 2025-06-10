// lib/services/conversation_memory_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';

/// 대화 메모리 서비스
class ConversationMemoryService {
  final List<Message> _messages = [];

  /// 메시지 추가
  void addMessage(Message message) {
    _messages.add(message);
    // 메모리 관리: 최대 50개 메시지만 유지
    if (_messages.length > 50) {
      _messages.removeAt(0);
    }
  }

  /// 모든 메시지 가져오기
  List<Message> getAllMessages() {
    return List.unmodifiable(_messages);
  }

  /// 메시지 개수 가져오기
  int getMessageCount() {
    return _messages.length;
  }

  /// 메모리 초기화
  void clear() {
    _messages.clear();
  }

  /// 최근 N개 메시지 가져오기
  List<Message> getRecentMessages(int count) {
    if (_messages.length <= count) {
      return List.unmodifiable(_messages);
    }
    return List.unmodifiable(_messages.sublist(_messages.length - count));
  }

  /// 대화 히스토리를 문자열로 변환
  String getConversationHistory({int? maxMessages}) {
    final messages = maxMessages != null
        ? getRecentMessages(maxMessages)
        : getAllMessages();

    return messages.map((msg) {
      final sender = msg.sender == MessageSender.user ? "User" : "Assistant";
      return "$sender: ${msg.content}";
    }).join("\n");
  }
}

/// Provider 정의
final conversationMemoryServiceProvider = Provider<ConversationMemoryService>((ref) {
  return ConversationMemoryService();
});
