#!/usr/bin/env python3
# 🧪 Firebase 트리거 테스트 스크립트 (간단 버전)

import requests
import json
import time

class FirebaseTriggerTester:
    def __init__(self, database_url):
        """
        Firebase Realtime Database URL로 초기화
        예: https://test-f55dc-default-rtdb.asia-southeast1.firebasedatabase.app/
        """
        self.database_url = database_url.rstrip('/')
        self.trigger_path = 'conversation_trigger'
    
    def set_trigger_value(self, value):
        """트리거 값 설정"""
        url = f"{self.database_url}/{self.trigger_path}.json"
        
        try:
            response = requests.put(url, json=value)
            if response.status_code == 200:
                print(f"✅ 트리거 값 설정 완료: {value}")
                return True
            else:
                print(f"❌ 설정 실패: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 오류: {e}")
            return False
    
    def get_trigger_value(self):
        """현재 트리거 값 확인"""
        url = f"{self.database_url}/{self.trigger_path}.json"
        
        try:
            response = requests.get(url)
            if response.status_code == 200:
                value = response.json()
                print(f"📡 현재 트리거 값: {value}")
                return value
            else:
                print(f"❌ 값 읽기 실패: {response.status_code}")
                return None
        except Exception as e:
            print(f"❌ 오류: {e}")
            return None
    
    def manual_trigger_test(self):
        """수동 트리거 테스트"""
        print("🧪 수동 트리거 테스트 시작...")
        
        # 1. 현재 상태 확인
        current_value = self.get_trigger_value()
        
        # 2. 트리거 발송
        print("🎯 대화 시작 트리거 발송...")
        if self.set_trigger_value("start_conversation"):
            print("   → 앱에서 대화가 시작되어야 합니다!")
        
        # 3. 3초 대기
        print("⏳ 3초 대기...")
        time.sleep(3)
        
        # 4. 초기화
        print("🔄 트리거 초기화...")
        self.set_trigger_value("idle")
        
        print("✅ 테스트 완료!")
    
    def continuous_trigger_test(self, interval=10):
        """연속 트리거 테스트"""
        print(f"🔄 {interval}초마다 트리거 발송 시작...")
        print("   종료: Ctrl+C")
        
        try:
            while True:
                self.manual_trigger_test()
                print(f"⏳ {interval}초 대기...")
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\n🛑 연속 테스트 종료")

def main():
    # 🔧 실제 Firebase Database URL로 수정하세요
    DATABASE_URL = "https://test-f55dc-default-rtdb.asia-southeast1.firebasedatabase.app/"
    
    tester = FirebaseTriggerTester(DATABASE_URL)
    
    print("🎯 Firebase 트리거 테스터")
    print("=" * 40)
    print("1. 수동 트리거 테스트")
    print("2. 연속 트리거 테스트")
    print("3. 현재 값 확인")
    print("4. 트리거 초기화")
    
    try:
        choice = input("\n선택하세요 (1-4): ").strip()
        
        if choice == "1":
            tester.manual_trigger_test()
        elif choice == "2":
            interval = int(input("간격(초, 기본 10): ") or "10")
            tester.continuous_trigger_test(interval)
        elif choice == "3":
            tester.get_trigger_value()
        elif choice == "4":
            tester.set_trigger_value("idle")
        else:
            print("❌ 잘못된 선택입니다.")
            
    except KeyboardInterrupt:
        print("\n👋 종료합니다.")
    except Exception as e:
        print(f"❌ 오류: {e}")

if __name__ == "__main__":
    main()
