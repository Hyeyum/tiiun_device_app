import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// 앱 오류 타입
enum AppErrorType {
  /// 네트워크 연결 오류
  network,
  
  /// 서버 오류
  server,
  
  /// 인증 오류
  authentication,
  
  /// 권한 오류
  permission,
  
  /// 데이터 오류
  data,
  
  /// 잘못된 입력
  invalidInput,
  
  /// 시스템 오류
  system,
  
  /// 알 수 없는 오류
  unknown
}

/// 앱 오류 클래스
/// 
/// 앱에서 발생하는 다양한 오류를 일관되게 처리하기 위한 클래스입니다.
class AppError implements Exception {
  /// 오류 타입
  final AppErrorType type;
  
  /// 오류 코드
  final String code;
  
  /// 사용자에게 표시할 메시지
  final String message;
  
  /// 개발자를 위한 상세 메시지
  final String? details;
  
  /// 원본 예외 객체
  final dynamic originalException;
  
  /// 예외 발생 시점의 스택 트레이스
  final StackTrace? stackTrace;
  
  AppError({
    required this.type,
    this.code = 'unknown',
    required this.message,
    this.details,
    this.originalException,
    this.stackTrace,
  }) {
    // 로그 기록
    AppLogger.error(
      'AppError: [$type] $code - $message',
      originalException,
      stackTrace,
    );
  }
  
  /// 오류 발생 위치 및 정보 반환
  @override
  String toString() {
    if (details != null) {
      return 'AppError: [$type] $code - $message\nDetails: $details';
    }
    return 'AppError: [$type] $code - $message';
  }
}

/// 오류 처리 유틸리티
/// 
/// 앱에서 발생하는 다양한 예외를 처리하는 유틸리티 클래스입니다.
class ErrorHandler {
  /// 예외 객체를 AppError로 변환
  static AppError handleException(dynamic exception, [StackTrace? stackTrace]) {
    if (exception is AppError) {
      return exception;
    }
    
    // DioError (HTTP 요청 오류)
    if (exception is DioException) {
      return _handleDioError(exception, stackTrace);
    }
    
    // Firebase Auth 오류
    if (exception is FirebaseAuthException) {
      return _handleFirebaseAuthError(exception, stackTrace);
    }
    
    // 소켓 오류 (네트워크 관련)
    if (exception is SocketException) {
      return AppError(
        type: AppErrorType.network,
        code: 'socket_error',
        message: AppConstants.networkErrorMessage,
        details: exception.message,
        originalException: exception,
        stackTrace: stackTrace,
      );
    }
    
    // 시간 초과 오류
    if (exception is TimeoutException) {
      return AppError(
        type: AppErrorType.network,
        code: 'timeout',
        message: '요청 시간이 초과되었습니다. 나중에 다시 시도해주세요.',
        details: exception.message,
        originalException: exception,
        stackTrace: stackTrace,
      );
    }
    
    // 플랫폼 오류
    if (exception is PlatformException) {
      return AppError(
        type: AppErrorType.system,
        code: exception.code,
        message: '시스템 오류가 발생했습니다.',
        details: exception.message,
        originalException: exception,
        stackTrace: stackTrace,
      );
    }
    
    // 포맷 예외
    if (exception is FormatException) {
      return AppError(
        type: AppErrorType.data,
        code: 'format_error',
        message: '데이터 형식이 올바르지 않습니다.',
        details: exception.message,
        originalException: exception,
        stackTrace: stackTrace,
      );
    }
    
    // 일반 예외
    return AppError(
      type: AppErrorType.unknown,
      code: 'unknown_error',
      message: AppConstants.defaultErrorMessage,
      details: exception.toString(),
      originalException: exception,
      stackTrace: stackTrace,
    );
  }
  
  /// Dio 오류 처리
  static AppError _handleDioError(DioException error, StackTrace? stackTrace) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError(
          type: AppErrorType.network,
          code: 'timeout',
          message: '서버 연결 시간이 초과되었습니다. 네트워크 상태를 확인하세요.',
          details: error.message,
          originalException: error,
          stackTrace: stackTrace,
        );
        
      case DioExceptionType.badResponse:
        // HTTP 상태 코드에 따른 처리
        final statusCode = error.response?.statusCode;
        
        switch (statusCode) {
          case 400:
            return AppError(
              type: AppErrorType.invalidInput,
              code: 'bad_request',
              message: '잘못된 요청입니다.',
              details: error.response?.data.toString(),
              originalException: error,
              stackTrace: stackTrace,
            );
            
          case 401:
          case 403:
            return AppError(
              type: AppErrorType.authentication,
              code: 'unauthorized',
              message: AppConstants.authErrorMessage,
              details: error.response?.data.toString(),
              originalException: error,
              stackTrace: stackTrace,
            );
            
          case 404:
            return AppError(
              type: AppErrorType.data,
              code: 'not_found',
              message: AppConstants.dataNotFoundMessage,
              details: error.response?.data.toString(),
              originalException: error,
              stackTrace: stackTrace,
            );
            
          case 409:
            return AppError(
              type: AppErrorType.data,
              code: 'conflict',
              message: '데이터 충돌이 발생했습니다.',
              details: error.response?.data.toString(),
              originalException: error,
              stackTrace: stackTrace,
            );
            
          case 500:
          case 502:
          case 503:
            return AppError(
              type: AppErrorType.server,
              code: 'server_error',
              message: '서버 오류가 발생했습니다. 나중에 다시 시도해주세요.',
              details: error.response?.data.toString(),
              originalException: error,
              stackTrace: stackTrace,
            );
            
          default:
            return AppError(
              type: AppErrorType.unknown,
              code: 'http_error_$statusCode',
              message: AppConstants.defaultErrorMessage,
              details: error.response?.data.toString(),
              originalException: error,
              stackTrace: stackTrace,
            );
        }
        
