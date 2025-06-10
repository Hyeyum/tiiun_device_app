/// 앱 전체에서 사용할 상수 정의
class AppConstants {
  // 앱 정보
  static const String appName = "마음챙김 대화";
  static const String appVersion = "1.0.0";
  static const String appBuildNumber = "1";

  // 권한 관련
  static const String microphonePermissionRationale =
      "음성 대화 기능을 사용하려면 마이크 권한이 필요합니다.";
  static const String storagePermissionRationale =
      "프로필 이미지와 대화 녹음을 저장하기 위해 저장소 접근 권한이 필요합니다.";
  static const String cameraPermissionRationale =
      "프로필 이미지를 촬영하기 위해 카메라 권한이 필요합니다.";
  static const String notificationPermissionRationale =
      "알림을 받기 위해 알림 권한이 필요합니다.";

  // 파이어베이스 콜렉션 이름
  static const String usersCollection = "users";
  static const String conversationsCollection = "conversations";
  static const String messagesCollection = "messages";
  static const String moodRecordsCollection = "mood_records";
  static const String agentsCollection = "agents";
  static const String voiceProfilesCollection = "voice_profiles";
  static const String notificationsCollection = "notifications";

  // 네트워크 타임아웃
  static const int connectTimeout = 30000; // 30초
  static const int receiveTimeout = 30000; // 30초

  // 오류 메시지
  static const String defaultErrorMessage =
      "오류가 발생했습니다. 다시 시도해주세요.";
  static const String networkErrorMessage =
      "네트워크 연결이 원활하지 않습니다. 연결 상태를 확인해주세요.";
  static const String authErrorMessage =
      "인증에 실패했습니다. 로그인 정보를 확인해주세요.";
  static const String permissionDeniedMessage =
      "필요한 권한이 허용되지 않아 해당 기능을 사용할 수 없습니다.";
  static const String dataNotFoundMessage =
      "요청하신 데이터를 찾을 수 없습니다.";

  // 감정 관련
  static const List<String> moodTypes = [
    'very_bad',
    'bad',
    'neutral',
    'good',
    'very_good'
  ];

  static const Map<String, String> moodLabels = {
    'very_bad': '매우 나쁨',
    'bad': '나쁨',
    'neutral': '보통',
    'good': '좋음',
    'very_good': '매우 좋음'
  };

  // 기본 감정 태그
  static const List<String> defaultMoodTags = [
    // 감정
    '행복', '슬픔', '걱정', '불안', '분노', '신남', '지침', '편안함', '스트레스', '안도감',
    // 활동
    '운동', '여행', '일', '공부', '취미', '휴식', '모임', '식사', '쇼핑', '영화',
    // 사람
    '가족', '친구', '연인', '동료', '혼자', '낯선 사람', '반려동물',
    // 장소
    '집', '회사', '학교', '카페', '공원', '대중교통', '야외', '실내'
  ];

  // 음성 대화 관련
  static const int maxRecordingDuration = 60000; // 60초
  static const int voiceVisualizerSmoothing = 5; // 음성 시각화 평활화 단계
  static const int voiceInputSilenceThreshold = 800; // 음성 입력 종료 감지 임계치(ms)

  // AI 에이전트 관련
  static const List<String> defaultAgentPersonalities = [
    '공감적',
    '지지적',
    '논리적',
    '분석적',
    '친절한',
    '차분한',
    '긍정적',
    '유머러스',
    '실용적',
  ];

  // 애니메이션 지속 시간
  static const int shortAnimationDuration = 150; // 밀리초
  static const int normalAnimationDuration = 300; // 밀리초
  static const int longAnimationDuration = 500; // 밀리초

  // 앱 설정 관련
  static const String darkModeKey = 'dark_mode';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String soundEffectsEnabledKey = 'sound_effects_enabled';
  static const String hapticFeedbackEnabledKey = 'haptic_feedback_enabled';
  static const String autoRecordingKey = 'auto_recording';
  static const String fontSizeKey = 'font_size';
  static const String languageKey = 'language';

  // 폰트 크기 옵션
  static const Map<String, double> fontSizeOptions = {
    '작게': 0.8,
    '기본': 1.0,
    '크게': 1.2,
    '매우 크게': 1.4,
  };

  // 언어 옵션
  static const Map<String, String> languageOptions = {
    'ko': '한국어',
    'en': 'English',
    'ja': '日本語',
    'zh': '中文',
  };

  // 푸시 알림 채널
  static const String messageNotificationChannelId = 'message_notification_channel';
  static const String messageNotificationChannelName = '메시지 알림';
  static const String messageNotificationChannelDescription = '새로운 메시지가 도착했을 때 알림을 받습니다.';

  static const String reminderNotificationChannelId = 'reminder_notification_channel';
  static const String reminderNotificationChannelName = '리마인더 알림';
  static const String reminderNotificationChannelDescription = '감정 기록 및 대화 리마인더 알림을 받습니다.';

