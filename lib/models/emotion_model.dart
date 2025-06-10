
// lib/models/emotion_model.dart

/// 감정 유형을 정의하는 enum
enum EmotionType {
  stress,     // 스트레스
  anxiety,    // 불안
  depression, // 우울
  joy,        // 기쁨
  anger,      // 분노
  neutral,    // 중립
}

/// 욕구 유형을 정의하는 enum (매슬로우의 욕구 계층 기반)
enum NeedType {
  // 생존 욕구 (Survival/Physiological)
  survival_rest,      // 휴식
  survival_healing,   // 치료
  survival_release,   // 배출/해소

  // 소속 욕구 (Belonging/Love)
  belonging_empathy,      // 공감
  belonging_support,      // 지지
  belonging_understanding, // 이해
  belonging_comfort,      // 안심
  belonging_sharing,      // 공유
  belonging_connection,   // 연결

  // 안정 욕구 (Security/Safety)
  security_prediction,    // 예측
  security_planning,      // 계획
  security_information,   // 정보

  // 존중 욕구 (Esteem)
  esteem_recognition,     // 인정
  esteem_value,          // 가치
  esteem_achievement,    // 성취
  esteem_justice,        // 정의/공정
}

/// 감정 분석 결과를 담는 클래스
class EmotionAnalysisResult {
  final EmotionType emotionType;
  final double intensity;        // 0.0 ~ 1.0
  final List<String> keywords;
  final List<NeedType> suggestedNeeds;
  final String originalText;
  final DateTime timestamp;

  EmotionAnalysisResult({
    required this.emotionType,
    required this.intensity,
    required this.keywords,
    required this.suggestedNeeds,
    required this.originalText,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'EmotionAnalysisResult(emotion: $emotionType, intensity: $intensity, keywords: $keywords, needs: $suggestedNeeds)';
  }
}

/// 개인화된 응답을 위한 컨텍스트
class ConversationContext {
  final List<EmotionAnalysisResult> emotionHistory;
  final Map<NeedType, int> needFrequency;
  final String? userName;
  final DateTime lastInteraction;

  ConversationContext({
    required this.emotionHistory,
    required this.needFrequency,
    this.userName,
    DateTime? lastInteraction,
  }) : lastInteraction = lastInteraction ?? DateTime.now();

  /// 가장 최근 감정을 반환합니다
  EmotionType? get recentEmotion =>
      emotionHistory.isNotEmpty ? emotionHistory.last.emotionType : null;

  /// 가장 빈번한 욕구를 반환합니다
  NeedType? get dominantNeed {
    if (needFrequency.isEmpty) return null;

    return needFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// 최근 감정 패턴을 분석합니다
  Map<EmotionType, int> get recentEmotionPattern {
    final pattern = <EmotionType, int>{};

    // 최근 10개 감정 분석
    final recentEmotions = emotionHistory.length > 10
        ? emotionHistory.sublist(emotionHistory.length - 10)
        : emotionHistory;

    for (final emotion in recentEmotions) {
      pattern[emotion.emotionType] = (pattern[emotion.emotionType] ?? 0) + 1;
    }

    return pattern;
  }
}

/// 감정에 따른 응답 템플릿
class EmotionResponseTemplate {
  final EmotionType targetEmotion;
  final List<NeedType> targetNeeds;
  final List<String> empathyResponses;
  final List<String> actionSuggestions;
  final List<String> followUpQuestions;

  EmotionResponseTemplate({
    required this.targetEmotion,
    required this.targetNeeds,
    required this.empathyResponses,
    required this.actionSuggestions,
    required this.followUpQuestions,
  });
}

/// 감정 유형별 한국어 이름 확장
extension EmotionTypeExtension on EmotionType {
  String get displayName {
    switch (this) {
      case EmotionType.stress:
        return '스트레스';
      case EmotionType.anxiety:
        return '불안';
      case EmotionType.depression:
        return '우울';
      case EmotionType.joy:
        return '기쁨';
      case EmotionType.anger:
        return '분노';
      case EmotionType.neutral:
        return '평온';
    }
  }

  String get emoji {
    switch (this) {
      case EmotionType.stress:
        return '😰';
      case EmotionType.anxiety:
        return '😟';
      case EmotionType.depression:
        return '😔';
      case EmotionType.joy:
        return '😊';
      case EmotionType.anger:
        return '😠';
      case EmotionType.neutral:
        return '😐';
    }
  }
}

/// 욕구 유형별 한국어 이름 확장
extension NeedTypeExtension on NeedType {
  String get displayName {
    switch (this) {
      case NeedType.survival_rest:
        return '휴식';
      case NeedType.survival_healing:
        return '치료';
      case NeedType.survival_release:
        return '해소';
      case NeedType.belonging_empathy:
        return '공감';
      case NeedType.belonging_support:
        return '지지';
      case NeedType.belonging_understanding:
        return '이해';
      case NeedType.belonging_comfort:
        return '안심';
      case NeedType.belonging_sharing:
        return '공유';
      case NeedType.belonging_connection:
        return '연결';
      case NeedType.security_prediction:
        return '예측';
      case NeedType.security_planning:
        return '계획';
      case NeedType.security_information:
        return '정보';
      case NeedType.esteem_recognition:
        return '인정';
      case NeedType.esteem_value:
        return '가치';
      case NeedType.esteem_achievement:
        return '성취';
      case NeedType.esteem_justice:
        return '정의';
    }
  }

  String get category {
    switch (this) {
      case NeedType.survival_rest:
      case NeedType.survival_healing:
      case NeedType.survival_release:
        return '생존 욕구';
      case NeedType.belonging_empathy:
      case NeedType.belonging_support:
      case NeedType.belonging_understanding:
      case NeedType.belonging_comfort:
      case NeedType.belonging_sharing:
      case NeedType.belonging_connection:
        return '소속 욕구';
      case NeedType.security_prediction:
      case NeedType.security_planning:
      case NeedType.security_information:
        return '안정 욕구';
      case NeedType.esteem_recognition:
      case NeedType.esteem_value:
      case NeedType.esteem_achievement:
      case NeedType.esteem_justice:
        return '존중 욕구';
    }
  }
}
