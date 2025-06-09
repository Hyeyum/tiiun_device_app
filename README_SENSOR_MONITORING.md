# 🤖 Tiiun App - Firebase Realtime Database 센서 모니터링 시스템

## 📋 프로젝트 개요

Firebase Realtime Database에서 실시간으로 센서 데이터(습도, 움직임, 타임스탬프)를 모니터링하고, motion 값이 1이 되면 자동으로 AI 대화를 시작하는 Flutter 앱입니다.

## 🔥 주요 기능

### 1. 실시간 센서 모니터링
- Firebase Realtime Database의 `adddelete` 경로 실시간 감시
- 센서 데이터 시간순 정렬 및 시각화
- 습도(humidity), 움직임(motion), 타임스탬프(timestamp) 표시

### 2. 자동 대화 시스템
- **대화 시작**: motion = 1 → 자동 AI 대화 시작
- **스마트 종료**: 30초간 음성 감지 없음 → 자동 대화 종료  
- **타이머 리셋**: 음성 입력 감지 시 30초 타이머 자동 리셋
- 음성 인식 & TTS 기반 실시간 음성 대화

### 3. 데이터 시각화
- 실시간 센서 상태 대시보드
- 최신 센서 데이터 하이라이트
- 센서 데이터 히스토리 목록

## 🚀 빠른 시작

### 1. 프로젝트 실행
```bash
# Windows
start_sensor_monitoring.bat

# Mac/Linux  
chmod +x start_sensor_monitoring.sh
./start_sensor_monitoring.sh
```

### 2. 수동 실행
```bash
flutter pub get
flutter run
```

### 3. 앱 사용법
1. 앱 실행 후 로그인
2. 우상단 메뉴 → "센서 모니터링" 선택
3. Firebase Console에서 motion 값을 1로 변경하여 테스트

## 🔗 Firebase 설정 정보

- **Database URL**: `https://test-f55dc-default-rtdb.asia-southeast1.firebasedatabase.app/`
- **모니터링 경로**: `adddelete`
- **데이터 형식**:
```json
{
  "-ORJDpoCK0G7-qrBI13p": {
    "humidity": 55,
    "motion": 1,
    "timestamp": "2025-05-28 09:12:04"
  }
}
```

## 📱 앱 구조

### 새로 추가된 파일들
```
lib/
├── models/
│   └── sensor_data_model.dart          # 센서 데이터 모델
├── services/
│   └── sensor_monitoring_service.dart  # 센서 모니터링 서비스
└── pages/
    └── sensor_monitor_page.dart        # 센서 UI 페이지
```

### 수정된 파일들
- `lib/main.dart` - 센서 모니터링 라우트 추가
- `lib/pages/realtime_chat_page.dart` - 센서 모니터링 메뉴 추가

## 🛠️ 기술 스택

- **Frontend**: Flutter 3.0+
- **State Management**: Riverpod 2.4+
- **Database**: Firebase Realtime Database
- **Authentication**: Firebase Auth
- **Voice**: flutter_tts, speech_to_text
- **AI**: LangChain, OpenAI

## 📊 모니터링 상태

| 상태 | 설명 |
|------|------|
| `initializing` | 초기화 중 |
| `monitoring` | 센서 모니터링 중 |
| `conversation_active` | AI 대화 진행 중 |
| `no_data` | 센서 데이터 없음 |
| `error` | 오류 발생 |

## 🔧 문제 해결

### 데이터가 표시되지 않는 경우
1. Firebase 프로젝트 설정 확인
2. 네트워크 연결 상태 확인  
3. Firebase Realtime Database 보안 규칙 확인

### 대화가 시작되지 않는 경우
1. motion 값이 실제로 1로 변경되었는지 확인
2. 마이크 권한 설정 확인
3. 음성 서비스 초기화 상태 확인

## 🎯 테스트 방법

1. **Firebase Console 테스트**:
   - Firebase Console → Realtime Database → `adddelete`
   - motion 값을 0 → 1로 변경

2. **앱에서 확인**:
   - 센서 모니터링 페이지에서 실시간 업데이트 확인
   - motion=1일 때 대화 시작 알림 확인

## 📞 지원

문제 발생 시 확인사항:
- Flutter 콘솔 로그
- Firebase Console 데이터 구조
- 네트워크 연결 상태
- 앱 권한 설정

---

🤖 **30초 무음성 감지 시스템으로 더 스마트하고 자연스러운 AI 대화를 경험하세요!**

## 🆕 주요 변경사항

### 대화 종료 로직 개선:
- **기존**: motion=0 → 즉시 대화 종료
- **신규**: 30초 무음성 감지 → 스마트 자동 종료
- **장점**: 더 자연스러운 대화 흐름, 의도하지 않은 대화 중단 방지

### 타이머 시스템:
- 대화 시작 시 30초 카운트다운 시작
- 음성 활동 감지 시 타이머 자동 리셋
- 타이머 만료 시 정중한 종료 메시지

## 📞 지원

문제가 발생하면 다음을 확인해주세요:
1. Flutter 콘솔 로그 확인
2. Firebase Console에서 데이터 구조 확인
3. 네트워크 연결 상태 확인
4. 마이크 권한 및 음성 서비스 상태 확인
