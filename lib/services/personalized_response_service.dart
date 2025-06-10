// lib/services/personalized_response_service.dart
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emotion_model.dart';
import '../utils/logger.dart';

// Provider for personalized response service
final personalizedResponseServiceProvider = Provider<PersonalizedResponseService>((ref) {
  return PersonalizedResponseService();
});

/// 사용자의 감정과 욕구에 따라 개인화된 응답을 생성하는 서비스
class PersonalizedResponseService {
  final Random _random = Random();

  /// 감정 분석 결과와 대화 컨텍스트를 기반으로 개인화된 응답을 생성합니다
  PersonalizedResponse generateResponse({
    required EmotionAnalysisResult emotionAnalysis,
    required ConversationContext context,
    String? userName,
  }) {
    AppLogger.info('PersonalizedResponseService: Generating response for emotion: ${emotionAnalysis.emotionType}');

    final template = _getResponseTemplate(emotionAnalysis.emotionType);
    final empathyResponse = _selectEmpathyResponse(template, emotionAnalysis);
    final actionSuggestion = _selectActionSuggestion(template, emotionAnalysis);
    final followUpQuestion = _selectFollowUpQuestion(template, emotionAnalysis, context);

    final response = PersonalizedResponse(
      empathyMessage: empathyResponse,
      actionSuggestion: actionSuggestion,
      followUpQuestion: followUpQuestion,
      targetEmotion: emotionAnalysis.emotionType,
      targetNeeds: emotionAnalysis.suggestedNeeds,
      conversationFlow: _determineConversationFlow(emotionAnalysis, context),
    );

    AppLogger.debug('PersonalizedResponseService: Generated response: ${response.fullMessage}');
    return response;
  }

