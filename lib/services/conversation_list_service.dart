// lib/services/conversation_list_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'auth_service.dart';

// 대화 목록 서비스 Provider
final conversationListServiceProvider = Provider<ConversationListService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ConversationListService(FirebaseFirestore.instance, authService);
});

// 사용자 대화 목록 Provider (마지막 메시지 포함)
final userConversationsWithMessagesProvider = StreamProvider<List<ConversationWithLastMessage>>((ref) {
  final conversationListService = ref.watch(conversationListServiceProvider);
  return conversationListService.getConversationsWithLastMessages();
});

/// 마지막 메시지 정보를 포함한 대화 클래스
class ConversationWithLastMessage {
  final Conversation conversation;
  final Message? lastMessage;
  final int unreadCount;

  ConversationWithLastMessage({
    required this.conversation,
    this.lastMessage,
    this.unreadCount = 0,
  });

  /// 표시할 제목 (대화 제목 or 마지막 메시지 요약)
  String get displayTitle {
    if (lastMessage != null && lastMessage!.content.isNotEmpty) {
      final content = lastMessage!.content;
      if (content.length > 30) {
        return '${content.substring(0, 30)}...';
      }
      return content;
    }
    return conversation.title;
  }

  /// 표시할 시간
  String get displayTime {
    return lastMessage?.formattedTime ?? conversation.formattedTime;
  }

  /// 마지막 메시지 발신자
  String get lastSender {
    if (lastMessage == null) return '';
    return lastMessage!.sender == MessageSender.user ? '나' : 'AI';
  }
}

