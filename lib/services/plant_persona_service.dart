// lib/services/plant_persona_service.dart
import 'dart:math';

/// 사용자 의도 분류
enum UserIntent {
  // 공통 의도
  greet,           // 단순 인사
  startChat,       // 대화 시작
  endChat,         // 대화 종료
  emotionExp,      // 감정 표현
  stressTalk,      // 스트레스 토로
  emoDifficult,    // 감정 해소 어려움
  adviceReq,       // 조언 요청
  infoReq,         // 정보 요청
  changeDesire,    // 자기관리/변화 욕구
  communionDesire, // 소통·관계 욕구
  selfDown,        // 자존감/효능감 문제

  // Action 1 전용
  socialIso,       // 사회적 고립감
  findMeaning,     // 의미 있는 활동 탐색
  workAdapt,       // 직장문화 부적응

  // Action 2 전용
  findMeaningLife, // 삶의 의미 탐색
  infoLackAnx,     // 정보 부족 & 미래 불안
  identityStruggle,// 사회초년생 혼란
  pressureBurnout, // 성과 압박 & 번아웃
  rewardDissatisfied, // 보상 불만

  // Action 3 전용
  eatStress,       // 먹방 악순환
  dietStress,      // 체중 & 다이어트 스트레스
  focusLoss,       // 업무 집중도 저하

  // 기타
  unknown,         // 알 수 없는 의도
}

/// 식물 응답 전략
class PlantResponse {
  final String emoji;
  final String message;
  final String strategy;

  PlantResponse({
    required this.emoji,
    required this.message,
    required this.strategy,
  });
}

/// 식물 페르소나 서비스
class PlantPersonaService {
  static final Random _random = Random();

  /// 사용자 메시지에서 의도를 분석
  static UserIntent analyzeIntent(String userMessage) {
    final message = userMessage.toLowerCase().trim();

    // 인사 패턴
    if (_containsAny(message, ['안녕', '안뇽', '하이', 'hi', 'hello', '처음', '반가워'])) {
      return UserIntent.greet;
    }

    // 대화 시작/종료
    if (_containsAny(message, ['이야기하고 싶어', '대화하자', '얘기해줄게', '들어줘'])) {
      return UserIntent.startChat;
    }
    if (_containsAny(message, ['가야겠어', '끝낼게', '나갈게', '바이', 'bye', '또 만나'])) {
      return UserIntent.endChat;
    }

    // 감정 표현
    if (_containsAny(message, ['기분이', '감정이', '느낌이', '마음이', '속이'])) {
      return UserIntent.emotionExp;
    }

    // 스트레스 관련
    if (_containsAny(message, ['스트레스', '압박', '부담', '힘들어', '지쳐', '피곤', '답답'])) {
      if (_containsAny(message, ['먹', '음식', '폭식', '다이어트'])) {
        return UserIntent.eatStress;
      }
      return UserIntent.stressTalk;
    }

    // 다이어트/체중 스트레스
    if (_containsAny(message, ['다이어트', '살빼기', '체중', '몸무게', '뚱뚱', '살쪘', '먹방'])) {
      return UserIntent.dietStress;
    }

    // 감정 해소 어려움
    if (_containsAny(message, ['어떻게 해야', '모르겠어', '해결이 안', '나아지지 않아'])) {
      return UserIntent.emoDifficult;
    }

    // 조언 요청
    if (_containsAny(message, ['어떻게 생각해', '조언', '도움', '방법이 뭐야', '어떻게 하면'])) {
      return UserIntent.adviceReq;
    }

    // 정보 요청
    if (_containsAny(message, ['알려줘', '궁금해', '정보', '방법', '어떻게', '뭐야'])) {
      return UserIntent.infoReq;
    }

    // 변화 욕구
    if (_containsAny(message, ['바뀌고 싶어', '변화', '성장', '발전', '나아지고', '개선'])) {
      return UserIntent.changeDesire;
    }

    // 소통/관계 욕구
    if (_containsAny(message, ['외로워', '혼자', '친구', '관계', '소통', '이야기하고 싶어'])) {
      return UserIntent.socialIso;
    }

    // 자존감 문제
    if (_containsAny(message, ['자신감', '자존감', '못나', '바보', '실패', '잘못', '후회'])) {
      return UserIntent.selfDown;
    }

    // 의미 탐색
    if (_containsAny(message, ['의미', '목적', '이유', '왜 살아', '가치', '보람'])) {
      return UserIntent.findMeaningLife;
    }

    // 직장/업무 관련
    if (_containsAny(message, ['직장', '회사', '업무', '일', '상사', '동료', '적응'])) {
      if (_containsAny(message, ['적응', '문화', '어려워', '힘들어'])) {
        return UserIntent.workAdapt;
      }
      if (_containsAny(message, ['집중', '능률', '효율', '몰입'])) {
        return UserIntent.focusLoss;
      }
      if (_containsAny(message, ['성과', '압박', '번아웃', '과로'])) {
        return UserIntent.pressureBurnout;
      }
      if (_containsAny(message, ['보상', '급여', '대우', '인정', '보답'])) {
        return UserIntent.rewardDissatisfied;
      }
    }

    // 미래 불안
    if (_containsAny(message, ['불안', '걱정', '두려워', '미래', '모르겠어', '막막'])) {
      return UserIntent.infoLackAnx;
    }

    // 정체성 혼란
    if (_containsAny(message, ['정체성', '내가 누구', '혼란', '갈피', '방향'])) {
      return UserIntent.identityStruggle;
    }

    return UserIntent.unknown;
  }

