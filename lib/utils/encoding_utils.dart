// 개선된 인코딩 유틸리티 클래스 (Base64 인코딩 사용)
import 'dart:convert'; // utf8, base64, latin1 등을 사용하기 위한 import
import 'package:flutter/material.dart';

// 디버깅 로그 활성화 (개발 중에만 사용)
const bool _enableDebugLog = true;

class EncodingUtils {
  // 텍스트를 Base64로 인코딩
  static String encodeToBase64(String text) {
    try {
      if (text.isEmpty) return text;  // 빈 문자열은 인코딩하지 않음
      
      // 이미 Base64로 인코딩되어 있는지 확인
      if (isBase64Encoded(text)) {
        if (_enableDebugLog) {
          debugPrint('이미 Base64로 인코딩되어 있음: $text');
        }
        return text;  // 이미 인코딩된 경우 그대로 반환
      }
      
      // UTF-8로 변환 후 Base64 인코딩
      final bytes = utf8.encode(text);
      final base64Str = base64.encode(bytes);
      
      if (_enableDebugLog) {
        debugPrint('Base64 인코딩: $text → $base64Str');
      }
      
      return base64Str;
    } catch (e) {
      debugPrint('Base64 인코딩 오류: $e');
      return text;  // 오류 시 원본 반환
    }
  }
  
  // Base64에서 텍스트로 디코딩 (개선된 버전)
  static String decodeFromBase64(String base64Str) {
    try {
      if (base64Str.isEmpty) return base64Str;  // 빈 문자열은 디코딩하지 않음
      
      // Base64 여부 확인
      if (!isBase64Encoded(base64Str)) {
        if (_enableDebugLog) {
          debugPrint('Base64 형식이 아님: $base64Str');
        }
        
        // Base64가 아니지만 깨진 텍스트인 경우 복구 시도
        if (isCorruptedText(base64Str)) {
          return fixCorruptedText(base64Str);
        }
        
        return base64Str;  // Base64가 아니면 원본 반환
      }
      
      try {
        // 기본 Base64 디코딩 시도
        final bytes = base64.decode(base64Str);
        final text = utf8.decode(bytes, allowMalformed: true);
        
        if (_enableDebugLog) {
          debugPrint('Base64 디코딩 성공: $base64Str → $text');
        }
        
        return text;
      } catch (e) {
        debugPrint('UTF-8 디코딩 실패, 다른 방식 시도: $e');
        
        // UTF-8 디코딩 실패 시 다른 방법 시도
        final bytes = base64.decode(base64Str);
        
        try {
          // Latin1으로 디코딩 후 UTF-8로 변환 시도
          final latinText = latin1.decode(bytes);
          final utf8Bytes = latin1.encode(latinText);
          return utf8.decode(utf8Bytes, allowMalformed: true);
        } catch (e2) {
          debugPrint('Latin1 변환 실패: $e2');
          
          // 수동 복구 시도
          final rawText = String.fromCharCodes(bytes);
          return fixCorruptedText(rawText);
        }
      }
    } catch (e) {
      debugPrint('Base64 디코딩 오류: $e');
      return base64Str;  // 오류 시 원본 반환
    }
  }
  
  // 텍스트가 Base64 인코딩되었는지 확인 (개선된 버전)
  static bool isBase64Encoded(String text) {
    try {
      if (text.isEmpty) return false;  // 빈 문자열은 Base64가 아님
      
      // 길이 확인: Base64 인코딩된 문자열의 길이는 항상 4의 배수
      if (text.length % 4 != 0) return false;
      
      // 패딩 검사
      if (text.endsWith('=')) {
        if (text.endsWith('==') && text.length < 4) return false;
        if (!text.endsWith('==') && text.endsWith('=') && text.length < 4) return false;
      }
      
      // 유효한 Base64 문자인지 확인
      final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
      if (!base64Regex.hasMatch(text)) return false;
      
      // 추가 검증: 실제로 디코딩 시도
      try {
        base64.decode(text);
        return true;  // 디코딩 성공
      } catch (_) {
        return false;  // 디코딩 실패 = Base64가 아님
      }
    } catch (e) {
      debugPrint('Base64 확인 오류: $e');
      return false;  // 오류 발생 = Base64가 아니라고 가정
    }
  }
  
  // 자동 감지 및 디코딩 (개선 버전)
  static String autoDecodeIfNeeded(String text) {
    try {
      // 텍스트가 비어 있으면 그대로 반환
      if (text.isEmpty) return text;
      
      // Base64 인코딩 여부 확인
      if (isBase64Encoded(text)) {
        // Base64 디코딩 시도
        try {
          return decodeFromBase64(text);
        } catch (e) {
          debugPrint('자동 디코딩 오류: $e');
          return text;  // 디코딩 오류 시 원본 반환
        }
      }
      
      // Base64가 아니지만 깨진 텍스트인 경우 복구 시도
      if (isCorruptedText(text)) {
        return fixCorruptedText(text);
      }
      
      // Base64가 아니면 원본 텍스트 반환
      return text;
    } catch (e) {
      debugPrint('자동 디코딩 처리 오류: $e');
      return text;  // 오류 시 원본 반환
    }
  }
  
