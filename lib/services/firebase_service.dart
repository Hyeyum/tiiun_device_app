// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiiun/models/user_model.dart';
import 'package:tiiun/models/conversation_model.dart';
import 'package:tiiun/models/message_model.dart'; // Message 모델 import
import 'package:tiiun/services/auth_service.dart'; // Import AuthService
import 'package:tiiun/services/conversation_service.dart'; // Import ConversationService

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService(ref); // Pass ref to constructor
});

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Ref _ref; // Store Ref to access providers

  FirebaseService(this._ref); // Constructor to receive Ref

  // ========== 🔐 사용자 정보 관련 ==========

  String? get currentUserId => _auth.currentUser?.uid;
  User? get currentUser => _auth.currentUser;
  String? get currentUserEmail => _auth.currentUser?.email;

  // ========== 🔑 인증 관련 메서드 ==========

  // 회원가입
  Future<UserModel?> signUp({
    required String email,
    required String password,
    String userName = '',
  }) async {
    try {
      final authService = _ref.read(authServiceProvider); // Access AuthService
      final userCredential = await authService.registerWithEmailAndPassword(
        email,
        password,
        userName,
      );

      // authService.registerWithEmailAndPassword already handles creating the user document
      // and encoding the username.
      if (userCredential.user != null) {
        return await authService.getUserModel(userCredential.user!.uid);
      }
      return null;
    } catch (e) {
      print('회원가입 오류: $e');
      return null;
    }
  }

  // 로그인
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final authService = _ref.read(authServiceProvider); // Access AuthService
      final userCredential = await authService.loginWithEmailAndPassword(
        email,
        password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      return await authService.getUserModel(user.uid);
    } catch (e) {
      print('로그인 오류: $e');
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    final authService = _ref.read(authServiceProvider);
    await authService.logout();
  }

  // ========== 👤 사용자 정보 관리 ==========

  // 사용자 데이터 가져오기
  Future<UserModel?> getUserData(String uid) async {
    final authService = _ref.read(authServiceProvider);
    return await authService.getUserModel(uid);
  }

  // 현재 사용자 데이터 스트림
  Stream<UserModel?> getCurrentUserStream() {
    final authService = _ref.read(authServiceProvider);
    return authService.authStateChanges.asyncMap((user) async {
      if (user == null) return null;
      return await authService.getUserModel(user.uid);
    });
  }

  // 사용자 정보 업데이트
  Future<bool> updateUserData(UserModel userModel) async {
    try {
      final authService = _ref.read(authServiceProvider);
      await authService.updateUserModel(userModel);
      return true;
    } catch (e) {
      print('사용자 정보 업데이트 오류: $e');
      return false;
    }
  }

  // ========== 💬 대화 관리 (새로운 구조) ==========

  // 새 대화 생성
  Future<Conversation?> createConversation({
    String? title,
    String? agentId,
    String? specificId,
  }) async {
    try {
      if (currentUserId == null) return null;

      final conversationService = _ref.read(conversationServiceProvider);
      final newConversation = await conversationService.createConversation(
        title: title ?? '새 대화',
        agentId: agentId ?? 'default_agent',
        specificId: specificId,
      );
      return newConversation;
    } catch (e) {
      print('대화 생성 오류: $e');
      return null;
    }
  }

  // 메시지 추가
  Future<Message?> addMessage({
    required String conversationId,
    required String content,
    required String sender,
    String type = 'text',
  }) async {
    try {
      final conversationService = _ref.read(conversationServiceProvider);
      final newMessage = await conversationService.addMessage(
        conversationId: conversationId,
        content: content,
        sender: sender == 'user' ? MessageSender.user : MessageSender.agent,
        type: type == 'text' ? MessageType.text : MessageType.audio, // Corrected: MessageType.voice to MessageType.audio
      );
      return newMessage;
    } catch (e) {
      print('메시지 추가 오류: $e');
      return null;
    }
  }

  // 대화 목록 가져오기 (모델로 반환)
  Stream<List<Conversation>> getConversations() {
    final conversationService = _ref.read(conversationServiceProvider);
    return conversationService.getConversations();
  }

  // 메시지 목록 가져오기 (모델로 반환)
  Stream<List<Message>> getMessages(String conversationId) {
    final conversationService = _ref.read(conversationServiceProvider);
    return conversationService.getConversationMessages(conversationId);
  }

  // 특정 메시지 가져오기 (last_message_id로 사용)
  Future<Message?> getMessage(String messageId) async {
    try {
      // Direct Firestore fetch, assuming Message model is flexible enough
      final doc = await _firestore.collection('messages').doc(messageId).get();
      if (doc.exists) {
        return Message.fromFirestore(doc); // Use Message.fromFirestore
      }
      return null;
    } catch (e) {
      print('메시지 가져오기 오류: $e');
      return null;
    }
  }

  // 대화 삭제
  Future<bool> deleteConversation(String conversationId) async {
    try {
      final conversationService = _ref.read(conversationServiceProvider);
      await conversationService.deleteConversation(conversationId);
      return true;
    } catch (e) {
      print('대화 삭제 오류: $e');
      return false;
    }
  }

  // ========== 🎯 퀵액션 전용 메서드 ==========

  // 퀵액션별 메시지 매핑
  Map<String, String> get quickActionMessages => {
    '자랑거리': '나 자랑할 거 있어!',
    '고민거리': '요즘 고민이 있어서 이야기하고 싶어',
    '위로가 필요할 때': '나 좀 위로해줘',
    '시시콜콜': '심심해! 나랑 이야기하자!',
    '끝말 잇기': '끝말 잇기 하자!',
    '화가 나요': '나 너무 화나는 일 있어',
  };

  // 퀵액션으로 대화 시작 (간단하게)
  Future<Conversation?> startQuickActionConversation(String actionText) async {
    try {
      // 1. 새 대화 생성
      final conversation = await createConversation(
        title: actionText, // Use action text as title
        agentId: 'default_agent',
      );
      if (conversation == null) return null;

      // 2. 첫 메시지 추가 (사용자)
      final initialMessage = quickActionMessages[actionText] ?? '안녕하세요!';
      await addMessage(
        conversationId: conversation.id, // Use conversation.id
        content: initialMessage,
        sender: 'user',
      );

      return conversation;
    } catch (e) {
      print('퀵액션 대화 시작 오류: $e');
      return null;
    }
  }
}