// lib/services/emotion_analysis_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emotion_model.dart';
import '../utils/logger.dart';

// Provider for emotion analysis service
final emotionAnalysisServiceProvider = Provider<EmotionAnalysisService>((ref) {
  return EmotionAnalysisService();
});

/// 사용자의 텍스트 입력을 분석하여 감정과 욕구를 파악하는 서비스
class EmotionAnalysisService {

  /// 텍스트에서 감정을 분석합니다
  EmotionAnalysisResult analyzeEmotion(String text) {
    AppLogger.info('EmotionAnalysisService: Analyzing emotion for text: "$text"');

    final cleanText = text.toLowerCase().trim();

    // 감정 키워드 매칭
    final emotionType = _detectEmotionType(cleanText);
    final intensity = _calculateIntensity(cleanText);
    final keywords = _extractEmotionKeywords(cleanText);
    final suggestedNeeds = _predictNeeds(emotionType, cleanText);

    final result = EmotionAnalysisResult(
      emotionType: emotionType,
      intensity: intensity,
      keywords: keywords,
      suggestedNeeds: suggestedNeeds,
      originalText: text,
    );

    AppLogger.debug('EmotionAnalysisService: Analysis result: $result');
    return result;
  }

  /// 감정 유형을 감지합니다
  EmotionType _detectEmotionType(String text) {
    // 스트레스 관련 키워드
    if (_containsAnyKeywords(text, [
      '스트레스', '힘들어', '지쳐', '피곤', '답답', '짜증', '화나', '분노',
      '스트레스받', '열받', '빡쳐', '신경쓰여', '괴로워', '지겨워',
      '못견디겠', '한계', '과로', '번아웃', '압박', '부담'
    ])) {
      return EmotionType.stress;
    }

    // 불안 관련 키워드
    if (_containsAnyKeywords(text, [
      '불안', '걱정', '두려워', '무서워', '겁나', '염려', '초조',
      '긴장', '떨려', '심장이', '가슴이', '두근', '불확실', '모르겠',
      '어떻게', '망하면', '실패', '잘못되면', '계속', '혹시'
    ])) {
      return EmotionType.anxiety;
    }

    // 우울 관련 키워드
    if (_containsAnyKeywords(text, [
      '우울', '슬퍼', '울적', '암울', '절망', '의욕없', '무기력',
      '공허', '허무', '외로워', '고독', '쓸쓸', '비참', '눈물',
      '포기', '그만두고싶', '의미없', '살기싫', '죽고싶'
    ])) {
      return EmotionType.depression;
    }

    // 기쁨 관련 키워드
    if (_containsAnyKeywords(text, [
      '기뻐', '행복', '좋아', '즐거워', '신나', '만족', '뿌듯',
      '감사', '고마워', '사랑', '웃음', '미소', '축하', '성공',
      '완성', '달성', '최고', '환상', '굉장', '대박'
    ])) {
      return EmotionType.joy;
    }

    // 분노 관련 키워드
    if (_containsAnyKeywords(text, [
      '화나', '분노', '열받', '빡쳐', '짜증', '욕나와', '미워',
      '원망', '억울', '불공평', '부당', '이해안돼', '말도안돼'
    ])) {
      return EmotionType.anger;
    }

    return EmotionType.neutral;
  }

  /// 감정 강도를 계산합니다 (0.0 ~ 1.0)
  double _calculateIntensity(String text) {
    int intensityScore = 0;

    // 강화 표현들
    final intensifiers = [
      '정말', '너무', '진짜', '완전', '엄청', '매우', '굉장히', '심하게',
      '많이', '극도로', '무척', '대단히', '상당히', '꽤', '제대로'
    ];

    // 반복 표현들 (!!!!, ㅠㅠㅠ 등)
    final exclamationCount = '!'.allMatches(text).length;
    final cryingCount = 'ㅠ'.allMatches(text).length + 'ㅜ'.allMatches(text).length;

    // 강화 표현 점수
    for (final intensifier in intensifiers) {
      if (text.contains(intensifier)) {
        intensityScore += 2;
      }
    }

    // 반복 표현 점수
    intensityScore += (exclamationCount / 2).round();
    intensityScore += (cryingCount / 2).round();

    // 0.3 ~ 1.0 범위로 정규화
    final normalizedScore = (intensityScore / 10.0).clamp(0.3, 1.0);
    return normalizedScore;
  }

  /// 감정 키워드를 추출합니다
  List<String> _extractEmotionKeywords(String text) {
    final allKeywords = [
      // 스트레스
      '스트레스', '힘들어', '지쳐', '피곤', '답답', '짜증',
      // 불안
      '불안', '걱정', '두려워', '무서워', '긴장',
      // 우울
      '우울', '슬퍼', '울적', '절망', '무기력', '외로워',
      // 기쁨
      '기뻐', '행복', '좋아', '즐거워', '신나', '만족',
      // 분노
      '화나', '분노', '열받', '빡쳐', '미워'
    ];

    return allKeywords.where((keyword) => text.contains(keyword)).toList();
  }

  /// 감정에 따른 욕구를 예측합니다
  List<NeedType> _predictNeeds(EmotionType emotionType, String text) {
    switch (emotionType) {
      case EmotionType.stress:
      // 스트레스 → 휴식/치료 (생존) 또는 공감/지지 (소속)
        if (_containsAnyKeywords(text, ['쉬고싶', '휴식', '치료', '병원', '약'])) {
          return [NeedType.survival_rest, NeedType.survival_healing];
        } else {
          return [NeedType.belonging_empathy, NeedType.belonging_support];
        }

      case EmotionType.anxiety:
      // 불안 → 예측/계획 (안정) 또는 안심/지지 (소속)
        if (_containsAnyKeywords(text, ['계획', '준비', '정보', '어떻게', '방법'])) {
          return [NeedType.security_prediction, NeedType.security_planning];
        } else {
          return [NeedType.belonging_comfort, NeedType.belonging_support];
        }

      case EmotionType.depression:
      // 우울 → 이해/공감 (소속) 또는 인정/가치 (존중)
        if (_containsAnyKeywords(text, ['인정', '가치', '능력', '성취', '칭찬'])) {
          return [NeedType.esteem_recognition, NeedType.esteem_value];
        } else {
          return [NeedType.belonging_understanding, NeedType.belonging_empathy];
        }

      case EmotionType.joy:
      // 기쁨 → 공유/축하 (소속) 또는 성취/인정 (존중)
        return [NeedType.belonging_sharing, NeedType.esteem_achievement];

      case EmotionType.anger:
      // 분노 → 정의/공정 (존중) 또는 배출/해소 (생존)
        return [NeedType.esteem_justice, NeedType.survival_release];

      case EmotionType.neutral:
      // 중립 → 기본적인 소통 욕구
        return [NeedType.belonging_connection];
    }
  }

  /// 텍스트에 특정 키워드들이 포함되어 있는지 확인합니다
  bool _containsAnyKeywords(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}