# 🎯 방법 1: 기존 구조 유지 - 센서 트리거 스크립트
# Firebase Realtime Database에 센서 데이터 저장 + 대화 트리거

import firebase_admin
from firebase_admin import credentials, db
import time
from datetime import datetime
import json
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SensorTriggerSystem:
    def __init__(self, service_account_path, database_url):
        """
        센서 트리거 시스템 초기화
        
        Args:
            service_account_path: Firebase 서비스 계정 키 파일 경로
            database_url: Firebase Realtime Database URL
        """
        try:
            # Firebase 초기화
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred, {
                'databaseURL': database_url
            })
            
            # 데이터베이스 참조
            self.sensor_ref = db.reference('test')  # 기존 센서 데이터 경로
            self.trigger_ref = db.reference('conversation_trigger')  # 대화 트리거 경로
            
            # 상태 변수
            self.previous_motion = 0
            self.last_trigger_time = 0
            self.trigger_cooldown = 10  # 10초 쿨다운 (중복 트리거 방지)
            
            logger.info("✅ Firebase 초기화 완료")
            logger.info(f"   - 센서 데이터 경로: test")
            logger.info(f"   - 트리거 경로: conversation_trigger")
            
        except Exception as e:
            logger.error(f"❌ Firebase 초기화 실패: {e}")
            raise
    
    def read_sensors(self):
        """
        실제 센서에서 데이터 읽기
        이 부분을 실제 센서 라이브러리로 대체하세요
        """
        # 🔧 실제 센서 코드로 대체할 부분
        # 예시: DHT22 센서 + PIR 센서
        
        try:
            # 습도 센서 읽기 (임시로 고정값 사용)
            humidity = 55  # 실제: dht.humidity
            
            # 모션 센서 읽기 (임시로 시뮬레이션)
            import random
            motion = random.choice([0, 0, 0, 1])  # 25% 확률로 움직임 감지
            
            return humidity, motion
            
        except Exception as e:
            logger.error(f"센서 읽기 오류: {e}")
            return 50, 0  # 기본값 반환
    
    def save_sensor_data(self, humidity, motion):
        """센서 데이터를 Firebase에 저장"""
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            sensor_data = {
                'humidity': humidity,
                'motion': motion,
                'timestamp': timestamp
            }
            
            # 센서 데이터 저장 (기존 구조 유지)
            self.sensor_ref.push(sensor_data)
            logger.info(f"📊 센서 데이터 저장: motion={motion}, humidity={humidity}")
            
        except Exception as e:
            logger.error(f"센서 데이터 저장 오류: {e}")
    
    def trigger_conversation_if_needed(self, motion):
        """움직임 감지시 대화 트리거"""
        try:
            current_time = time.time()
            
            # 0에서 1로 변할 때만 트리거 (새로운 움직임 감지)
            if (self.previous_motion == 0 and motion == 1 and 
                current_time - self.last_trigger_time > self.trigger_cooldown):
                
                logger.info("🎯 새로운 움직임 감지! 대화 트리거 발송...")
                
                # 대화 시작 트리거
                self.trigger_ref.set('start_conversation')
                logger.info("✅ 대화 트리거 완료!")
                
                # 마지막 트리거 시간 업데이트
                self.last_trigger_time = current_time
                
                # 3초 후 자동 리셋 (앱에서도 리셋하지만 이중 보장)
                time.sleep(3)
                self.trigger_ref.set('idle')
                logger.info("🔄 트리거 값 초기화 완료")
                
            elif motion == 1:
                logger.debug("움직임 감지됨 (쿨다운 중이거나 연속 움직임)")
            
            self.previous_motion = motion
            
        except Exception as e:
            logger.error(f"트리거 처리 오류: {e}")
    
    def check_trigger_status(self):
        """현재 트리거 상태 확인"""
        try:
            current_value = self.trigger_ref.get()
            logger.info(f"📡 현재 트리거 상태: {current_value}")
            return current_value
        except Exception as e:
            logger.error(f"트리거 상태 확인 오류: {e}")
            return None
    
    def manual_trigger_test(self):
        """수동 트리거 테스트"""
        try:
            logger.info("🧪 수동 트리거 테스트 시작...")
            self.trigger_ref.set('start_conversation')
            logger.info("✅ 수동 트리거 발송 완료!")
            
            time.sleep(3)
            self.trigger_ref.set('idle')
            logger.info("🔄 트리거 초기화 완료")
            
        except Exception as e:
            logger.error(f"수동 트리거 테스트 오류: {e}")
    
    def run_continuous_monitoring(self):
        """연속 센서 모니터링 실행"""
        logger.info("🚀 센서 모니터링 시작...")
        logger.info("   - 종료: Ctrl+C")
        logger.info("   - 트리거 쿨다운: 10초")
        
        # 초기 트리거 상태 확인
        self.check_trigger_status()
        
        cycle_count = 0
        
        try:
            while True:
                cycle_count += 1
                
                # 센서 데이터 읽기
                humidity, motion = self.read_sensors()
                
                # Firebase에 센서 데이터 저장
                self.save_sensor_data(humidity, motion)
                
                # 필요시 대화 트리거
                self.trigger_conversation_if_needed(motion)
                
                # 10회마다 상태 로그
                if cycle_count % 10 == 0:
                    logger.info(f"📊 모니터링 사이클: {cycle_count}, 현재 motion: {motion}")
                
                # 1초 대기
                time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("\n🛑 센서 모니터링 종료")
        except Exception as e:
            logger.error(f"모니터링 오류: {e}")
            time.sleep(5)  # 오류시 5초 대기 후 재시도


def main():
    """메인 실행 함수"""
    # 🔧 설정값 - 실제 값으로 수정하세요
    SERVICE_ACCOUNT_PATH = 'path/to/your/serviceAccountKey.json'  # Firebase 서비스 계정 키
    DATABASE_URL = 'https://test-f55dc-default-rtdb.asia-southeast1.firebasedatabase.app/'  # 실제 Database URL
    
    try:
        # 센서 트리거 시스템 초기화
        sensor_system = SensorTriggerSystem(SERVICE_ACCOUNT_PATH, DATABASE_URL)
        
        # 실행 모드 선택
        import sys
        if len(sys.argv) > 1 and sys.argv[1] == 'test':
            # 수동 테스트 모드
            sensor_system.manual_trigger_test()
        else:
            # 연속 모니터링 모드
            sensor_system.run_continuous_monitoring()
            
    except Exception as e:
        logger.error(f"❌ 시스템 실행 오류: {e}")


if __name__ == "__main__":
    main()
