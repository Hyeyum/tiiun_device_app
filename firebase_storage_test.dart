// Firebase Storage 연결 테스트를 위한 임시 함수 (debug용)
// chatting_page.dart에 추가할 수 있는 테스트 함수

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

Future<void> _testFirebaseStorageConnection() async {
  try {
    final storage = FirebaseStorage.instance;
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      print('❌ 사용자가 로그인되어 있지 않습니다');
      return;
    }
    
    // 테스트 파일 생성
    final tempDir = await getTemporaryDirectory();
    final testFile = File('${tempDir.path}/test_connection.txt');
    await testFile.writeAsString('Firebase Storage 연결 테스트');
    
    // 업로드 테스트
    final ref = storage.ref().child('test/${user.uid}/connection_test.txt');
    
    print('🔄 Firebase Storage 업로드 테스트 시작...');
    final uploadTask = await ref.putFile(testFile);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    
    print('✅ Firebase Storage 연결 성공!');
    print('📤 업로드 URL: $downloadUrl');
    
    // 테스트 파일 삭제
    await ref.delete();
    await testFile.delete();
    
    print('🧹 테스트 파일 정리 완료');
    
  } catch (e, stackTrace) {
    print('❌ Firebase Storage 연결 실패: $e');
    print('📋 Stack trace: $stackTrace');
  }
}