/// 대화 목록 관리 서비스
class ConversationListService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  ConversationListService(this._firestore, this._authService);

  /// 사용자의 대화 목록과 마지막 메시지를 함께 가져오기
  Stream<List<ConversationWithLastMessage>> getConversationsWithLastMessages() {
    final userId = _authService.getCurrentUserId();
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('user_id', isEqualTo: userId)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<ConversationWithLastMessage> conversationsWithMessages = [];

      for (final doc in snapshot.docs) {
        try {
          final conversation = Conversation.fromFirestore(doc);

          // 마지막 메시지 가져오기
          Message? lastMessage;
          int unreadCount = 0;

          if (conversation.lastMessageId != null) {
            // last_message_id가 있으면 해당 메시지 가져오기
            try {
              final messageDoc = await _firestore
                  .collection('messages')
                  .doc(conversation.lastMessageId!)
                  .get();

              if (messageDoc.exists) {
                lastMessage = Message.fromFirestore(messageDoc);
              }
            } catch (e) {
              debugPrint('마지막 메시지 가져오기 실패: $e');
            }
          } else {
            // last_message_id가 없으면 최신 메시지 검색
            try {
              final messagesSnapshot = await _firestore
                  .collection('messages')
                  .where('conversation_id', isEqualTo: conversation.id)
                  .orderBy('created_at', descending: true)
                  .limit(1)
                  .get();

              if (messagesSnapshot.docs.isNotEmpty) {
                lastMessage = Message.fromFirestore(messagesSnapshot.docs.first);
              }
            } catch (e) {
              debugPrint('최신 메시지 검색 실패: $e');
            }
          }

          // 읽지 않은 메시지 수 계산
          try {
            final unreadSnapshot = await _firestore
                .collection('messages')
                .where('conversation_id', isEqualTo: conversation.id)
                .where('sender', isEqualTo: 'agent')
                .where('is_read', isEqualTo: false)
                .get();

            unreadCount = unreadSnapshot.docs.length;
          } catch (e) {
            debugPrint('읽지 않은 메시지 수 계산 실패: $e');
          }

          conversationsWithMessages.add(ConversationWithLastMessage(
            conversation: conversation,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
          ));

        } catch (e) {
          debugPrint('대화 처리 중 오류: $e');
          continue;
        }
      }

      return conversationsWithMessages;
    });
  }

  /// 특정 대화의 읽지 않은 메시지를 모두 읽음 처리
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) return;

      // 읽지 않은 AI 메시지들을 모두 찾아서 읽음 처리
      final unreadMessages = await _firestore
          .collection('messages')
          .where('conversation_id', isEqualTo: conversationId)
          .where('sender', isEqualTo: 'agent')
          .where('is_read', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in unreadMessages.docs) {
          batch.update(doc.reference, {'is_read': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('대화 읽음 처리 실패: $e');
    }
  }

  /// 대화 삭제
  Future<void> deleteConversation(String conversationId) async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) return;

      // 대화 문서 삭제
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .delete();

      // 관련 메시지들 삭제
      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('conversation_id', isEqualTo: conversationId)
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('대화 삭제 완료: $conversationId');
    } catch (e) {
      debugPrint('대화 삭제 실패: $e');
      throw Exception('대화를 삭제할 수 없습니다: $e');
    }
  }

  /// 여러 대화 삭제
  Future<void> deleteMultipleConversations(List<String> conversationIds) async {
    try {
      if (conversationIds.isEmpty) return;

      final userId = _authService.getCurrentUserId();
      if (userId == null) return;

      for (final conversationId in conversationIds) {
        await deleteConversation(conversationId);
      }

      debugPrint('${conversationIds.length}개 대화 삭제 완료');
    } catch (e) {
      debugPrint('여러 대화 삭제 실패: $e');
      throw Exception('대화들을 삭제할 수 없습니다: $e');
    }
  }

  /// 모든 대화 삭제
  Future<void> deleteAllConversations() async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) return;

      // 사용자의 모든 대화 가져오기
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('user_id', isEqualTo: userId)
          .get();

      final conversationIds = conversationsSnapshot.docs.map((doc) => doc.id).toList();

      if (conversationIds.isNotEmpty) {
        await deleteMultipleConversations(conversationIds);
      }

      debugPrint('모든 대화 삭제 완료');
    } catch (e) {
      debugPrint('모든 대화 삭제 실패: $e');
      throw Exception('모든 대화를 삭제할 수 없습니다: $e');
    }
  }

  /// 대화 검색
  Future<List<ConversationWithLastMessage>> searchConversations(String query) async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) return [];

      if (query.trim().isEmpty) return [];

      // 대화 목록 가져오기
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('user_id', isEqualTo: userId)
          .orderBy('updated_at', descending: true)
          .get();

      List<ConversationWithLastMessage> searchResults = [];

      for (final doc in conversationsSnapshot.docs) {
        try {
          final conversation = Conversation.fromFirestore(doc);

          // 대화 제목이나 요약에서 검색
          bool titleMatch = conversation.title.toLowerCase().contains(query.toLowerCase());
          bool summaryMatch = conversation.summary?.toLowerCase().contains(query.toLowerCase()) ?? false;

          // 메시지 내용에서 검색
          bool messageMatch = false;
          final messagesSnapshot = await _firestore
              .collection('messages')
              .where('conversation_id', isEqualTo: conversation.id)
              .get();

          for (final messageDoc in messagesSnapshot.docs) {
            try {
              final message = Message.fromFirestore(messageDoc);
              if (message.content.toLowerCase().contains(query.toLowerCase())) {
                messageMatch = true;
                break;
              }
            } catch (e) {
              continue;
            }
          }

          if (titleMatch || summaryMatch || messageMatch) {
            // 마지막 메시지 가져오기
            Message? lastMessage;
            if (conversation.lastMessageId != null) {
              try {
                final messageDoc = await _firestore
                    .collection('messages')
                    .doc(conversation.lastMessageId!)
                    .get();

                if (messageDoc.exists) {
                  lastMessage = Message.fromFirestore(messageDoc);
                }
              } catch (e) {
                debugPrint('마지막 메시지 가져오기 실패: $e');
              }
            }

            searchResults.add(ConversationWithLastMessage(
              conversation: conversation,
              lastMessage: lastMessage,
            ));
          }
        } catch (e) {
          continue;
        }
      }

      return searchResults;
    } catch (e) {
      debugPrint('대화 검색 실패: $e');
      return [];
    }
  }

  /// 대화 통계 정보 가져오기
  Future<Map<String, dynamic>> getConversationStats() async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        return {
          'totalConversations': 0,
          'totalMessages': 0,
          'unreadMessages': 0,
          'todayConversations': 0,
        };
      }

      // 전체 대화 수
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('user_id', isEqualTo: userId)
          .get();

      int totalConversations = conversationsSnapshot.docs.length;

      // 오늘 생성된 대화 수
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final todayConversationsSnapshot = await _firestore
          .collection('conversations')
          .where('user_id', isEqualTo: userId)
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('created_at', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      int todayConversations = todayConversationsSnapshot.docs.length;

      // 전체 메시지 수와 읽지 않은 메시지 수
      int totalMessages = 0;
      int unreadMessages = 0;

      for (final conversationDoc in conversationsSnapshot.docs) {
        final conversationId = conversationDoc.id;

        // 해당 대화의 메시지 수
        final messagesSnapshot = await _firestore
            .collection('messages')
            .where('conversation_id', isEqualTo: conversationId)
            .get();

        totalMessages += messagesSnapshot.docs.length;

        // 읽지 않은 메시지 수
        final unreadSnapshot = await _firestore
            .collection('messages')
            .where('conversation_id', isEqualTo: conversationId)
            .where('sender', isEqualTo: 'agent')
            .where('is_read', isEqualTo: false)
            .get();

        unreadMessages += unreadSnapshot.docs.length;
      }

      return {
        'totalConversations': totalConversations,
        'totalMessages': totalMessages,
        'unreadMessages': unreadMessages,
        'todayConversations': todayConversations,
      };
    } catch (e) {
      debugPrint('대화 통계 조회 실패: $e');
      return {
        'totalConversations': 0,
        'totalMessages': 0,
        'unreadMessages': 0,
        'todayConversations': 0,
      };
    }
  }
}