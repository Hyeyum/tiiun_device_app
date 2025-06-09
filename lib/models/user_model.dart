// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // ========== FireStore 스키마 필수 필드들 ==========
  
  /// 사용자명 (FireStore 필수)
  final String userName;
  
  /// 생성 시간 (FireStore 필수)
  final DateTime createdAt;
  
  /// 선호 음성 (FireStore 필수)
  final String preferredVoice;
  
  /// 알림 설정 (FireStore 필수)
  final bool notificationYn;
  
  /// 성별 (FireStore 필수)
  final String? gender;
  
  /// 언어 설정 (FireStore 필수)
  final String language;
  
  /// 선호 활동 (FireStore 필수)
  final List<String> preferredActivities;
  
  /// 프로필 이미지 URL (FireStore 필수)
  final String? profileImageUrl;
  
  /// Whisper API 사용 여부 (FireStore 필수)
  final bool useWhisperApiYn;
  
  /// 테마 모드 (FireStore 필수)
  final String themeMode;
  
  /// 자동 대화 저장 여부 (FireStore 필수)
  final bool autoSaveConversationsYn;
  
  /// 연령대 (FireStore 필수)
  final String? ageGroup;
  
  // ========== 추가 기능 필드들 (FireStore 스키마에는 없지만 앱 기능상 필요) ==========
  
  /// Firebase Auth UID (인증 연동용)
  final String uid;
  
  /// Firebase Auth 이메일 (인증 연동용)
  final String email;
  
  // ========== 추가 알림 설정 필드들 (FireStore 스키마에 없음 - 제거 검토 필요) ==========
  
  /// 이메일 알림 (스키마에 없음)
  final bool emailNotifications;
  
  /// 매일 체크인 리마인더 (스키마에 없음)
  final bool dailyCheckInReminder;
  
  /// 주간 요약 기능 (스키마에 없음)
  final bool weeklySummaryEnabled;

  UserModel({
    required this.uid,
    required this.email,
    required this.userName,
    required this.createdAt,
    required this.preferredVoice,
    required this.notificationYn, // notificationYn 반영
    this.gender,
    required this.language,
    required this.preferredActivities,
    this.profileImageUrl,
    required this.useWhisperApiYn,
    required this.themeMode,
    required this.autoSaveConversationsYn,
    required this.ageGroup,
    // 새로 추가된 알림 설정 필드들
    required this.emailNotifications,
    required this.dailyCheckInReminder,
    required this.weeklySummaryEnabled,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid, String email) {
    return UserModel(
      uid: uid,
      email: email, // Firebase Auth에서 전달받음
      userName: data['user_name'] ?? '', // user_name (스키마 반영)
      createdAt: (data['createdAt'] as Timestamp).toDate(), // createdAt (스키마 반영)
      preferredVoice: data['preferred_voice'] ?? 'default', // preferred_voice (스키마 반영)
      notificationYn: data['notification_yn'] ?? true, // notification_yn (스키마 반영)
      gender: data['gender'],
      language: data['language'] ?? 'ko',
      preferredActivities: List<String>.from(data['preferred_activities'] ?? []), // preferred_activities (스키마 반영)
      profileImageUrl: data['profile_image_url'], // profile_image_url (스키마 반영)
      useWhisperApiYn: data['use_whisper_api_yn'] ?? false, // use_whisper_api_yn (스키마 반영)
      themeMode: data['theme_mode'] ?? 'light', // theme_mode (스키마 반영)
      autoSaveConversationsYn: data['auto_save_conversations_yn'] ?? true, // auto_save_conversations_yn (스키마 반영)
      ageGroup: data['age_group'], // age_group (스키마 반영)
      
      // 새로 추가된 알림 설정 필드들을 Firestore에서 읽어옴 (스키마에 없지만 유지)
      emailNotifications: data['emailNotifications'] ?? true,
      dailyCheckInReminder: data['dailyCheckInReminder'] ?? false,
      weeklySummaryEnabled: data['weeklySummaryEnabled'] ?? true,
    );
  }

  // toMap 메서드 (Firestore에 업데이트 시 사용)
  Map<String, dynamic> toMap() {
    return {
      'user_name': userName, // user_name (스키마 반영)
      'createdAt': Timestamp.fromDate(createdAt), // createdAt (스키마 반영)
      'preferred_voice': preferredVoice, // preferred_voice (스키마 반영)
      'notification_yn': notificationYn, // notification_yn (스키마 반영)
      'gender': gender,
      'language': language,
      'preferred_activities': preferredActivities, // preferred_activities (스키마 반영)
      'profile_image_url': profileImageUrl, // profile_image_url (스키마 반영)
      'use_whisper_api_yn': useWhisperApiYn, // use_whisper_api_yn (스키마 반영)
      'theme_mode': themeMode, // theme_mode (스키마 반영)
      'auto_save_conversations_yn': autoSaveConversationsYn, // auto_save_conversations_yn (스키마 반영)
      'age_group': ageGroup, // age_group (스키마 반영)
      // 새로 추가된 알림 설정 필드들을 Map에 추가
      'emailNotifications': emailNotifications,
      'dailyCheckInReminder': dailyCheckInReminder,
      'weeklySummaryEnabled': weeklySummaryEnabled,
    };
  }

  // 기존 toFirestore 메서드 (초기 생성 시 사용)
  Map<String, dynamic> toFirestore() {
    return {
      'user_name': userName, // user_name (스키마 반영)
      'createdAt': Timestamp.fromDate(createdAt), // createdAt (스키마 반영)
      'preferred_voice': preferredVoice, // preferred_voice (스키마 반영)
      'notification_yn': notificationYn, // notification_yn (스키마 반영)
      'gender': gender,
      'language': language,
      'preferred_activities': preferredActivities, // preferred_activities (스키마 반영)
      'profile_image_url': profileImageUrl, // profile_image_url (스키마 반영)
      'use_whisper_api_yn': useWhisperApiYn, // use_whisper_api_yn (스키마 반영)
      'theme_mode': themeMode, // theme_mode (스키마 반영)
      'auto_save_conversations_yn': autoSaveConversationsYn, // auto_save_conversations_yn (스키마 반영)
      'age_group': ageGroup, // age_group (스키마 반영)
      // 새로 추가된 알림 설정 필드들을 Map에 추가
      'emailNotifications': emailNotifications,
      'dailyCheckInReminder': dailyCheckInReminder,
      'weeklySummaryEnabled': weeklySummaryEnabled,
    };
  }

  // copyWith 메서드
  UserModel copyWith({
    String? uid,
    String? email,
    String? userName,
    DateTime? createdAt,
    String? preferredVoice,
    bool? notificationYn,
        String? gender,
    String? language,
    List<String>? preferredActivities,
    String? profileImageUrl,
    bool? useWhisperApiYn,
    String? themeMode,
    bool? autoSaveConversationsYn,
    String? ageGroup,
    // 새로 추가된 알림 설정 필드들
    bool? emailNotifications,
    bool? dailyCheckInReminder,
    bool? weeklySummaryEnabled,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
      preferredVoice: preferredVoice ?? this.preferredVoice,
      notificationYn: notificationYn ?? this.notificationYn, // notificationYn 반영
      gender: gender ?? this.gender,
      language: language ?? this.language,
      preferredActivities: preferredActivities ?? this.preferredActivities,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      useWhisperApiYn: useWhisperApiYn ?? this.useWhisperApiYn,
      themeMode: themeMode ?? this.themeMode,
      autoSaveConversationsYn: autoSaveConversationsYn ?? this.autoSaveConversationsYn,
      ageGroup: ageGroup ?? this.ageGroup,
      // 새로 추가된 알림 설정 필드들
      emailNotifications: emailNotifications ?? this.emailNotifications,
      dailyCheckInReminder: dailyCheckInReminder ?? this.dailyCheckInReminder,
      weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
    );
  }
}