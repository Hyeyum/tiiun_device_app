// lib/services/conversation_context_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emotion_model.dart';
import '../utils/logger.dart';

// Provider for conversation context service
final conversationContextServiceProvider = StateNotifierProvider<ConversationContextNotifier, ConversationContext>((ref) {
  return ConversationContextNotifier();
});

/// 대화 컨텍스트를 관리하는 StateNotifier
class ConversationContextNotifier extends StateNotifier<ConversationContext> {
  ConversationContextNotifier() : super(ConversationContext(
    emotionHistory: [],
    needFrequency: {},
  ));

  /// 새로운 감정 분석 결과를 추가합니다
  void addEmotionAnalysis(EmotionAnalysisResult analysis) {
    AppLogger.info('ConversationContextService: Adding emotion analysis: ${analysis.emotionType}');

    final updatedHistory = [...state.emotionHistory, analysis];
    final updatedNeedFrequency = {...state.needFrequency};

    // 욕구 빈도 업데이트
    for (final need in analysis.suggestedNeeds) {
      updatedNeedFrequency[need] = (updatedNeedFrequency[need] ?? 0) + 1;
    }

    // 히스토리는 최대 50개까지만 유지
    final limitedHistory = updatedHistory.length > 50
        ? updatedHistory.sublist(updatedHistory.length - 50)
        : updatedHistory;

    state = ConversationContext(
      emotionHistory: limitedHistory,
      needFrequency: updatedNeedFrequency,
      userName: state.userName,
      lastInteraction: DateTime.now(),
    );

    AppLogger.debug('ConversationContextService: Updated context. History length: ${limitedHistory.length}');
  }

  /// 사용자 이름을 설정합니다
  void setUserName(String? userName) {
    state = ConversationContext(
      emotionHistory: state.emotionHistory,
      needFrequency: state.needFrequency,
      userName: userName,
      lastInteraction: state.lastInteraction,
    );
  }

  /// 컨텍스트를 초기화합니다
  void resetContext() {
    AppLogger.info('ConversationContextService: Resetting context');
    state = ConversationContext(
      emotionHistory: [],
      needFrequency: {},
    );
  }

  /// 최근 감정 패턴을 분석합니다
  Map<String, dynamic> analyzeRecentPattern() {
    if (state.emotionHistory.isEmpty) {
      return {
        'hasPattern': false,
        'message': '아직 충분한 대화 데이터가 없어요.',
      };
    }

    final recentEmotions = state.emotionHistory.length > 10
        ? state.emotionHistory.sublist(state.emotionHistory.length - 10)
        : state.emotionHistory;

    final emotionCounts = <EmotionType, int>{};
    for (final emotion in recentEmotions) {
      emotionCounts[emotion.emotionType] = (emotionCounts[emotion.emotionType] ?? 0) + 1;
    }

    // 가장 빈번한 감정 찾기
    final dominantEmotion = emotionCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    // 부정적 감정의 비율 계산
    final negativeEmotions = [EmotionType.stress, EmotionType.anxiety, EmotionType.depression, EmotionType.anger];
    final negativeCount = emotionCounts.entries
        .where((entry) => negativeEmotions.contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value);

    final negativeRatio = negativeCount / recentEmotions.length;

    String patternMessage;
    bool needsAttention = false;

    if (negativeRatio > 0.7) {
      patternMessage = '최근에 힘든 감정을 많이 느끼고 계시는 것 같아요. 혹시 전문적인 도움이 필요하시지는 않나요?';
      needsAttention = true;
    } else if (dominantEmotion.value >= 5) {
      patternMessage = '최근에 ${dominantEmotion.key.displayName} 감정을 자주 느끼고 계시는군요.';
    } else {
      patternMessage = '다양한 감정을 균형있게 느끼고 계시는 것 같아요.';
    }

    return {
      'hasPattern': true,
      'dominantEmotion': dominantEmotion.key,
      'emotionCounts': emotionCounts,
      'negativeRatio': negativeRatio,
      'needsAttention': needsAttention,
      'message': patternMessage,
    };
  }

