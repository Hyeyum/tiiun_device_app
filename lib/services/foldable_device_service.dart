// lib/services/foldable_device_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

// 폴더블 디바이스 서비스 Provider
final foldableDeviceServiceProvider = Provider<FoldableDeviceService>((ref) {
  return FoldableDeviceService();
});

// 폴드 상태 열거형
enum FoldState {
  flat,         // 완전히 펼쳐진 상태
  halfOpened,   // 반쯤 접힌 상태 (Z플립에서 주로 사용)
  unknown,      // 알 수 없는 상태
}

// 폴드 방향 열거형
enum FoldOrientation {
  horizontal,   // 가로 방향 접힘 (Z플립)
  vertical,     // 세로 방향 접힘 (Z폴드)
  unknown,      // 알 수 없는 방향
}

// 폴딩 기능 정보 클래스
class FoldingFeatureInfo {
  final FoldState state;
  final FoldOrientation orientation;
  final bool isSeparating;
  final String occlusionType;
  final Rect bounds;

  FoldingFeatureInfo({
    required this.state,
    required this.orientation,
    required this.isSeparating,
    required this.occlusionType,
    required this.bounds,
  });

  factory FoldingFeatureInfo.fromMap(Map<String, dynamic> map) {
    try {
      final boundsMap = map['bounds'] as Map<String, dynamic>? ?? {};

      return FoldingFeatureInfo(
        state: _parseState(map['state'] as String?),
        orientation: _parseOrientation(map['orientation'] as String?),
        isSeparating: map['isSeparating'] as bool? ?? false,
        occlusionType: map['occlusionType'] as String? ?? 'unknown',
        bounds: Rect.fromLTRB(
          (boundsMap['left'] as num?)?.toDouble() ?? 0,
          (boundsMap['top'] as num?)?.toDouble() ?? 0,
          (boundsMap['right'] as num?)?.toDouble() ?? 0,
          (boundsMap['bottom'] as num?)?.toDouble() ?? 0,
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.error('FoldingFeatureInfo.fromMap: Error parsing folding feature: $e', e, stackTrace);
      // 대체 값 반환
      return FoldingFeatureInfo(
        state: FoldState.unknown,
        orientation: FoldOrientation.unknown,
        isSeparating: false,
        occlusionType: 'unknown',
        bounds: Rect.zero,
      );
    }
  }

  static FoldState _parseState(String? state) {
    switch (state) {
      case 'flat':
        return FoldState.flat;
      case 'half_opened':
        return FoldState.halfOpened;
      default:
        return FoldState.unknown;
    }
  }

  static FoldOrientation _parseOrientation(String? orientation) {
    switch (orientation) {
      case 'horizontal':
        return FoldOrientation.horizontal;
      case 'vertical':
        return FoldOrientation.vertical;
      default:
        return FoldOrientation.unknown;
    }
  }

  // Z플립에서 반쯤 접힌 상태인지 확인
  bool get isZFlipHalfOpened =>
      state == FoldState.halfOpened && orientation == FoldOrientation.horizontal;

  // Z폴드에서 반쯤 접힌 상태인지 확인
  bool get isZFoldHalfOpened =>
      state == FoldState.halfOpened && orientation == FoldOrientation.vertical;

  @override
  String toString() {
    return 'FoldingFeatureInfo(state: $state, orientation: $orientation, '
        'isSeparating: $isSeparating, bounds: $bounds)';
  }
}

// 디바이스 정보 클래스
class DeviceInfo {
  final int screenWidth;
  final int screenHeight;
  final double density;
  final bool isFoldable;

  DeviceInfo({
    required this.screenWidth,
    required this.screenHeight,
    required this.density,
    required this.isFoldable,
  });

  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    try {
      return DeviceInfo(
        screenWidth: map['screenWidth'] as int? ?? 0,
        screenHeight: map['screenHeight'] as int? ?? 0,
        density: (map['density'] as num?)?.toDouble() ?? 1.0,
        isFoldable: map['isFoldable'] as bool? ?? false,
      );
    } catch (e, stackTrace) {
      AppLogger.error('DeviceInfo.fromMap: Error parsing device info: $e', e, stackTrace);
      // 대체 값 반환
      return DeviceInfo(
        screenWidth: 0,
        screenHeight: 0,
        density: 1.0,
        isFoldable: false,
      );
    }
  }

  @override
  String toString() {
    return 'DeviceInfo(width: $screenWidth, height: $screenHeight, '
        'density: $density, isFoldable: $isFoldable)';
  }
}

// 윈도우 레이아웃 정보 클래스
class WindowLayoutInfo {
  final List<FoldingFeatureInfo> foldingFeatures;
  final DeviceInfo deviceInfo;
  final int timestamp;

