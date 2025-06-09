# 🎯 방법 1: Firebase Realtime Database 트리거 시스템 설정 가이드

## 📋 설정 단계

### 1단계: Firebase Console 설정

#### A. Remote Config 설정
Firebase Console → Remote Config → 매개변수 추가:

```json
{
  "openai_api_key": "sk-proj-your-actual-openai-api-key-here",
  "trigger_path": "conversation_trigger",
  "trigger_value": "start_conversation",
  "reset_value": "idle"
}
```

#### B. Realtime Database 설정
Firebase Console → Realtime Database → 데이터 구조:

```json
{
  "test": {
    "-ORJDpoCK0G7-qrBI13p": {
      "humidity": 55,
      "motion": 1,
      "timestamp": "2025-05-28 09:12:04"
    }
  },
  "conversation_trigger": "idle"  // ← 새로 추가
}
```

### 2단계: 앱 테스트

#### A. 수동 트리거 테스트
1. 앱 실행 → RealtimeChatPage 이동
2. Firebase Console에서 `conversation_trigger` 값을 `"start_conversation"`으로 변경
3. 앱에서 즉시 대화 시작됨
4. 자동으로 `"idle"`로 리셋됨

#### B. 연결 상태 확인
앱 실행 시 다음 메시지들이 나타나야 함:
- "✅ Firebase Realtime Database에 연결되었습니다."
- "📡 경로 conversation_trigger에서 값 start_conversation 감지 대기 중..."

### 3단계: 센서 연동 (선택사항)

#### A. Python 스크립트 설정
1. `sensor_trigger_script.py` 파일 수정:
   ```python
   SERVICE_ACCOUNT_PATH = 'path/to/your/serviceAccountKey.json'
   DATABASE_URL = 'https://test-f55dc-default-rtdb.asia-southeast1.firebasedatabase.app/'
   ```

2. 필요한 Python 패키지 설치:
   ```bash
   pip install firebase-admin
   ```

3. Firebase 서비스 계정 키 다운로드:
   - Firebase Console → 프로젝트 설정 → 서비스 계정
   - "새 비공개 키 생성" 클릭
   - JSON 파일 다운로드

#### B. 스크립트 실행
```bash
# 연속 모니터링 모드
python sensor_trigger_script.py

# 수동 테스트 모드
python sensor_trigger_script.py test
```

## 🧪 테스트 시나리오

### 시나리오 1: 수동 트리거
1. Firebase Console에서 `conversation_trigger` → `"start_conversation"`
2. 앱: "🎯 트리거 감지! 대화를 시작합니다..."
3. AI: "안녕하세요! 트리거가 감지되어 대화를 시작합니다."
4. 실시간 음성 대화 시작

### 시나리오 2: 센서 자동 트리거
1. 센서에서 motion: 0 → 1 감지
2. 스크립트: `conversation_trigger` → `"start_conversation"`
3. 앱: 즉시 대화 시작
4. 스크립트: 3초 후 `conversation_trigger` → `"idle"`

### 시나리오 3: 쿨다운 테스트
1. 첫 번째 트리거 → 대화 시작
2. 10초 이내 추가 트리거 → 무시됨
3. 10초 후 트리거 → 새 대화 시작

## 🔧 문제 해결

### 문제: 트리거가 감지되지 않음
- Firebase Console에서 `conversation_trigger` 경로 존재 확인
- Remote Config 값 확인
- 앱 재시작

### 문제: OpenAI API 응답 없음
- Remote Config의 `openai_api_key` 확인
- API 키 유효성 확인
- 네트워크 연결 확인

### 문제: 센서 데이터가 저장되지 않음
- Firebase 서비스 계정 키 확인
- Database Rules 확인
- 인터넷 연결 확인

## 📊 모니터링

### 앱 로그 확인
```
✅ Remote Config initialized and fetched.
🔧 Remote Config Values:
   - OpenAI API Key: 설정됨
   - Trigger Path: conversation_trigger
   - Trigger Value: start_conversation
   - Reset Value: idle
```

### 센서 스크립트 로그 확인
```
✅ Firebase 초기화 완료
📊 센서 데이터 저장: motion=1, humidity=55
🎯 새로운 움직임 감지! 대화 트리거 발송...
✅ 대화 트리거 완료!
```

## 🚀 고급 설정

### 다중 트리거 지원
Remote Config에 추가 설정:
```json
{
  "emergency_trigger_value": "emergency_call",
  "meditation_trigger_value": "meditation_mode"
}
```

### 시간대별 다른 인사말
센서 스크립트에서 시간 정보 포함:
```python
trigger_data = {
  "action": "start_conversation",
  "time_of_day": "morning",  # morning, afternoon, evening
  "context": "motion_detected"
}
```
