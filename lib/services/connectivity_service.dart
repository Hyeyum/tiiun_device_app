// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

/// 네트워크 연결 상태
enum NetworkStatus {
  /// 네트워크에 연결됨
  connected,

  /// 네트워크에 연결되지 않음
  disconnected
}

/// 네트워크 연결 관리 서비스
///
/// 앱의 네트워크 연결 상태를 실시간으로 모니터링하고 상태 변경을 알립니다.
class ConnectivityService {
  // 싱글톤 인스턴스
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();

  // 비공개 생성자
  ConnectivityService._();

  // 연결 상태 스트림 컨트롤러
  final _connectionStatusController = StreamController<NetworkStatus>.broadcast();

  // 연결 관리 객체
  final _connectivity = Connectivity();

  // 현재 연결 상태
  NetworkStatus _currentStatus = NetworkStatus.connected;
  NetworkStatus get currentStatus => _currentStatus;

  // 구독 취소 객체
  StreamSubscription? _connectionSubscription;

  // 연결 상태 스트림
  Stream<NetworkStatus> get connectionStatusStream => _connectionStatusController.stream;

  /// 서비스 초기화
  void initialize() {
    AppLogger.info('ConnectivityService: Initializing...');

    // 최초 상태 확인
    _checkConnectivity();

    // 상태 변경 구독
    // connectivity_plus 최신 버전은 List<ConnectivityResult>를 반환합니다.
    _connectionSubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      AppLogger.debug('ConnectivityService: Connectivity changed - $results');
      _updateConnectionStatus(results);
    });

    AppLogger.info('ConnectivityService: Initialized');
  }

  /// 연결 상태 확인
  Future<void> _checkConnectivity() async {
    try {
      // checkConnectivity도 List<ConnectivityResult>를 반환합니다.
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      AppLogger.error('ConnectivityService: Error checking connectivity - $e');
      _currentStatus = NetworkStatus.disconnected;
      _connectionStatusController.add(_currentStatus);
    }
  }

  /// 연결 상태 업데이트
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final previousStatus = _currentStatus;

    // 리스트에 ConnectivityResult.none이 포함되어 있지 않으면 연결된 것으로 간주
    bool isConnected = !results.contains(ConnectivityResult.none);

    if (isConnected) {
      _currentStatus = NetworkStatus.connected;
    } else {
      _currentStatus = NetworkStatus.disconnected;
    }

    // 상태가 변경된 경우에만 알림
    if (previousStatus != _currentStatus) {
      AppLogger.info('ConnectivityService: Network status changed to $_currentStatus');
      _connectionStatusController.add(_currentStatus);
    }
  }

  /// 현재 네트워크에 연결되어 있는지 확인
  bool isConnected() {
    return _currentStatus == NetworkStatus.connected;
  }

  /// 네트워크 연결 해제 시 처리할 콜백 등록
  StreamSubscription<NetworkStatus> onDisconnected(Function() callback) {
    return connectionStatusStream.listen((status) {
      if (status == NetworkStatus.disconnected) {
        callback();
      }
    });
  }

  /// 네트워크 연결 시 처리할 콜백 등록
  StreamSubscription<NetworkStatus> onConnected(Function() callback) {
    return connectionStatusStream.listen((status) {
      if (status == NetworkStatus.connected) {
        callback();
      }
    });
  }

  /// 현재 연결 타입 확인
  Future<List<ConnectivityResult>> getConnectionType() async {
    return await _connectivity.checkConnectivity();
  }

  /// 서비스 종료
  void dispose() {
    _connectionSubscription?.cancel();
    _connectionStatusController.close();
    AppLogger.info('ConnectivityService: Disposed');
  }
}