  /// 사용자의 주요 욕구를 분석합니다
  Map<String, dynamic> analyzeDominantNeeds() {
    if (state.needFrequency.isEmpty) {
      return {
        'hasNeeds': false,
        'message': '아직 충분한 대화 데이터가 없어요.',
      };
    }

    // 욕구를 카테고리별로 그룹화
    final categoryFrequency = <String, int>{};
    for (final entry in state.needFrequency.entries) {
      final category = entry.key.category;
      categoryFrequency[category] = (categoryFrequency[category] ?? 0) + entry.value;
    }

    // 가장 빈번한 욕구 카테고리 찾기
    final dominantCategory = categoryFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    // 해당 카테고리의 구체적인 욕구들
    final categoryNeeds = state.needFrequency.entries
        .where((entry) => entry.key.category == dominantCategory.key)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String needsMessage;
    switch (dominantCategory.key) {
      case '생존 욕구':
        needsMessage = '휴식과 치유가 많이 필요하신 것 같아요. 자신을 돌보는 시간을 가져보세요.';
        break;
      case '소속 욕구':
        needsMessage = '공감과 지지, 이해받고 싶은 마음이 크신 것 같아요. 소중한 사람들과의 연결을 느껴보세요.';
        break;
      case '안정 욕구':
        needsMessage = '예측 가능하고 안정적인 환경을 원하시는군요. 계획을 세우고 정보를 찾아보시는 것이 도움이 될 것 같아요.';
        break;
      case '존중 욕구':
        needsMessage = '인정받고 가치를 느끼고 싶으신 것 같아요. 스스로의 성취를 인정해주시는 것도 중요해요.';
        break;
      default:
        needsMessage = '다양한 욕구를 가지고 계시는군요.';
    }

    return {
      'hasNeeds': true,
      'dominantCategory': dominantCategory.key,
      'categoryFrequency': categoryFrequency,
      'topNeeds': categoryNeeds.take(3).map((e) => e.key.displayName).toList(),
      'message': needsMessage,
    };
  }

  /// 대화 지속 시간 분석
  Duration get conversationDuration {
    if (state.emotionHistory.isEmpty) return Duration.zero;

    final firstInteraction = state.emotionHistory.first.timestamp;
    final lastInteraction = state.lastInteraction;

    return lastInteraction.difference(firstInteraction);
  }

  /// 대화 세션 요약 생성
  Map<String, dynamic> generateSessionSummary() {
    final pattern = analyzeRecentPattern();
    final needs = analyzeDominantNeeds();
    final duration = conversationDuration;

    return {
      'duration': duration,
      'totalInteractions': state.emotionHistory.length,
      'emotionPattern': pattern,
      'needsAnalysis': needs,
      'suggestions': _generateSessionSuggestions(pattern, needs),
    };
  }

  /// 세션 기반 제안사항 생성
  List<String> _generateSessionSuggestions(Map<String, dynamic> pattern, Map<String, dynamic> needs) {
    final suggestions = <String>[];

    // 부정적 감정이 많은 경우
    if (pattern['needsAttention'] == true) {
      suggestions.add('전문 상담사나 의료진과 상담을 받아보시는 것을 권해드려요.');
      suggestions.add('신뢰할 수 있는 가족이나 친구에게 마음을 털어놓아보세요.');
    }

    // 욕구별 제안
    if (needs['hasNeeds'] == true) {
      switch (needs['dominantCategory']) {
        case '생존 욕구':
          suggestions.add('충분한 휴식과 수면을 취하세요.');
          suggestions.add('규칙적인 운동과 건강한 식습관을 유지해보세요.');
          break;
        case '소속 욕구':
          suggestions.add('소중한 사람들과 더 많은 시간을 보내보세요.');
          suggestions.add('동호회나 커뮤니티 활동에 참여해보시는 것도 좋겠어요.');
          break;
        case '안정 욕구':
          suggestions.add('미래 계획을 구체적으로 세워보세요.');
          suggestions.add('신뢰할 수 있는 정보원을 찾아 불안감을 줄여보세요.');
          break;
        case '존중 욕구':
          suggestions.add('자신의 성취와 장점을 인정해주세요.');
          suggestions.add('새로운 도전을 통해 성장의 기회를 만들어보세요.');
          break;
      }
    }

    // 기본 제안
    if (suggestions.isEmpty) {
      suggestions.add('꾸준한 자기 관리와 긍정적인 마음가짐을 유지해보세요.');
      suggestions.add('필요할 때는 언제든 도움을 요청하세요.');
    }

    return suggestions;
  }
}