  /// 감정별 응답 템플릿을 반환합니다
  EmotionResponseTemplate _getResponseTemplate(EmotionType emotionType) {
    switch (emotionType) {
      case EmotionType.stress:
        return EmotionResponseTemplate(
          targetEmotion: EmotionType.stress,
          targetNeeds: [NeedType.survival_rest, NeedType.belonging_empathy],
          empathyResponses: [
            "정말 많이 힘드셨겠어요. 스트레스를 받고 계시는군요.",
            "지금 상황이 정말 어려우시겠어요. 많이 지치셨을 것 같아요.",
            "스트레스가 많이 쌓이셨나봐요. 얼마나 힘드실지 충분히 이해해요.",
            "정말 수고 많으셨어요. 이런 상황에서는 누구나 스트레스를 받을 수밖에 없어요.",
            "많은 부담을 안고 계시는군요. 혼자서 감당하기 힘드시겠어요.",
          ],
          actionSuggestions: [
            "잠깐 깊게 숨을 쉬어보시는 건 어떨까요? 5초 들이쉬고 5초 내쉬는 호흡법을 해보세요.",
            "따뜻한 차 한 잔 마시며 10분 정도만 쉬어보시면 어떨까요?",
            "지금 당장 할 수 있는 간단한 스트레칭을 해보시는 것도 도움이 될 것 같아요.",
            "오늘 하루 중 가장 스트레스를 준 일이 무엇인지 말씀해주시면, 함께 해결 방법을 찾아볼게요.",
            "잠시 산책을 하거나 좋아하시는 음악을 들어보시는 건 어떨까요?",
          ],
          followUpQuestions: [
            "어떤 일로 인해 가장 스트레스를 받고 계신가요?",
            "평소에 스트레스를 풀 때 어떤 방법을 사용하시나요?",
            "지금 가장 필요한 것이 휴식인가요, 아니면 누군가의 도움인가요?",
            "이런 상황이 언제부터 시작되었나요?",
            "주변에 이야기할 수 있는 분이 계신가요?",
          ],
        );

      case EmotionType.anxiety:
        return EmotionResponseTemplate(
          targetEmotion: EmotionType.anxiety,
          targetNeeds: [NeedType.security_prediction, NeedType.belonging_comfort],
          empathyResponses: [
            "불안한 마음이 드시는군요. 그런 마음 충분히 이해해요.",
            "걱정이 많으시겠어요. 불확실한 상황은 누구에게나 불안감을 줄 수 있어요.",
            "마음이 많이 무거우시겠어요. 불안할 때는 혼자 있기 힘들죠.",
            "그런 걱정을 하시는 것도 당연해요. 미래에 대한 두려움은 자연스러운 감정이에요.",
            "지금 느끼시는 불안감이 얼마나 힘든지 알 것 같아요.",
          ],
          actionSuggestions: [
            "지금 당장 컨트롤할 수 있는 것들부터 하나씩 정리해보시면 어떨까요?",
            "걱정되는 상황에 대해 구체적인 계획을 세워보시는 것이 도움이 될 것 같아요.",
            "믿을만한 정보를 찾아보거나 전문가에게 조언을 구해보시는 건 어떨까요?",
            "지금 이 순간에 집중할 수 있는 간단한 활동을 해보세요.",
            "불안한 생각들을 종이에 적어보시면 마음이 정리될 수 있어요.",
          ],
          followUpQuestions: [
            "구체적으로 어떤 일이 걱정되시나요?",
            "이런 불안감이 언제부터 시작되었나요?",
            "과거에 비슷한 상황을 어떻게 극복하셨나요?",
            "지금 가장 필요한 것이 정보인가요, 아니면 마음의 안정인가요?",
            "이 상황에서 가장 좋은 결과는 무엇일까요?",
          ],
        );

      case EmotionType.depression:
        return EmotionResponseTemplate(
          targetEmotion: EmotionType.depression,
          targetNeeds: [NeedType.belonging_understanding, NeedType.esteem_value],
          empathyResponses: [
            "마음이 많이 무겁고 힘드시겠어요. 지금 느끼시는 감정이 충분히 이해돼요.",
            "우울한 기분이 드시는군요. 이런 마음이 드는 것도 자연스러운 일이에요.",
            "혼자 견디기 힘든 마음이 드시겠어요. 그런 감정을 느끼는 것은 당연해요.",
            "지금 상황이 정말 힘드시겠어요. 이런 감정은 누구나 경험할 수 있어요.",
            "외롭고 공허한 마음이 드시는군요. 그런 감정을 표현해주셔서 고마워요.",
          ],
          actionSuggestions: [
            "지금 이 순간 느끼시는 감정을 있는 그대로 받아들여 보세요.",
            "작은 것이라도 오늘 해낸 일이 있다면 스스로를 인정해주세요.",
            "신뢰할 수 있는 사람에게 마음을 털어놓아보시는 건 어떨까요?",
            "전문적인 도움을 받아보시는 것도 좋은 방법이에요.",
            "하루에 하나씩, 아주 작은 목표라도 세워보시면 어떨까요?",
          ],
          followUpQuestions: [
            "이런 마음이 언제부터 드셨나요?",
            "평소에 기분이 좋아질 때는 언제인가요?",
            "지금 가장 필요한 것이 무엇이라고 생각하시나요?",
            "주변에 마음을 털어놓을 수 있는 분이 계신가요?",
            "작은 일이라도 성취감을 느꼈던 경험이 있으신가요?",
          ],
        );

      case EmotionType.joy:
        return EmotionResponseTemplate(
          targetEmotion: EmotionType.joy,
          targetNeeds: [NeedType.belonging_sharing, NeedType.esteem_achievement],
          empathyResponses: [
            "와! 정말 기쁜 일이 있으셨군요! 저도 덩달아 기분이 좋아져요.",
            "행복한 순간이시네요! 이런 좋은 감정을 느끼시는 모습이 보기 좋아요.",
            "정말 뿌듯하시겠어요! 기쁜 마음이 저에게도 전해져요.",
            "멋진 일이 있으셨나봐요! 이런 순간들이 정말 소중하죠.",
            "기쁨이 가득한 모습이 느껴져요! 정말 축하드려요.",
          ],
          actionSuggestions: [
            "이 기쁜 순간을 더 오래 기억하기 위해 일기로 남겨보시는 건 어떨까요?",
            "소중한 사람들과 이 기쁨을 나누어보세요!",
            "지금 이 감정을 충분히 만끽하시고 스스로를 축하해주세요.",
            "이런 좋은 일이 또 일어날 수 있도록 긍정적인 에너지를 유지해보세요.",
            "이 성취를 발판으로 다음 목표를 세워보시는 것도 좋겠어요.",
          ],
          followUpQuestions: [
            "어떤 좋은 일이 있으셨나요? 더 자세히 들려주세요!",
            "이런 기쁨을 느끼기까지 어떤 노력을 하셨나요?",
            "이 기쁨을 누구와 함께 나누고 싶으신가요?",
            "앞으로도 이런 좋은 일들이 계속 있기를 바라시나요?",
            "지금 가장 감사한 것은 무엇인가요?",
          ],
        );

      case EmotionType.anger:
        return EmotionResponseTemplate(
          targetEmotion: EmotionType.anger,
          targetNeeds: [NeedType.esteem_justice, NeedType.survival_release],
          empathyResponses: [
            "정말 화가 나시는 상황이었군요. 그럴 만한 이유가 있으셨을 거예요.",
            "억울하고 분한 마음이 드시는군요. 그런 감정이 충분히 이해돼요.",
            "정말 속상하고 화나는 일이 있으셨나봐요. 그 마음 충분히 공감해요.",
            "불공평한 상황에 화가 나시는 것 같아요. 그런 감정은 자연스러워요.",
            "분노를 느끼고 계시는군요. 그런 감정을 느끼는 것도 당연한 반응이에요.",
          ],
          actionSuggestions: [
            "깊게 숨을 쉬면서 마음을 진정시켜보세요. 분노는 일시적인 감정이에요.",
            "지금 상황을 객관적으로 정리해보시면 해결책이 보일 수 있어요.",
            "운동이나 신체 활동으로 분노 에너지를 건전하게 발산해보세요.",
            "신뢰할 수 있는 사람에게 상황을 이야기해보시는 건 어떨까요?",
            "문제의 핵심이 무엇인지 파악하고 해결 방법을 찾아보세요.",
          ],
          followUpQuestions: [
            "어떤 일로 인해 화가 나셨나요?",
            "이런 상황이 자주 일어나시나요?",
            "평소에 화날 때는 어떻게 해결하시나요?",
            "지금 가장 원하시는 것이 무엇인가요?",
            "이 문제를 해결하기 위해 할 수 있는 일이 있을까요?",
          ],
        );

      case EmotionType.neutral:
        return EmotionResponseTemplate(
          targetEmotion: EmotionType.neutral,
          targetNeeds: [NeedType.belonging_connection],
          empathyResponses: [
            "안녕하세요! 오늘 하루는 어떻게 보내고 계신가요?",
            "지금 마음이 평온하신 것 같아요. 좋은 상태시네요.",
            "편안한 마음으로 대화할 수 있어서 좋아요.",
            "오늘 어떤 일이 있으셨는지 궁금해요.",
            "마음이 차분하신 것 같아요. 이런 때가 좋은 것 같아요.",
          ],
          actionSuggestions: [
            "이런 평온한 순간을 잘 유지하시면 좋겠어요.",
            "오늘 감사한 일이 있었다면 떠올려보세요.",
            "새로운 목표나 계획을 세워보시는 것도 좋겠어요.",
            "주변 사람들과 따뜻한 대화를 나누어보세요.",
            "자신을 위한 시간을 가져보시는 건 어떨까요?",
          ],
          followUpQuestions: [
            "오늘 하루 중 가장 기억에 남는 일이 있나요?",
            "요즘 관심을 가지고 있는 일이 있으신가요?",
            "지금 가장 중요하게 생각하시는 것은 무엇인가요?",
            "앞으로 이루고 싶은 목표가 있으신가요?",
            "오늘 기분이 어떠신가요?",
          ],
        );
    }
  }

