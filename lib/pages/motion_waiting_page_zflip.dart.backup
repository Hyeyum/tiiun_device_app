// lib/pages/motion_waiting_page_zflip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // StreamSubscription을 위해 추가
import '../design_system/colors.dart';
import '../design_system/typography.dart';
import '../services/voice_service.dart';
import '../services/foldable_device_service.dart';
import '../services/auth_service.dart';
import '../widgets/foldable_adaptive_widget.dart';
import 'advanced_voice_chat_page.dart';

class MotionWaitingPageZFlip extends ConsumerStatefulWidget {
  const MotionWaitingPageZFlip({super.key});

  @override
  ConsumerState<MotionWaitingPageZFlip> createState() => _MotionWaitingPageZFlipState();
}

class _MotionWaitingPageZFlipState extends ConsumerState<MotionWaitingPageZFlip>
    with TickerProviderStateMixin {

  // Firebase 및 센서 상태
  bool _isConnected = false;
  String _connectionStatus = 'Firebase 연결 시도 중...';
  int? _currentMotionValue;
  bool _hasGreeted = false;
  bool _isLoading = true;

  // 애니메이션 컨트롤러
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Firebase 스트림 구독 관리
  StreamSubscription<DatabaseEvent>? _firebaseSubscription;

  @override
  void initState() {
    super.initState();
    print('🚀 MotionWaitingPageZFlip 초기화 시작');

    // 애니메이션 초기화
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // 폴더블 디바이스 서비스 초기화
    _initializeFoldableService();

    // Firebase 모니터링 시작
    _startMotionMonitoring();

    // 페이드 인 애니메이션 시작
    _fadeController.forward();
  }

  Future<void> _initializeFoldableService() async {
    try {
      final foldableService = ref.read(foldableDeviceServiceProvider);
      await foldableService.initialize();
      print('✅ 폴더블 디바이스 서비스 초기화 완료');
    } catch (e) {
      print('❌ 폴더블 디바이스 서비스 초기화 실패: $e');
    }
  }

  void _startMotionMonitoring() {
    print('🔄 Firebase 연결 시도 중...');

    try {
      final database = FirebaseDatabase.instance;
      final motionRef = database.ref('test'); // Firebase 구조에 맞게 test 경로로 변경

      if (mounted) {
        setState(() {
          _isConnected = true;
          _isLoading = false;
          _connectionStatus = 'Firebase 연결 성공! motion 값 감지 대기 중...';
        });
      }

      print('✅ Firebase Realtime Database 연결 성공');

      // StreamSubscription 저장
      _firebaseSubscription = motionRef.onValue.listen((event) {
        print('💾 Firebase 데이터 수신: ${event.snapshot.value}');

        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;

          // test 경로의 직접 데이터 처리 (단일 센서 데이터)
          try {
            final motionValue = data['motion'] as int? ?? 0;
            final humidityValue = data['humidity'] as int? ?? 0;
            final timestampStr = data['timestamp'] as String? ?? '';

            // mounted 체크 후 setState 호출
            if (mounted) {
              setState(() {
                _currentMotionValue = motionValue;
                _connectionStatus = 'motion: $motionValue, humidity: $humidityValue (${timestampStr.isNotEmpty ? timestampStr : '시간 불명'})';
              });
            }

            print('🎆 센서 데이터 업데이트 - Motion: $motionValue, Humidity: $humidityValue, Timestamp: $timestampStr');

            // motion 값이 1이면 대화 시작
            if (motionValue == 1 && !_hasGreeted && mounted) {
              print('🎉 Motion = 1 감지! 대화 시작');
              _startConversation();
            }

          } catch (e) {
            print('🚨 데이터 파싱 오류: $e');
            if (mounted) {
              setState(() {
                _connectionStatus = '데이터 파싱 오류: $e';
              });
            }
          }
        } else {
          print('📁 Firebase 데이터가 null입니다. 대기 상태로 전환...');
          if (mounted) {
            setState(() {
              _connectionStatus = 'Firebase 연결됨. 데이터 대기 중...';
            });
          }
        }
      }, onError: (error) {
        print('🚨 Firebase 연결 오류: $error');
        if (mounted) {
          setState(() {
            _isConnected = false;
            _isLoading = false;
            _connectionStatus = 'Firebase 연결 오류: $error';
          });
        }
      });

    } catch (e) {
      print('🚨 모니터링 시작 실패: $e');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
          _connectionStatus = '모니터링 시작 실패: $e';
        });
      }
    }
  }

  void _startConversation() async {
    if (_hasGreeted) {
      print('⚠️ 이미 대화가 시작되었습니다.');
      return;
    }

    print('🚀 대화 시작 프로세스 시작...');

    if (mounted) {
      setState(() {
        _hasGreeted = true;
        _connectionStatus = '사용자 감지! 대화를 시작합니다...';
      });
    }

    try {
      print('🎤 음성 서비스로 인사말 재생 시도...');

      // 음성 서비스로 인사말 재생
      final voiceService = ref.read(voiceServiceProvider);
      await voiceService.speak('안녕하세요! 움직임이 감지되어 대화를 시작합니다. 무엇을 도와드릴까요?');

      print('✅ 인사말 재생 완료. 대화 페이지로 이동...');

      // 대화 페이지로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdvancedVoiceChatPage(autoStart: true), // autoStart=true로 설정
          ),
        );
        print('🎉 대화 페이지로 이동 완료!');
      }
    } catch (e) {
      print('🚨 대화 시작 오류: $e');
      if (mounted) {
        setState(() {
          _connectionStatus = '대화 시작 오류: $e';
          _hasGreeted = false;
        });
      }
    }
  }

  // 로그아웃 처리
  Future<void> _handleLogout() async {
    try {
      // 확인 다이얼로그 표시
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('로그아웃'),
            content: const Text('정말 로그아웃하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('로그아웃'),
              ),
            ],
          );
        },
      );

      if (shouldLogout == true) {
        // 로딩 다이얼로그 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        // 로그아웃 처리
        final authService = ref.read(authServiceProvider);
        await authService.logout();

        // 로딩 다이얼로그 닫기
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();

          // 로그인 페이지로 이동
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );
        }
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 에러 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('🚨 로그아웃 오류: $e');
    }
  }

  @override
  void dispose() {
    print('🗑️ MotionWaitingPageZFlip dispose 시작');

    // Firebase 스트림 구독 취소
    _firebaseSubscription?.cancel();
    _firebaseSubscription = null;

    // 애니메이션 컨트롤러 정리
    _pulseController.dispose();
    _fadeController.dispose();

    print('✅ MotionWaitingPageZFlip dispose 완료');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 UI 빌드 시작: _isConnected=$_isConnected, _isLoading=$_isLoading, _hasGreeted=$_hasGreeted');
    print('📊 상태: $_connectionStatus');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('틔운이 대기중'),
        backgroundColor: AppColors.main800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'logout') {
                _handleLogout();
              } else if (value == 'settings') {
                // 설정 페이지로 이동
                Navigator.pushNamed(context, '/voice_settings');
              } else if (value == 'conversations') {
                // 대화 목록 페이지로 이동
                Navigator.pushNamed(context, '/conversation_list');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'conversations',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline),
                    SizedBox(width: 8),
                    Text('대화 목록'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('설정'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('로그아웃', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ZFlipLayout(
          // 상단 영역: 센서 상태 및 정보 표시
          topContent: _buildTopContent(),
          // 하단 영역: 컨트롤 버튼들
          bottomContent: _buildBottomContent(),
          // 일반 디바이스용 전체 화면 레이아웃
          flatContent: _buildFlatContent(),
          hingeColor: AppColors.main100,
        ),
      ),
    );
  }

  /// 상단 영역 빌드 (센서 정보)
  Widget _buildTopContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.main100,
            AppColors.main200,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 폴더블 상태 인디케이터
              const Row(
                children: [
                  FoldableStatusIndicator(showDetails: true),
                  Spacer(),
                ],
              ),

              const SizedBox(height: 20),

              // 센서 아이콘과 제목
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.main500,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.main300.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sensors,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              FoldableText(
                '틔운이 센서 모니터링',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.main800,
                ),
                foldedStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.main800,
                ),
                textAlign: TextAlign.center,
              ),

              const FoldableSpacing(normalSpacing: 16, foldedSpacing: 8),

              // Firebase 연결 상태
              _buildConnectionStatus(),

              const FoldableSpacing(normalSpacing: 16, foldedSpacing: 8),

              // Motion 값 표시
              if (_currentMotionValue != null) _buildMotionValueDisplay(),
            ],
          ),
        ),
      ),
    );
  }

  /// 하단 영역 빌드 (컨트롤)
  Widget _buildBottomContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.main200,
            AppColors.main300,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 수동 대화 시작 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  print('🔴 Z플립 수동 테스트 버튼 클릭됨');
                  _startConversation();
                },
                icon: const Icon(Icons.mic),
                label: const FoldableText(
                  '수동으로 대화 시작',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  foldedStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),

            const FoldableSpacing(normalSpacing: 16, foldedSpacing: 12),

            // 설정 버튼들
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // 설정 페이지로 이동
                      print('⚙️ 설정 버튼 클릭');
                    },
                    icon: const Icon(Icons.settings),
                    label: const FoldableText(
                      '설정',
                      style: TextStyle(fontSize: 14),
                      foldedStyle: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.main700,
                      side: BorderSide(color: AppColors.main400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // 기록 페이지로 이동
                      print('📊 기록 버튼 클릭');
                    },
                    icon: const Icon(Icons.history),
                    label: const FoldableText(
                      '기록',
                      style: TextStyle(fontSize: 14),
                      foldedStyle: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.main700,
                      side: BorderSide(color: AppColors.main400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const FoldableSpacing(normalSpacing: 16, foldedSpacing: 8),

            // 하단 안내 텍스트
            FoldableText(
              'Z플립 텐트 모드로 더 편리하게 사용하세요',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.main600,
                fontStyle: FontStyle.italic,
              ),
              foldedStyle: TextStyle(
                fontSize: 10,
                color: AppColors.main600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 일반 디바이스용 전체 화면 레이아웃
  Widget _buildFlatContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.main100,
            AppColors.main300,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 상단 상태 정보
              _buildConnectionStatus(),

              const SizedBox(height: 40),

              // 메인 아이콘
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.main500,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.main300.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sensors,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // 제목
              Text(
                '틔운이 대기 중',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.main800,
                ),
              ),

              const SizedBox(height: 16),

              // 설명
              Text(
                'Firebase에서 motion 값이 1이 되면\n자동으로 대화가 시작됩니다',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.main600,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              // 수동 테스트 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    print('🔴 수동 테스트 버튼 클릭됨');
                    _startConversation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    '수동으로 대화 시작',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Motion 값 표시
              if (_currentMotionValue != null) _buildMotionValueDisplay(),

              const Spacer(),

              // 하단 정보
              Text(
                '센서가 움직임을 감지하면 자동으로 대화가 시작됩니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Firebase 연결 상태 위젯
  Widget _buildConnectionStatus() {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isLoading
              ? Colors.orange.shade50
              : _isConnected ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isLoading
                ? Colors.orange
                : _isConnected ? Colors.green : Colors.red,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isLoading
                  ? Icons.hourglass_empty
                  : _isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isLoading
                  ? Colors.orange
                  : _isConnected ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FoldableText(
                _connectionStatus,
                style: TextStyle(
                  color: _isLoading
                      ? Colors.orange.shade700
                      : _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                foldedStyle: TextStyle(
                  color: _isLoading
                      ? Colors.orange.shade700
                      : _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Motion 값 표시 위젯
  Widget _buildMotionValueDisplay() {
    return Card(
      elevation: 3,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: _currentMotionValue == 1
              ? LinearGradient(
            colors: [Colors.green.shade50, Colors.green.shade100],
          )
              : null,
        ),
        child: Column(
          children: [
            FoldableText(
              '현재 Motion 값',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              foldedStyle: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_currentMotionValue',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _currentMotionValue == 1 ? Colors.green : AppColors.main700,
              ),
            ),
            if (_currentMotionValue == 1) ...[
              const SizedBox(height: 8),
              FoldableText(
                '🎉 움직임 감지됨!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
                foldedStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
