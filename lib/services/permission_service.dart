// lib/services/permission_service.dart
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// 앱 권한 관리 서비스
///
/// 앱 실행에 필요한 다양한 시스템 권한을 요청하고 관리합니다.
class PermissionService {
  // 싱글톤 인스턴스
  static PermissionService? _instance;
  static PermissionService get instance => _instance ??= PermissionService._();

  // 비공개 생성자
  PermissionService._();

  /// 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    AppLogger.debug('PermissionService: Requesting microphone permission');

    final status = await Permission.microphone.request();

    AppLogger.info('PermissionService: Microphone permission status - $status');
    return status.isGranted;
  }

  /// 저장소 권한 요청
  Future<bool> requestStoragePermission() async {
    // iOS에서는 저장소 권한이 필요 없음
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }

    AppLogger.debug('PermissionService: Requesting storage permission');

    final status = await Permission.storage.request();

    AppLogger.info('PermissionService: Storage permission status - $status');
    return status.isGranted;
  }

  /// 카메라 권한 요청
  Future<bool> requestCameraPermission() async {
    AppLogger.debug('PermissionService: Requesting camera permission');

    final status = await Permission.camera.request();

    AppLogger.info('PermissionService: Camera permission status - $status');
    return status.isGranted;
  }

  /// 알림 권한 요청
  Future<bool> requestNotificationPermission() async {
    AppLogger.debug('PermissionService: Requesting notification permission');

    final status = await Permission.notification.request();

    AppLogger.info('PermissionService: Notification permission status - $status');
    return status.isGranted;
  }

  /// 모든 필수 권한 요청
  Future<Map<Permission, bool>> requestAllRequiredPermissions() async {
    AppLogger.info('PermissionService: Requesting all required permissions');

    final microphonePermission = await requestMicrophonePermission();
    final storagePermission = await requestStoragePermission();
    final notificationPermission = await requestNotificationPermission();

    return {
      Permission.microphone: microphonePermission,
      Permission.storage: storagePermission,
      Permission.notification: notificationPermission,
    };
  }

  /// 마이크 권한 상태 확인
  Future<bool> isMicrophonePermissionGranted() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// 저장소 권한 상태 확인
  Future<bool> isStoragePermissionGranted() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }

    final status = await Permission.storage.status;
    return status.isGranted;
  }

  /// 카메라 권한 상태 확인
  Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// 알림 권한 상태 확인
  Future<bool> isNotificationPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// 권한이 영구적으로 거부되었는지 확인
  Future<bool> isPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  /// 앱 설정 화면으로 이동
  Future<void> openAppSettings() async {
    AppLogger.debug('PermissionService: Opening app settings');
    await openAppSettings();
  }

  /// 권한 상태 변경 리스너 등록
  Future<void> listenToPermissionChanges(Permission permission, Function(PermissionStatus) callback) async {
    // Initial status check
    final initialStatus = await permission.status;
    callback(initialStatus);

    // Periodic status check
    Stream.periodic(const Duration(seconds: 1)).listen((_) async {
      final status = await permission.status;
      AppLogger.debug('PermissionService: ${permission.toString()} status changed to $status');
      callback(status);
    });
  }

  /// 권한 요청 이유 메시지 가져오기
  String getRationaleMessage(Permission permission) {
    switch (permission) {
      case Permission.microphone:
        return AppConstants.microphonePermissionRationale;
      case Permission.storage:
        return AppConstants.storagePermissionRationale;
      case Permission.camera:
        return AppConstants.cameraPermissionRationale;
      case Permission.notification:
        return AppConstants.notificationPermissionRationale;
      default:
        return '앱 기능을 사용하기 위해 권한이 필요합니다.';
    }
  }
}