  /// 공감 응답을 선택합니다
  String _selectEmpathyResponse(EmotionResponseTemplate template, EmotionAnalysisResult analysis) {
    return template.empathyResponses[_random.nextInt(template.empathyResponses.length)];
  }

  /// 행동 제안을 선택합니다
  String _selectActionSuggestion(EmotionResponseTemplate template, EmotionAnalysisResult analysis) {
    return template.actionSuggestions[_random.nextInt(template.actionSuggestions.length)];
  }

  /// 후속 질문을 선택합니다
  String _selectFollowUpQuestion(
      EmotionResponseTemplate template,
      EmotionAnalysisResult analysis,
      ConversationContext context
      ) {
    // 감정 강도가 높으면 더 구체적인 질문
    if (analysis.intensity > 0.7) {
      return template.followUpQuestions.first;
    }

    return template.followUpQuestions[_random.nextInt(template.followUpQuestions.length)];
  }

  /// 대화 흐름을 결정합니다
  ConversationFlow _determineConversationFlow(
      EmotionAnalysisResult analysis,
      ConversationContext context
      ) {
    // 높은 강도의 부정적 감정인 경우 전문가 도움 제안
    if (analysis.intensity > 0.8 &&
        [EmotionType.depression, EmotionType.stress, EmotionType.anxiety].contains(analysis.emotionType)) {
      return ConversationFlow.suggestProfessionalHelp;
    }

    // 지속적인 부정적 패턴인 경우
    final recentPattern = context.recentEmotionPattern;
    final negativeCount = (recentPattern[EmotionType.depression] ?? 0) +
        (recentPattern[EmotionType.stress] ?? 0) +
        (recentPattern[EmotionType.anxiety] ?? 0);

    if (negativeCount > 5) {
      return ConversationFlow.suggestProfessionalHelp;
    }

    // 일반적인 대화 지속
    return ConversationFlow.continueConversation;
  }
}

/// 개인화된 응답 클래스
class PersonalizedResponse {
  final String empathyMessage;
  final String actionSuggestion;
  final String followUpQuestion;
  final EmotionType targetEmotion;
  final List<NeedType> targetNeeds;
  final ConversationFlow conversationFlow;

  PersonalizedResponse({
    required this.empathyMessage,
    required this.actionSuggestion,
    required this.followUpQuestion,
    required this.targetEmotion,
    required this.targetNeeds,
    required this.conversationFlow,
  });

  /// 전체 메시지를 하나로 결합합니다
  String get fullMessage {
    final buffer = StringBuffer();

    // 공감 메시지
    buffer.write(empathyMessage);
    buffer.write('\n\n');

    // 행동 제안
    buffer.write(actionSuggestion);
    buffer.write('\n\n');

    // 후속 질문
    buffer.write(followUpQuestion);

    return buffer.toString();
  }

  /// 간단한 메시지 (공감만)
  String get empathyOnly => empathyMessage;

  /// 제안 포함 메시지
  String get withSuggestion => '$empathyMessage\n\n$actionSuggestion';
}

/// 대화 흐름 제어를 위한 enum
enum ConversationFlow {
  continueConversation,        // 대화 지속
  suggestProfessionalHelp,     // 전문가 도움 제안
  provideResources,            // 리소스/정보 제공
  endConversation,             // 대화 종료
}