  // 앱 가이드 텍스트
  static const List<Map<String, String>> onboardingPages = [
    {
      'title': '마음 건강 대화',
      'description': '인공지능 대화를 통해 매일 마음 건강을 챙겨보세요. 당신의 이야기에 귀 기울이는 친구가 항상 함께합니다.',
      'image': 'assets/images/onboarding_1.png',
    },
    {
      'title': '감정 추적',
      'description': '매일의 감정을 기록하고 패턴을 확인해보세요. 자신의 감정 변화를 이해하는 것이 마음 건강의 첫걸음입니다.',
      'image': 'assets/images/onboarding_2.png',
    },
    {
      'title': '음성으로 더 편하게',
      'description': '타이핑이 부담스러울 때는 음성으로 대화하세요. 마치 실제 대화하는 것처럼 자연스러운 소통이 가능합니다.',
      'image': 'assets/images/onboarding_3.png',
    },
  ];

  // 프라이버시 정책 및 이용약관 URL
  static const String privacyPolicyUrl = 'https://mindcare.example.com/privacy';
  static const String termsOfServiceUrl = 'https://mindcare.example.com/terms';

  // 기타
  static const int maxConversationHistoryCount = 50;
  static const int paginationLimit = 20;
}

/// 앱 내에서 사용되는 모든 라우트 정의
class AppRoutes {
  // 인증 관련
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // 메인 화면
  static const String home = '/home';
  static const String conversationList = '/conversations';
  static const String conversation = '/conversation';
  static const String moodTracking = '/mood-tracking';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // 설정 관련
  static const String voiceSettings = '/settings/voice';
  static const String notificationSettings = '/settings/notifications';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
  static const String about = '/about';
}

/// 로컬 저장소에 사용되는 키 정의
class StorageKeys {
  static const String userToken = 'user_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userName = 'user_name';
  static const String userPhotoUrl = 'user_photo_url';
  static const String isOnboardingCompleted = 'is_onboarding_completed';
  static const String lastLoginAt = 'last_login_at';
  static const String lastActiveAt = 'last_active_at';
  static const String darkModeEnabled = 'dark_mode_enabled';
  static const String selectedLanguage = 'selected_language';
  static const String fontScale = 'font_scale';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String soundEffectsEnabled = 'sound_effects_enabled';
  static const String hapticFeedbackEnabled = 'haptic_feedback_enabled';
  static const String lastMoodRecordDate = 'last_mood_record_date';
  static const String recentConversationIds = 'recent_conversation_ids';
  static const String preferredAgentId = 'preferred_agent_id';
  static const String voiceInputEnabled = 'voice_input_enabled';
  static const String voiceOutputEnabled = 'voice_output_enabled';
  static const String selectedVoiceProfileId = 'selected_voice_profile_id';
  static const String autoRecordingEnabled = 'auto_recording_enabled';
}

/// API 관련 상수 정의
class ApiConstants {
  // API 엔드포인트
  static const String baseUrl = 'https://mindfultalks-api.example.com/api/v1';
  static const String aiServiceUrl = 'https://mindfultalks-ai.example.com/api/v1';

  // API 경로
  static const String authPath = '/auth';
  static const String usersPath = '/users';
  static const String conversationsPath = '/conversations';
  static const String messagesPath = '/messages';
  static const String moodRecordsPath = '/mood-records';
  static const String voiceProfilesPath = '/voice-profiles';
  static const String filesPath = '/files';

  // API 헤더
  static const String authHeader = 'Authorization';
  static const String contentTypeHeader = 'Content-Type';
  static const String acceptHeader = 'Accept';
  static const String applicationJson = 'application/json';

  // API 타임아웃
  static const int connectionTimeout = 30000; // 30초
  static const int receiveTimeout = 60000; // 60초

  // Firebase Storage 경로
  static const String profileImagesPath = 'profile_images';
  static const String voiceRecordingsPath = 'voice_recordings';
  static const String messageAttachmentsPath = 'message_attachments';
}

/// 분석 이벤트 상수 정의
class AnalyticsEvents {
  // 사용자 이벤트
  static const String userSignUp = 'user_sign_up';
  static const String userLogin = 'user_login';
  static const String userLogout = 'user_logout';
  static const String userProfileUpdate = 'user_profile_update';

  // 대화 이벤트
  static const String conversationStart = 'conversation_start';
  static const String conversationEnd = 'conversation_end';
  static const String messageSent = 'message_sent';
  static const String messageReceived = 'message_received';
  static const String voiceMessageSent = 'voice_message_sent';

  // 감정 관련 이벤트
  static const String moodRecorded = 'mood_recorded';
  static const String moodDataViewed = 'mood_data_viewed';

  // 기능 사용 이벤트
  static const String featureUsed = 'feature_used';
  static const String settingsChanged = 'settings_changed';
  static const String onboardingCompleted = 'onboarding_completed';

  // 오류 이벤트
  static const String errorOccurred = 'error_occurred';
}

/// 알림 관련 상수 정의
class NotificationConstants {
  // 알림 ID 범위
  static const int messageNotificationIdStart = 1000;
  static const int reminderNotificationIdStart = 2000;

  // 알림 유형
  static const String messageType = 'message';
  static const String moodReminderType = 'mood_reminder';
  static const String conversationReminderType = 'conversation_reminder';
  static const String tipsType = 'tips';

  // 알림 시간
  static const int defaultMoodReminderHour = 20; // 저녁 8시
  static const int defaultMoodReminderMinute = 0;
}