// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../utils/encoding_utils.dart'; // Import for encoding/decoding username

// Provider for the auth service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider for the current user
final currentUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Provider for the current user model
final currentUserModelProvider = FutureProvider<UserModel?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user != null) {
    return ref.watch(authServiceProvider).getUserModel(user.uid);
  }
  return null;
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    return _auth.currentUser != null;
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, String username) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!.uid, email, username);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(String uid, String email, String username) async {
    final now = DateTime.now();
    // username을 Base64로 인코딩
    final encodedUsername = EncodingUtils.encodeToBase64(username); //

    await _firestore.collection('users').doc(uid).set({
      'user_name': encodedUsername, // user_name (스키마 반영)
      'email': email,
      'phoneNumber': null,
      'birthDate': null,
      'profile_image_url': null, // profile_image_url (스키마 반영)
      // moodTrackingEnabled 필드는 스키마에 없으므로 제거 (혹은 모델에서만 사용)
      'preferred_voice': 'default', // preferred_voice (스키마 반영)
      'notification_yn': true, // notification_yn (스키마 반영)
      'dailyCheckInReminder': false, // 스키마에 없지만 모델에 있으므로 일단 유지
      'weeklySummaryEnabled': true, // 스키마에 없지만 모델에 있으므로 일단 유지
      'created_at': now, // created_at (스키마 반영)
      // 'updatedAt': now, // updatedAt은 스키마에 없으므로 제거
      'language': 'ko', // language (스키마 반영)
      'preferred_activities': [], // preferred_activities (스키마 반영)
      'use_whisper_api_yn': false, // use_whisper_api_yn (스키마 반영)
      'theme_mode': 'light', // theme_mode (스키마 반영)
      'auto_save_conversations_yn': true, // auto_save_conversations_yn (스키마 반영)
      'age_group': null, // age_group (스키마 반영)
      // emailNotifications 필드는 스키마에 없지만 모델에 있으므로 일단 유지
      'emailNotifications': true,
    });
  }

  // Login with email and password
  Future<UserCredential> loginWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.updatePhotoURL(photoURL);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get user model with fallback for testing
  Future<UserModel> getUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        // UserModel.fromFirestore에서 자동으로 디코딩 처리
        // Pass doc.data() as the first argument, uid as second, and email from data as third
        return UserModel.fromFirestore(doc.data()!, uid, doc.data()!['email'] ?? '');
      } else {
        // 사용자 데이터가 없는 경우(테스트 환경에서) 필요한 기본 사용자 데이터 생성
        await _createDefaultUserDocument(uid);

        // 생성된 기본 사용자 데이터 반환
        final newDoc = await _firestore.collection('users').doc(uid).get();
        if (newDoc.exists) {
          return UserModel.fromFirestore(newDoc.data()!, uid, newDoc.data()!['email'] ?? '');
        } else {
          // 그래도 사용자 데이터가 없는 경우 기본값 사용
          return _createDefaultUserModel(uid);
        }
      }
    } catch (e) {
      print('사용자 정보 가져오기 오류: $e');
      // 오류 발생 시 기본 사용자 모델 반환
      return _createDefaultUserModel(uid);
    }
  }

  // 기본 사용자 데이터 생성 (Firestore에 저장)
  Future<void> _createDefaultUserDocument(String uid) async {
    try {
      final user = _auth.currentUser;
      final now = DateTime.now();

      // username을 Base64로 인코딩
      final encodedUsername = EncodingUtils.encodeToBase64(user?.displayName ?? '사용자'); //

      await _firestore.collection('users').doc(uid).set({
        'user_name': encodedUsername, // user_name (스키마 반영)
        'email': user?.email ?? 'user@example.com',
        'phoneNumber': null,
        'birthDate': null,
        'profile_image_url': null, // profile_image_url (스키마 반영)
        // moodTrackingEnabled 필드는 스키마에 없으므로 제거 (혹은 모델에서만 사용)
        'preferred_voice': 'default', // preferred_voice (스키마 반영)
        'notification_yn': true, // notification_yn (스키마 반영)
        'dailyCheckInReminder': false, // 스키마에 없지만 모델에 있으므로 일단 유지
        'weeklySummaryEnabled': true, // 스키마에 없지만 모델에 있으므로 일단 유지
        'created_at': now, // created_at (스키마 반영)
        // 'updatedAt': now, // updatedAt은 스키마에 없으므로 제거
        'language': 'ko', // language (스키마 반영)
        'preferred_activities': [], // preferred_activities (스키마 반영)
        'use_whisper_api_yn': false, // use_whisper_api_yn (스키마 반영)
        'theme_mode': 'light', // theme_mode (스키마 반영)
        'auto_save_conversations_yn': true, // auto_save_conversations_yn (스키마 반영)
        'age_group': null, // age_group (스키마 반영)
        // emailNotifications 필드는 스키마에 없지만 모델에 있으므로 일단 유지
        'emailNotifications': true,
      });

      print('기본 사용자 데이터 생성 완료');
    } catch (e) {
      print('기본 사용자 데이터 생성 오류: $e');
    }
  }

  // 기본 사용자 모델 생성 (Firestore에 저장하지 않음)
  UserModel _createDefaultUserModel(String uid) {
    final user = _auth.currentUser;
    final now = DateTime.now();

    return UserModel(
        uid: uid,
        email: user?.email ?? 'user@example.com',
        userName: user?.displayName ?? '사용자', // 이 부분은 저장하지 않으므로 인코딩 불필요
        createdAt: now,
        preferredVoice: 'default', // 기본 음성 설정
        notificationYn: true, // 이메일 알림 여부
        gender: null, // 선택사항
        language: 'ko', // 기본 언어 설정 (필요 시 수정)
        preferredActivities: [], // 활동 선호 항목 (초기값은 빈 리스트로 설정)
        profileImageUrl: null, // 기본 프로필 이미지 없음
        useWhisperApiYn: true, // Whisper API 사용 여부
        themeMode: 'light', // 기본 테마 모드 (예: 'light' 또는 'dark')
        autoSaveConversationsYn: true, // 대화 자동 저장 여부
        ageGroup: '20s', // 연령대 (예시값, 실제 입력 필요)
        // 새로 추가된 알림 설정 필드들에 기본값 추가
        emailNotifications: true, // 기본값 true
        dailyCheckInReminder: false, // 기본값 false
        weeklySummaryEnabled: true, // 기본값 true
      );
  }

  // Update user model
  Future<void> updateUserModel(UserModel userModel) async {
    try {
      // username을 Base64로 인코딩
      final encodedUsername = EncodingUtils.encodeToBase64(userModel.userName); //
      await _firestore.collection('users').doc(userModel.uid).update(
        // toMap() 호출 시 필드명이 스키마에 맞게 변환될 것으로 기대
        userModel.toMap()..addAll({'user_name': encodedUsername}), // user_name (스키마 반영)
      );
    } catch (e) {
      rethrow;
    }
  }
}