  WindowLayoutInfo({
    required this.foldingFeatures,
    required this.deviceInfo,
    required this.timestamp,
  });

  factory WindowLayoutInfo.fromMap(Map<String, dynamic> map) {
    try {
      final featuresData = map['displayFeatures'] as List<dynamic>? ?? [];
      final deviceData = map['deviceInfo'] as Map<String, dynamic>? ?? {};

      AppLogger.debug('WindowLayoutInfo.fromMap: Processing ${featuresData.length} features');

      final features = featuresData
          .where((feature) {
        if (feature is Map<String, dynamic>) {
          return feature['type'] == 'fold';
        }
        return false;
      })
          .map((feature) {
        try {
          return FoldingFeatureInfo.fromMap(feature as Map<String, dynamic>);
        } catch (e) {
          AppLogger.warning('WindowLayoutInfo.fromMap: Error parsing feature: $e');
          return null;
        }
      })
          .where((feature) => feature != null)
          .cast<FoldingFeatureInfo>()
          .toList();

      return WindowLayoutInfo(
        foldingFeatures: features,
        deviceInfo: DeviceInfo.fromMap(deviceData),
        timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e, stackTrace) {
      AppLogger.error('WindowLayoutInfo.fromMap: Error parsing window info: $e', e, stackTrace);
      // 대체 값 반환
      return WindowLayoutInfo(
        foldingFeatures: [],
        deviceInfo: DeviceInfo(
          screenWidth: 0,
          screenHeight: 0,
          density: 1.0,
          isFoldable: false,
        ),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  // 현재 폴드 상태 확인
  FoldState get currentFoldState {
    if (foldingFeatures.isEmpty) return FoldState.flat;
    return foldingFeatures.first.state;
  }

  // Z플립 특화 상태 확인
  bool get isZFlipHalfOpened =>
      foldingFeatures.any((feature) => feature.isZFlipHalfOpened);

  // 듀얼 스크린 모드인지 확인
  bool get isDualScreenMode =>
      foldingFeatures.any((feature) => feature.isSeparating);

  @override
  String toString() {
    return 'WindowLayoutInfo(features: ${foldingFeatures.length}, '
        'state: $currentFoldState, device: $deviceInfo)';
  }
}

/// 폴더블 디바이스 상태를 관리하는 서비스
class FoldableDeviceService {
  static const MethodChannel _methodChannel =
  MethodChannel('com.tiiun.foldable/window_manager');
  static const EventChannel _eventChannel =
  EventChannel('com.tiiun.foldable/window_events');

  // 현재 윈도우 정보
  WindowLayoutInfo? _currentWindowInfo;

  // 윈도우 정보 스트림
  StreamSubscription? _windowInfoSubscription;
  final StreamController<WindowLayoutInfo> _windowInfoController =
  StreamController<WindowLayoutInfo>.broadcast();

  /// 윈도우 정보 스트림
  Stream<WindowLayoutInfo> get windowInfoStream => _windowInfoController.stream;

  /// 현재 윈도우 정보
  WindowLayoutInfo? get currentWindowInfo => _currentWindowInfo;

  /// 서비스 초기화
  Future<void> initialize() async {
    try {
      AppLogger.info('FoldableDeviceService: Initializing...');

      // 현재 윈도우 정보 가져오기
      await getCurrentWindowInfo();

      // 실시간 윈도우 정보 스트림 시작
      _startWindowInfoStream();

      AppLogger.info('FoldableDeviceService: Initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error('FoldableDeviceService: Initialization failed: $e', e, stackTrace);
    }
  }

  /// 현재 윈도우 정보 가져오기 (일회성)
  Future<WindowLayoutInfo?> getCurrentWindowInfo() async {
    try {
      final result = await _methodChannel.invokeMethod('getCurrentWindowInfo');
      if (result != null) {
        // 안전한 타입 변환
        final Map<String, dynamic> convertedData = _convertToStringDynamicMap(result);
        _currentWindowInfo = WindowLayoutInfo.fromMap(convertedData);
        AppLogger.debug('FoldableDeviceService: Current window info: $_currentWindowInfo');
        return _currentWindowInfo;
      }
    } catch (e, stackTrace) {
      AppLogger.error('FoldableDeviceService: Error getting current window info: $e', e, stackTrace);
    }
    return null;
  }

  /// 디바이스가 폴더블인지 확인
  Future<bool> isDeviceFoldable() async {
    try {
      final result = await _methodChannel.invokeMethod('isDeviceFoldable');
      return result as bool? ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('FoldableDeviceService: Error checking if device is foldable: $e', e, stackTrace);
      return false;
    }
  }

  /// 실시간 윈도우 정보 스트림 시작
  void _startWindowInfoStream() {
    _windowInfoSubscription?.cancel();

    _windowInfoSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(
          (data) {
        try {
          if (data != null) {
            // 안전한 타입 변환을 위해 재귀적으로 Map을 변환
            final Map<String, dynamic> convertedData = _convertToStringDynamicMap(data);
            final windowInfo = WindowLayoutInfo.fromMap(convertedData);
            _currentWindowInfo = windowInfo;
            _windowInfoController.add(windowInfo);

            AppLogger.debug('FoldableDeviceService: Window info updated: $windowInfo');

            // 폴드 상태 변화 로깅
            _logFoldStateChange(windowInfo);
          }
        } catch (e, stackTrace) {
          AppLogger.error('FoldableDeviceService: Error processing window info: $e', e, stackTrace);
        }
      },
      onError: (error) {
        AppLogger.error('FoldableDeviceService: Window info stream error: $error');
      },
    );
  }

  /// Object를 Map<String, dynamic>으로 안전하게 변환
  Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
    if (data == null) {
      AppLogger.debug('FoldableDeviceService: Received null data');
      return {};
    }

    AppLogger.debug('FoldableDeviceService: Converting data type: ${data.runtimeType}');

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      final Map<String, dynamic> result = {};
      data.forEach((key, value) {
        final String stringKey = key?.toString() ?? '';
        if (stringKey.isEmpty) {
          AppLogger.warning('FoldableDeviceService: Empty key found, skipping');
          return;
        }

        if (value is Map) {
          result[stringKey] = _convertToStringDynamicMap(value);
        } else if (value is List) {
          result[stringKey] = _convertToStringDynamicList(value);
        } else {
          result[stringKey] = value;
        }
      });
      AppLogger.debug('FoldableDeviceService: Converted map keys: ${result.keys.toList()}');
      return result;
    }

    AppLogger.error('FoldableDeviceService: Cannot convert data of type ${data.runtimeType} to Map<String, dynamic>');
    throw ArgumentError('Cannot convert $data to Map<String, dynamic>');
  }

  /// List를 동적으로 변환
  List<dynamic> _convertToStringDynamicList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _convertToStringDynamicMap(item);
      } else if (item is List) {
        return _convertToStringDynamicList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// 폴드 상태 변화 로깅
  void _logFoldStateChange(WindowLayoutInfo windowInfo) {
    if (windowInfo.deviceInfo.isFoldable) {
      switch (windowInfo.currentFoldState) {
        case FoldState.flat:
          AppLogger.info('📱 Device state: FLAT (fully opened)');
          break;
        case FoldState.halfOpened:
          if (windowInfo.isZFlipHalfOpened) {
            AppLogger.info('📱 Device state: Z FLIP HALF OPENED (tent mode)');
          } else {
            AppLogger.info('📱 Device state: HALF OPENED');
          }
          break;
        case FoldState.unknown:
          AppLogger.info('📱 Device state: UNKNOWN');
          break;
      }
    }
  }

  /// 현재 폴드 상태 확인
  FoldState get currentFoldState =>
      _currentWindowInfo?.currentFoldState ?? FoldState.flat;

  /// Z플립 반접힘 모드인지 확인
  bool get isZFlipHalfOpened =>
      _currentWindowInfo?.isZFlipHalfOpened ?? false;

  /// 듀얼 스크린 모드인지 확인
  bool get isDualScreenMode =>
      _currentWindowInfo?.isDualScreenMode ?? false;

  /// 디바이스가 폴더블인지 확인 (캐시된 값)
  bool get isFoldableDevice =>
      _currentWindowInfo?.deviceInfo.isFoldable ?? false;

  /// 리소스 정리
  void dispose() {
    AppLogger.info('FoldableDeviceService: Disposing...');
    _windowInfoSubscription?.cancel();
    _windowInfoController.close();
  }
}

// 편의 확장 메서드
extension WindowLayoutInfoExtensions on WindowLayoutInfo {
  /// 상단 영역 높이 계산 (Z플립 반접힘 모드에서)
  double get topAreaHeight {
    if (!isZFlipHalfOpened) return deviceInfo.screenHeight.toDouble();

    final foldBounds = foldingFeatures.first.bounds;
    return foldBounds.top;
  }

  /// 하단 영역 높이 계산 (Z플립 반접힘 모드에서)
  double get bottomAreaHeight {
    if (!isZFlipHalfOpened) return 0;

    final foldBounds = foldingFeatures.first.bounds;
    return deviceInfo.screenHeight.toDouble() - foldBounds.bottom;
  }

  /// 힌지 영역 높이
  double get hingeHeight {
    if (foldingFeatures.isEmpty) return 0;
    return foldingFeatures.first.bounds.height;
  }
}