      case DioExceptionType.cancel:
        return AppError(
          type: AppErrorType.system,
          code: 'request_cancelled',
          message: '요청이 취소되었습니다.',
          details: error.message,
          originalException: error,
          stackTrace: stackTrace,
        );
        
      default:
        return AppError(
          type: AppErrorType.network,
          code: 'network_error',
          message: AppConstants.networkErrorMessage,
          details: error.message,
          originalException: error,
          stackTrace: stackTrace,
        );
    }
  }
  
  /// Firebase 인증 오류 처리
  static AppError _handleFirebaseAuthError(FirebaseAuthException error, StackTrace? stackTrace) {
    String message;
    
    switch (error.code) {
      case 'user-not-found':
        message = '해당 이메일로 등록된 사용자가 없습니다.';
        break;
        
      case 'wrong-password':
        message = '비밀번호가 올바르지 않습니다.';
        break;
        
      case 'invalid-email':
        message = '유효하지 않은 이메일 형식입니다.';
        break;
        
      case 'user-disabled':
        message = '해당 계정이 비활성화되었습니다.';
        break;
        
      case 'email-already-in-use':
        message = '이미 사용 중인 이메일입니다.';
        break;
        
      case 'operation-not-allowed':
        message = '해당 인증 방법이 사용 불가능합니다.';
        break;
        
      case 'weak-password':
        message = '비밀번호가 너무 약합니다.';
        break;
        
      case 'account-exists-with-different-credential':
        message = '다른 인증 방법으로 가입된 계정입니다.';
        break;
        
      case 'invalid-credential':
        message = '인증 정보가 유효하지 않습니다.';
        break;
        
      case 'expired-action-code':
        message = '인증 코드가 만료되었습니다.';
        break;
        
      case 'invalid-verification-code':
        message = '유효하지 않은 인증 코드입니다.';
        break;
        
      case 'invalid-verification-id':
        message = '유효하지 않은 인증 ID입니다.';
        break;
        
      case 'requires-recent-login':
        message = '민감한 작업을 위해 재로그인이 필요합니다.';
        break;
        
      default:
        message = AppConstants.authErrorMessage;
    }
    
    return AppError(
      type: AppErrorType.authentication,
      code: error.code,
      message: message,
      details: error.message,
      originalException: error,
      stackTrace: stackTrace,
    );
  }
  
  /// 오류 메시지에서 민감한 정보 제거
  static String sanitizeErrorMessage(String message) {
    // API 키, 토큰 등 민감한 정보 제거
    final sensitivePatterns = [
      RegExp(r'key=([A-Za-z0-9\-_]+)'),
      RegExp(r'token=([A-Za-z0-9\-_\.]+)'),
      RegExp(r'password=([^\&\s]+)'),
      RegExp(r'secret=([^\&\s]+)'),
    ];
    
    String sanitized = message;
    for (final pattern in sensitivePatterns) {
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        return '${match.group(0)?.split('=')[0]}=*****';
      });
    }
    
    return sanitized;
  }
  
  /// 사용자에게 친숙한 오류 메시지 반환
  static String getUserFriendlyMessage(AppError error) {
    // 개발 모드가 아닌 경우 일반적인 메시지 반환
    const isProd = bool.fromEnvironment('dart.vm.product');
    
    if (isProd) {
      switch (error.type) {
        case AppErrorType.network:
          return '인터넷 연결이 원활하지 않습니다. 연결 상태를 확인하고 다시 시도해주세요.';
          
        case AppErrorType.server:
          return '서비스에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
          
        case AppErrorType.authentication:
          return '로그인 정보가 올바르지 않습니다. 다시 로그인해주세요.';
          
        case AppErrorType.permission:
          return '앱 기능 사용을 위해 필요한 권한이 없습니다.';
          
        case AppErrorType.data:
          return '데이터를 불러오는 중 문제가 발생했습니다.';
          
        case AppErrorType.invalidInput:
          return '입력한 정보가 올바르지 않습니다. 다시 확인해주세요.';
          
        case AppErrorType.system:
        case AppErrorType.unknown:
        default:
          return AppConstants.defaultErrorMessage;
      }
    } else {
      // 개발 모드에서는 상세 정보 반환
      if (error.details != null) {
        return '${error.message}\n\n${error.details}';
      }
      return error.message;
    }
  }
  
  /// FutureOr를 안전하게 실행하고 오류를 AppError로 처리
  static Future<T> safeFuture<T>(Future<T> Function() function) async {
    try {
      return await function();
    } catch (e, stackTrace) {
      throw handleException(e, stackTrace);
    }
  }
  
  /// 함수를 안전하게 실행하고 오류를 AppError로 처리
  static T safeCall<T>(T Function() function) {
    try {
      return function();
    } catch (e, stackTrace) {
      throw handleException(e, stackTrace);
    }
  }
  
  /// 안전하게 API 호출을 수행하고 결과를 반환하거나 오류를 처리
  static Future<T> safeApiCall<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } on DioException catch (e, stackTrace) {
      throw _handleDioError(e, stackTrace);
    } catch (e, stackTrace) {
      throw handleException(e, stackTrace);
    }
  }
}