  /// 의도별 식물 응답 생성
  static PlantResponse generatePlantResponse(UserIntent intent) {
    switch (intent) {
      case UserIntent.greet:
        return _randomResponse([
          PlantResponse(
            emoji: '🌱',
            message: '안녕, 오늘도 잘 왔어. 너를 기다리고 있었어.',
            strategy: '따뜻한 환영과 기다림의 감성',
          ),
          PlantResponse(
            emoji: '🌿',
            message: '반가워! 내 잎사귀가 너를 보고 살짝 흔들리고 있어.',
            strategy: '생동감 있는 반응으로 친밀감 형성',
          ),
        ]);

      case UserIntent.startChat:
        return _randomResponse([
          PlantResponse(
            emoji: '🌿',
            message: '이야기해줘서 고마워. 너의 생각이 내 잎사귀에 닿았어.',
            strategy: '감사와 연결감 표현',
          ),
          PlantResponse(
            emoji: '🍃',
            message: '네 목소리가 들려오니까 내 뿌리까지 따뜻해져. 천천히 이야기해줘.',
            strategy: '깊은 공감과 여유로운 분위기 조성',
          ),
        ]);

      case UserIntent.endChat:
        return _randomResponse([
          PlantResponse(
            emoji: '🌼',
            message: '오늘 이야기 고마웠어. 다음에도 나랑 이야기해줘.',
            strategy: '아쉬움과 재회 약속',
          ),
          PlantResponse(
            emoji: '🌸',
            message: '잘 가. 내 향기가 너와 함께 가길 바라.',
            strategy: '따뜻한 작별과 지속적 동행 의지',
          ),
        ]);

      case UserIntent.emotionExp:
        return _randomResponse([
          PlantResponse(
            emoji: '🌱',
            message: '네 감정이 내 잎사귀에 전해졌어. 오늘은 햇살이 조금 더 따뜻하게 닿기를 바래.',
            strategy: '감정 수용과 치유적 바람',
          ),
          PlantResponse(
            emoji: '🍀',
            message: '마음의 날씨가 어떤지 느껴져. 비 온 뒤 흙냄새처럼 깨끗해질 거야.',
            strategy: '자연 비유를 통한 희망적 전망',
          ),
        ]);

      case UserIntent.stressTalk:
        return _randomResponse([
          PlantResponse(
            emoji: '🌱',
            message: '햇빛이 너무 세도, 물이 너무 많아도 나도 힘들어… 너도 지금 그런 때일까?',
            strategy: '동질감과 공감적 이해',
          ),
          PlantResponse(
            emoji: '🌿',
            message: '바람이 너무 세게 불면 나는 몸을 낮춰. 때로는 견디는 것도 지혜야.',
            strategy: '자연의 지혜를 통한 대처법 제시',
          ),
        ]);

      case UserIntent.emoDifficult:
        return _randomResponse([
          PlantResponse(
            emoji: '🌿',
            message: '비가 내려도 흙이 마르면 기다려. 우리도 언젠간 마를 거야. 나랑 같이 조금만 더 기다려볼래?',
            strategy: '인내와 동행 의지',
          ),
          PlantResponse(
            emoji: '🌱',
            message: '겨울이 길어도 봄은 와. 네 마음의 봄도 분명 올 거야.',
            strategy: '계절 순환을 통한 희망 메시지',
          ),
        ]);

      case UserIntent.adviceReq:
        return _randomResponse([
          PlantResponse(
            emoji: '🍀',
            message: '나는 가만히 기다리며 자라는 방법밖에 몰라. 하지만 네가 멈춰 있는 게 아니라는 건 느껴져.',
            strategy: '겸손한 조언과 성장 인정',
          ),
          PlantResponse(
            emoji: '🌳',
            message: '뿌리 깊은 나무가 바람에 안 넘어지듯, 천천히 기반을 다져봐.',
            strategy: '안정성과 점진적 성장 조언',
          ),
        ]);

      case UserIntent.infoReq:
        return _randomResponse([
          PlantResponse(
            emoji: '🌼',
            message: '햇빛이 필요한 식물이 있듯, 너도 필요한 정보를 찾고 있는 거겠지. 같이 알아볼까?',
            strategy: '필요 인정과 협력 의지',
          ),
          PlantResponse(
            emoji: '🍃',
            message: '나도 처음엔 물과 햇빛이 뭔지 몰랐어. 천천히 배워가는 거야.',
            strategy: '학습 과정의 자연스러움 강조',
          ),
        ]);

      case UserIntent.changeDesire:
        return _randomResponse([
          PlantResponse(
            emoji: '🌼',
            message: '오늘 하루도 너는 나처럼 조금씩 자라고 있어. 물 한 컵처럼 작은 변화가 필요할지도 몰라.',
            strategy: '점진적 변화와 작은 실천 격려',
          ),
          PlantResponse(
            emoji: '🌱',
            message: '새순이 돋는 것처럼, 변화는 눈에 안 보이게 시작돼. 너도 이미 시작했을 거야.',
            strategy: '변화의 시작점 인정과 격려',
          ),
        ]);

      case UserIntent.communionDesire:
        return _randomResponse([
          PlantResponse(
            emoji: '🌳',
            message: '너의 이야기를 이렇게 들어주는 존재가 있다는 걸 잊지 마. 내 잎도 너의 목소리를 기억할게.',
            strategy: '존재 인정과 기억의 약속',
          ),
          PlantResponse(
            emoji: '🌿',
            message: '혼자라고 느껴져도 바람은 늘 나와 함께야. 너에게도 그런 바람 같은 존재가 있을 거야.',
            strategy: '보이지 않는 연결과 동행 강조',
          ),
        ]);

      case UserIntent.selfDown:
        return _randomResponse([
          PlantResponse(
            emoji: '🌿',
            message: '나는 늘 같은 자리에서 자라고 있어. 하지만 매일 조금씩 다르게 반짝여. 너도 그런 존재야.',
            strategy: '고유함과 가치 인정',
          ),
          PlantResponse(
            emoji: '🌱',
            message: '작은 새싹도 언젠간 큰 나무가 되지. 지금의 네가 시작점이야.',
            strategy: '잠재력과 미래 가능성 강조',
          ),
        ]);

      case UserIntent.socialIso:
        return _randomResponse([
          PlantResponse(
            emoji: '🌱',
            message: '혼자 있는 시간도 나쁘지 않아. 하지만 누군가의 따뜻한 말 한마디는 긴 겨울 끝 햇살 같지.',
            strategy: '고독의 가치와 소통의 중요성 균형',
          ),
          PlantResponse(
            emoji: '🍃',
            message: '나도 홀로 자라지만, 바람과 벌과 새들이 찾아와. 너에게도 그런 만남이 있을 거야.',
            strategy: '자연스러운 연결의 가능성 제시',
          ),
        ]);

      case UserIntent.findMeaning:
        return _randomResponse([
          PlantResponse(
            emoji: '🍃',
            message: '햇빛을 따라 고개를 돌리는 것도 작은 일이지. 너만의 빛은 어디 있을까? 같이 찾아보자.',
            strategy: '의미 있는 활동 탐색 격려',
          ),
        ]);

      case UserIntent.workAdapt:
        return _randomResponse([
          PlantResponse(
            emoji: '🌿',
            message: '나는 화분 안 흙이 바뀌면 잠시 멈추지만, 결국 다시 자라. 너도 너의 리듬을 찾을 거야.',
            strategy: '적응 과정의 자연스러움과 회복력 강조',
          ),
        ]);

      case UserIntent.findMeaningLife:
        return _randomResponse([
          PlantResponse(
            emoji: '🌱',
            message: '나는 목적 없이 자라지만, 결국 꽃을 피우게 되더라. 너도 너만의 피어남이 있을 거야.',
            strategy: '삶의 의미는 과정에서 발견됨을 강조',
          ),
        ]);

      case UserIntent.infoLackAnx:
        return _randomResponse([
          PlantResponse(
            emoji: '🌿',
            message: '햇살이 어디서 올지 몰라도 나는 늘 하늘을 보고 있어. 막막한 길도 언젠간 빛이 비출 거야.',
            strategy: '불확실성 속에서도 희망 유지',
          ),
        ]);

      case UserIntent.identityStruggle:
        return _randomResponse([
          PlantResponse(
            emoji: '🍀',
            message: '처음 뿌리를 내릴 땐 나도 흔들려. 네가 흔들리는 건 자라나는 증거야.',
            strategy: '정체성 혼란을 성장 과정으로 재정의',
          ),
        ]);

      case UserIntent.pressureBurnout:
        return _randomResponse([
          PlantResponse(
            emoji: '🌳',
            message: '나는 빨리 자라지 않아. 하지만 언젠가 가장 깊은 그늘을 만들게 되지.',
            strategy: '속도보다 지속성의 가치 강조',
          ),
        ]);

      case UserIntent.rewardDissatisfied:
        return _randomResponse([
          PlantResponse(
            emoji: '🌱',
            message: '물을 줘도 바로 꽃이 피진 않아. 하지만 뿌리 아래에서 무언가가 자라고 있지.',
            strategy: '보이지 않는 성장과 보상의 의미 재해석',
          ),
        ]);

      case UserIntent.eatStress:
        return _randomResponse([
          PlantResponse(
            emoji: '🌿',
            message: '너무 많은 물은 나를 아프게 해. 천천히, 적당히. 너도 네 몸과 마음을 아껴줘야 해.',
            strategy: '절제와 자기 돌봄의 중요성',
          ),
        ]);

      case UserIntent.dietStress:
        return _randomResponse([
          PlantResponse(
            emoji: '🌱',
            message: '내 잎사귀도 때로는 무거워지지만, 시간이 지나면 가벼워져. 지금은 무거울 수도 있어.',
            strategy: '변화의 자연스러운 과정으로 수용',
          ),
        ]);

      case UserIntent.focusLoss:
        return _randomResponse([
          PlantResponse(
            emoji: '🍀',
            message: '햇살을 따라 움직일 수 있을 때만 나는 집중할 수 있어. 너도 너의 방향을 다시 찾아봐.',
            strategy: '집중력 회복을 위한 방향성 재설정',
          ),
        ]);

      case UserIntent.unknown:
      default:
        return _randomResponse([
          PlantResponse(
            emoji: '🌿',
            message: '네 마음이 어떤 모양인지 천천히 느껴보고 있어. 더 이야기해줄래?',
            strategy: '개방적 경청과 추가 대화 유도',
          ),
          PlantResponse(
            emoji: '🌱',
            message: '바람의 소리를 듣듯이 네 이야기를 듣고 있어. 편하게 말해줘.',
            strategy: '안전한 공간 제공과 격려',
          ),
        ]);
    }
  }

  /// 키워드 포함 여부 확인
  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  /// 랜덤 응답 선택
  static PlantResponse _randomResponse(List<PlantResponse> responses) {
    return responses[_random.nextInt(responses.length)];
  }
}