  // 깨진 텍스트인지 확인
  static bool isCorruptedText(String text) {
    // 일반적인 한글 깨짐 패턴 확인
    return text.contains('Ã') || 
           text.contains('Â') || 
           text.contains('ì') || 
           text.contains('ë') ||
           text.contains('í') ||
           text.contains('â') ||
           text.contains('¬') ||
           text.contains('ã') ||
           text.contains('Ã¬') ||
           text.contains('Ã«') ||
           text.contains('Ã­') ||
           text.contains('Ã¢');
  }
  
  // 깨진 텍스트 복구
  static String fixCorruptedText(String text) {
    try {
      if (_enableDebugLog) {
        debugPrint('깨진 텍스트 복구 시도: $text');
      }
      
      // 방법 1: latin1로 인코딩 후 UTF-8로 디코딩
      try {
        final bytes = latin1.encode(text);
        final fixed = utf8.decode(bytes, allowMalformed: true);
        
        if (_enableDebugLog) {
          debugPrint('Latin1 → UTF-8 변환 결과: $fixed');
        }
        
        // 변환 결과가 유의미하면 반환
        if (fixed != text && !fixed.contains('�')) {
          return fixed;
        }
      } catch (e) {
        debugPrint('Latin1 → UTF-8 변환 실패: $e');
      }
      
      // 방법 2: 일반적인 한글 깨짐 패턴 변환
      String result = text;
      final Map<String, String> replacements = {
        'Ã¬': '이', 'Ã«': '느', 'Ã­': '인', 'Ã¢': '아',
        'Â': '', 'Ã': '', '¬': '', 'ì': '이', 'ë': '느',
        'í': '인', 'â': '아', 'ã': '오',
        'Ã¬â': '이', 'Ã«â': '느', 'Ã­â': '인', 'Ã¢â': '아',
        // 추가 패턴...
      };
      
      replacements.forEach((key, value) {
        result = result.replaceAll(key, value);
      });
      
      if (_enableDebugLog) {
        debugPrint('패턴 치환 결과: $result');
      }
      
      return result;
    } catch (e) {
      debugPrint('텍스트 복구 실패: $e');
      return text;  // 오류 시 원본 반환
    }
  }
  
  // UTF-8 인코딩 확인 (기존 호환성 유지)
  static String ensureUtf8(String text) {
    try {
      // 텍스트가 비어 있으면 그대로 반환
      if (text.isEmpty) return text;
      
      // Base64 디코딩이 필요한 경우 자동으로 처리
      if (isBase64Encoded(text)) {
        return decodeFromBase64(text);
      }
      
      // 깨진 텍스트인 경우 복구 시도
      if (isCorruptedText(text)) {
        return fixCorruptedText(text);
      }
      
      // UTF-8 정상 확인 (원본에 UTF-8 인코딩/디코딩을 적용하여 검증)
      final encoded = utf8.encode(text);
      final decoded = utf8.decode(encoded, allowMalformed: true);
      
      return decoded;
    } catch (e) {
      debugPrint('UTF-8 검증 오류: $e');
      return text; // 오류 시 원본 반환
    }
  }
  
  // 모든 인코딩 문제 복구 시도 (최선의 결과 반환)
  static String tryAllFixMethods(String text) {
    if (text.isEmpty) return text;
    
    // 이미 정상적인 텍스트인지 확인
    if (!isCorruptedText(text) && !isBase64Encoded(text)) {
      return text;
    }
    
    try {
      // 1. Base64 디코딩 시도
      if (isBase64Encoded(text)) {
        return decodeFromBase64(text);
      }
      
      // 2. 깨진 텍스트 복구 시도
      if (isCorruptedText(text)) {
        // 여러 방식 시도 및 가장 좋은 결과 반환
        
        // 방법 1: Latin1 변환
        String fixed1 = "";
        try {
          final bytes = latin1.encode(text);
          fixed1 = utf8.decode(bytes, allowMalformed: true);
        } catch (e) {
          debugPrint('방법 1 실패: $e');
        }
        
        // 방법 2: 패턴 치환
        String fixed2 = fixCorruptedText(text);
        
        // 방법 3: ASCII 코드 포인트 조정
        String fixed3 = "";
        try {
          final bytes = text.codeUnits;
          final adjustedBytes = bytes.map((b) => b > 127 ? b - 128 : b).toList();
          fixed3 = String.fromCharCodes(adjustedBytes);
        } catch (e) {
          debugPrint('방법 3 실패: $e');
        }
        
        // 결과 평가 (한글 문자 수가 많은 것을 선택)
        int koreanCount1 = countKoreanChars(fixed1);
        int koreanCount2 = countKoreanChars(fixed2);
        int koreanCount3 = countKoreanChars(fixed3);
        
        if (koreanCount1 >= koreanCount2 && koreanCount1 >= koreanCount3) {
          return fixed1;
        } else if (koreanCount2 >= koreanCount1 && koreanCount2 >= koreanCount3) {
          return fixed2;
        } else {
          return fixed3;
        }
      }
      
      return text;
    } catch (e) {
      debugPrint('모든 인코딩 복구 시도 실패: $e');
      return text;
    }
  }
  
  // 한글 문자 개수 세기 (private에서 public으로 변경)
  static int countKoreanChars(String text) {
    final RegExp koreanRegex = RegExp(r'[ㄱ-ㅎ가-힣]');
    final matches = koreanRegex.allMatches(text);
    return matches.length;
  }
}
