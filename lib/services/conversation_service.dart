// lib/services/conversation_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart'; // Message 모델 import 추가
import 'auth_service.dart';
import '../utils/encoding_utils.dart'; // Ensure EncodingUtils is available
import '../utils/error_handler.dart'; // ✅ ErrorHandler import 추가

// 디버깅 로그 활성화 (개발 중에만 사용)
const bool _enableDebugLog = true;

// 대화 서비스 Provider
final conversationServiceProvider = Provider<ConversationService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ConversationService(FirebaseFirestore.instance, authService);
});

// 사용자 대화 목록 Provider
final userConversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final conversationService = ref.watch(conversationServiceProvider);
  return conversationService.getConversations();
});

class ConversationService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  ConversationService(this._firestore, this._authService);

  // 대화 목록 가져오기 (Stream) - 스키마에 맞게 수정
  Stream<List<Conversation>> getConversations() {
    final userId = _authService.getCurrentUserId();
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('user_id', isEqualTo: userId) // user_id로 수정
        .orderBy('updated_at', descending: true) // updated_at으로 수정
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // Firestore 데이터에서 객체 생성시 Conversation.fromFirestore에서 자동 디코딩 처리
        return Conversation.fromFirestore(doc);
      }).toList();
    });
  }

  // 대화 목록 가져오기 (Future) - 스키마에 맞게 수정
  Future<List<Conversation>> getUserConversations() async {
    final userId = _authService.getCurrentUserId();
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('conversations')
          .where('user_id', isEqualTo: userId) // user_id로 수정
          .orderBy('updated_at', descending: true) // updated_at으로 수정
          .get();

      return snapshot.docs.map((doc) {
        // Firestore 데이터에서 객체 생성시 Conversation.fromFirestore에서 자동 디코딩 처리
        return Conversation.fromFirestore(doc);
      }).toList();
    } catch (e) {
      debugPrint('대화 목록 가져오기 오류: $e');
      return [];
    }
  }

  // 대화 가져오기
  Future<Conversation?> getConversation(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!doc.exists) {
        return null;
      }

      // Firestore 데이터에서 객체 생성시 Conversation.fromFirestore에서 자동 디코딩 처리
      return Conversation.fromFirestore(doc);
    } catch (e) {
      debugPrint('대화 가져오기 실패: $e');
      return null;
    }
  }

  // 새 대화 생성 및 대화 ID 확인 로직 추가
  Future<Conversation> createConversation({
    String? title, // 대화 제목 추가
    String? agentId, // 에이전트 ID 추가  
    String? plantId, // plant_id 추가
    String? specificId,  // 특정 ID를 사용하고 싶을 때
  }) async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      final now = DateTime.now();

      // 실제 Firestore 스키마에 맞는 데이터
      final conversationData = {
        'user_id': userId,
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
        'last_message_id': null,
        'message_count': 0,
        'plant_id': plantId,
        'agent_id': agentId, // agentId 추가
        'title': title != null ? EncodingUtils.encodeToBase64(title) : null, // title 추가 (Base64 인코딩)
        'summary': null,
      };

      DocumentReference docRef;

      // 특정 ID를 요청한 경우 해당 ID로 문서 생성 시도
      if (specificId != null && specificId.isNotEmpty) {
        // 해당 ID의 문서가 존재하는지 확인
        final existingDoc = await _firestore
            .collection('conversations')
            .doc(specificId)
            .get();

        if (existingDoc.exists) {
          // 이미 존재하는 경우 해당 대화 반환
          debugPrint('이미 존재하는 대화 ID: $specificId');
          return Conversation.fromFirestore(existingDoc);
        } else {
          // 존재하지 않는 경우 새로 생성
          docRef = _firestore.collection('conversations').doc(specificId);
          await docRef.set(conversationData);
        }
      } else {
        // 새 문서 ID 자동 생성
        docRef = await _firestore
            .collection('conversations')
            .add(conversationData);
      }

      // 생성된 대화 반환
      final createdDoc = await docRef.get();
      return Conversation.fromFirestore(createdDoc);

    } catch (e) {
      debugPrint('대화 생성 오류: $e');
      throw Exception('대화를 생성할 수 없습니다: $e');
    }
  }

  // 대화에 메시지 추가 (Base64 인코딩 적용)
  Future<Message> addMessage({
    required String conversationId,
    required String content,
    required MessageSender sender,
    String? audioUrl,
    int? audioDuration,
    MessageType type = MessageType.text,
    List<MessageAttachment>? attachments, // 첨부파일 추가
  }) async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      // 대화 존재 여부 확인 (필요한 경우 생성)
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        // 대화가 존재하지 않으면 새로 생성
        debugPrint('대화가 존재하지 않아 새로 생성합니다: $conversationId');
        await createConversation(
          plantId: null,
          specificId: conversationId,
        );
      }

      // Message 모델에서 toFirestore 시 인코딩을 처리하므로, 여기서는 원본 텍스트 전달
      final newMessage = Message(
        id: '', // ID는 Firestore에서 생성됨
        conversationId: conversationId,
        userId: userId,
        content: content, // 원본 내용 전달, Message.toFirestore에서 인코딩
        sender: sender,
        createdAt: DateTime.now(),
        isRead: false,
        audioUrl: audioUrl,
        audioDuration: audioDuration,
        status: MessageStatus.sent,
        type: type,
        attachments: attachments ?? [], // 첨부파일 추가
      );

      // Firestore에 새 메시지 추가
      final messageRef = await _firestore
          .collection('messages')
          .add(newMessage.toFirestore()); // Message.toFirestore에서 인코딩

      // 대화 정보 업데이트 (스키마에 맞게 수정)
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'updated_at': Timestamp.fromDate(DateTime.now()), // updated_at 업데이트
        'last_message_id': messageRef.id, // last_message_id 업데이트
        'message_count': FieldValue.increment(1), // message_count 업데이트
      });

      // 메시지 객체 반환 (원본 내용 반환)
      return newMessage.copyWith(id: messageRef.id);
    } catch (e) {
      debugPrint('메시지 추가 오류: $e');
      throw Exception('메시지를 추가할 수 없습니다: $e');
    }
  }

  // 대화의 메시지 목록 가져오기 - 개선된 디코딩 버전
  Stream<List<Message>> getConversationMessages(String conversationId) {
    // ✅ conversationId 유효성 검사
    if (conversationId.isEmpty) {
      return Stream.error('Invalid conversation ID');
    }

    return _firestore
        .collection('messages')
        .where('conversation_id', isEqualTo: conversationId) // 필드명 반영
        .orderBy('created_at') // 필드명 반영
        .snapshots()
        .map((snapshot) {
      if (_enableDebugLog) {
        debugPrint('---------- 메시지 로드 시작 ----------');
        debugPrint('메시지 갯수: ${snapshot.docs.length}');
      }

      final messages = <Message>[];

      for (final doc in snapshot.docs) {
        try {
          // ✅ 각 메시지별로 개별 에러 처리
          final message = Message.fromFirestore(doc);
          messages.add(message);
        } catch (e) {
          debugPrint('메시지 변환 오류: $e, documentId: ${doc.id}');
          // ✅ 오류 발생한 메시지는 스킵하고 계속 진행
          continue;
        }
      }

      return messages;
    })
        .handleError((error) {
      debugPrint('메시지 스트림 오류: $error');
      throw ErrorHandler.handleException(error);
    });
  }

  // 대화 제목 업데이트 (스키마에 맞게 수정)
  Future<void> updateConversationTitle(String conversationId, String newTitle) async {
    try {
      // Base64 인코딩 적용
      final encodedTitle = EncodingUtils.encodeToBase64(newTitle);

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'title': encodedTitle,
        'updated_at': Timestamp.fromDate(DateTime.now()), // updated_at로 수정
      });
    } catch (e) {
      debugPrint('대화 제목 업데이트 오류: $e');
      throw Exception('대화 제목을 업데이트할 수 없습니다: $e');
    }
  }

  // 대화 요약 업데이트 (스키마에 맞게 수정)
  Future<void> updateConversationSummary(String conversationId, String summary) async {
    try {
      // Base64 인코딩 적용
      final encodedSummary = EncodingUtils.encodeToBase64(summary);

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'summary': encodedSummary,
        'updated_at': Timestamp.fromDate(DateTime.now()), // updated_at로 수정
      });
    } catch (e) {
      debugPrint('대화 요약 업데이트 오류: $e');
      throw Exception('대화 요약을 업데이트할 수 없습니다: $e');
    }
  }

  // 대화 태그 업데이트
  Future<void> updateConversationTags(String conversationId, List<String> tags) async {
    try {
      // 모든 태그에 Base64 인코딩 적용
      final encodedTags = tags.map((tag) => EncodingUtils.encodeToBase64(tag)).toList();

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'tags': encodedTags,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('대화 태그 업데이트 오류: $e');
      throw Exception('대화 태그를 업데이트할 수 없습니다: $e');
    }
  }

  // 대화 감정 점수 업데이트
  Future<void> updateConversationMoodScore(String conversationId, double moodScore, bool moodChanged) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'averageMoodScore': moodScore,
        'moodChangeDetected': moodChanged,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('대화 감정 점수 업데이트 오류: $e');
      throw Exception('대화 감정 점수를 업데이트할 수 없습니다: $e');
    }
  }

  // 대화 완료 상태 업데이트
  Future<void> completeConversation(String conversationId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isCompleted': true,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('대화 완료 상태 업데이트 오류: $e');
      throw Exception('대화 완료 상태를 업데이트할 수 없습니다: $e');
    }
  }

  // 대화 삭제
  Future<void> deleteConversation(String conversationId) async {
    try {
      // 대화 문서 삭제
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .delete();

      // 관련 메시지 삭제
      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('conversation_id', isEqualTo: conversationId) // 필드명 반영
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('대화 삭제 오류: $e');
      throw Exception('대화를 삭제할 수 없습니다: $e');
    }
  }

  // 여러 대화 삭제 (새로 추가된 메서드)
  Future<void> deleteMultipleConversations(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return;

    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      // Firestore 배치 처리를 위한 준비
      int batchCount = 0;
      WriteBatch batch = _firestore.batch();

      // 각 대화 ID에 대해 처리
      for (final conversationId in conversationIds) {
        // 대화 문서 참조
        final conversationRef = _firestore.collection('conversations').doc(conversationId);

        // 대화 문서 삭제 작업 추가
        batch.delete(conversationRef);
        batchCount++;

        // 관련 메시지 검색
        final messagesSnapshot = await _firestore
            .collection('messages')
            .where('conversation_id', isEqualTo: conversationId) // 필드명 반영
            .get();

        // 각 메시지 삭제 작업 추가
        for (final messageDoc in messagesSnapshot.docs) {
          batch.delete(messageDoc.reference);
          batchCount++;

          // Firestore 배치 작업은 500개로 제한되어 있으므로 400개마다 배치 실행 후 새로운 배치 생성
          if (batchCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      // 남은 배치 작업 실행
      if (batchCount > 0) {
        await batch.commit();
      }

      debugPrint('${conversationIds.length}개의 대화가 삭제되었습니다.');
    } catch (e) {
      debugPrint('여러 대화 삭제 오류: $e');
      throw Exception('대화를 삭제할 수 없습니다: $e');
    }
  }

  // 메시지 읽음 상태 업데이트
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      // 읽지 않은 메시지 조회
      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('conversation_id', isEqualTo: conversationId) // 필드명 반영
          .where('isRead', isEqualTo: false)
          .where('sender', isEqualTo: MessageSender.agent.toString().split('.').last)
          .get();

      if (messagesSnapshot.docs.isEmpty) {
        return; // 읽지 않은 메시지가 없음
      }

      // 메시지 읽음 상태 일괄 업데이트
      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('메시지 읽음 상태 업데이트 오류: $e');
      throw Exception('메시지 읽음 상태를 업데이트할 수 없습니다: $e');
    }
  }

  // 모든 대화 삭제
  Future<void> deleteAllConversations() async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      // 사용자의 모든 대화 가져오기 (스키마에 맞게 수정)
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('user_id', isEqualTo: userId) // user_id로 수정
          .get();

      // 대화가 없으면 종료
      if (conversationsSnapshot.docs.isEmpty) {
        return;
      }

      // 모든 대화 ID 목록
      final conversationIds = conversationsSnapshot.docs.map((doc) => doc.id).toList();

      // 여러 대화 삭제 메서드 호출 (배치 처리 최적화)
      await deleteMultipleConversations(conversationIds);

      debugPrint('모든 대화가 삭제되었습니다.');
    } catch (e) {
      debugPrint('모든 대화 삭제 오류: $e');
      throw Exception('모든 대화를 삭제할 수 없습니다: $e');
    }
  }

  // 인코딩 문제 해결을 위한 데이터 정비 메소드
  Future<Map<String, dynamic>> fixConversationEncodings(String conversationId) async {
    try {
      int messagesFixed = 0;
      int fieldsFixed = 0;

      // 1. 대화 정보 가져오기
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        throw Exception('대화를 찾을 수 없습니다: $conversationId');
      }

      // 2. 대화 필드 정비
      final data = conversationDoc.data()!;
      Map<String, dynamic> updates = {};

      // 제목 정비
      if (data['title'] != null) {
        final title = data['title'] as String;
        // 제목이 깨져있거나 Base64가 아닌 경우 재인코딩
        if (!EncodingUtils.isBase64Encoded(title) || EncodingUtils.isCorruptedText(title)) {
          // 복구 시도 후 재인코딩
          final fixedTitle = EncodingUtils.tryAllFixMethods(title);
          updates['title'] = EncodingUtils.encodeToBase64(fixedTitle);
          fieldsFixed++;
        }
      }

      // 마지막 메시지 정비 (lastMessage)
      if (data['lastMessage'] != null && (data['lastMessage'] as String).isNotEmpty) {
        final lastMessage = data['lastMessage'] as String;
        if (!EncodingUtils.isBase64Encoded(lastMessage) || EncodingUtils.isCorruptedText(lastMessage)) {
          final fixedLastMessage = EncodingUtils.tryAllFixMethods(lastMessage);
          updates['lastMessage'] = EncodingUtils.encodeToBase64(fixedLastMessage);
          fieldsFixed++;
        }
      }

      // 요약 정비
      if (data['summary'] != null) {
        final summary = data['summary'] as String;
        if (!EncodingUtils.isBase64Encoded(summary) || EncodingUtils.isCorruptedText(summary)) {
          final fixedSummary = EncodingUtils.tryAllFixMethods(summary);
          updates['summary'] = EncodingUtils.encodeToBase64(fixedSummary);
          fieldsFixed++;
        }
      }

      // 태그 정비
      if (data['tags'] != null) {
        final tags = (data['tags'] as List<dynamic>).map((e) => e.toString()).toList();
        List<String> updatedTags = [];
        bool tagsNeedUpdate = false;

        for (final tag in tags) {
          if (!EncodingUtils.isBase64Encoded(tag) || EncodingUtils.isCorruptedText(tag)) {
            final fixedTag = EncodingUtils.tryAllFixMethods(tag);
            updatedTags.add(EncodingUtils.encodeToBase64(fixedTag));
            tagsNeedUpdate = true;
          } else {
            updatedTags.add(tag);
          }
        }

        if (tagsNeedUpdate) {
          updates['tags'] = updatedTags;
          fieldsFixed++;
        }
      }

      // 대화 업데이트 필요시 실행
      if (updates.isNotEmpty) {
        updates['updatedAt'] = DateTime.now();
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .update(updates);

        debugPrint('대화 정보 인코딩 정비 완료: $fieldsFixed 필드 수정');
      }

      // 3. 메시지 정비
      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('conversation_id', isEqualTo: conversationId) // 필드명 반영
          .get();

      for (final messageDoc in messagesSnapshot.docs) {
        final messageData = messageDoc.data();
        final content = messageData['content'] as String? ?? '';

        if (content.isNotEmpty) {
          // 내용이 Base64가 아니거나, 또는 Base64지만 깨진 경우 재인코딩
          if (!EncodingUtils.isBase64Encoded(content) || EncodingUtils.isCorruptedText(content)) {
            try {
              final fixedContent = EncodingUtils.tryAllFixMethods(content);
              final encodedContent = EncodingUtils.encodeToBase64(fixedContent);

              await _firestore
                  .collection('messages')
                  .doc(messageDoc.id)
                  .update({
                'content': encodedContent,
                'updatedAt': DateTime.now(),
              });

              messagesFixed++;
            } catch (e) {
              debugPrint('메시지 정비 오류 (${messageDoc.id}): $e');
            }
          }
        }
      }

      debugPrint('인코딩 정비 완료 - 대화: $conversationId, 메시지: $messagesFixed개');

      return {
        'conversationId': conversationId,
        'fieldsFixed': fieldsFixed,
        'messagesFixed': messagesFixed,
        'totalFixed': fieldsFixed + messagesFixed,
      };
    } catch (e) {
      debugPrint('인코딩 정비 오류: $e');
      throw Exception('인코딩을 정비할 수 없습니다: $e');
    }
  }

  // 모든 대화 정보 인코딩 정비
  Future<Map<String, dynamic>> fixAllConversationsEncodings() async {
    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      // 모든 대화 가져오기 (스키마에 맞게 수정)
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('user_id', isEqualTo: userId) // user_id로 수정
          .get();

      int totalConversations = conversationsSnapshot.docs.length;
      int fixedConversations = 0;
      int totalFieldsFixed = 0;
      int totalMessagesFixed = 0;
      List<String> failedConversations = [];

      debugPrint('전체 인코딩 정비 시작: $totalConversations개 대화');

      for (final doc in conversationsSnapshot.docs) {
        try {
          final result = await fixConversationEncodings(doc.id);

          totalFieldsFixed += (result['fieldsFixed'] as num).toInt();
          totalMessagesFixed += (result['messagesFixed'] as num).toInt();

          if (result['totalFixed'] > 0) {
            fixedConversations++;
          }
        } catch (e) {
          debugPrint('대화 정비 실패 (${doc.id}): $e');
          failedConversations.add(doc.id);
        }
      }

      return {
        'totalConversations': totalConversations,
        'fixedConversations': fixedConversations,
        'totalFieldsFixed': totalFieldsFixed,
        'totalMessagesFixed': totalMessagesFixed,
        'totalFixed': totalFieldsFixed + totalMessagesFixed,
        'failedConversations': failedConversations,
      };
    } catch (e) {
      debugPrint('전체 인코딩 정비 오류: $e');
      throw Exception('모든 대화의 인코딩을 정비할 수 없습니다: $e');
    }
  }
}