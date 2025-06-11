// lib/pages/tiiun_waiting_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svg/svg.dart';
import 'package:tiiun/design_system/typography.dart';
import 'dart:async';
import 'package:tiiun/design_system/colors.dart';
import 'package:tiiun/services/voice_service.dart';
import 'package:tiiun/services/foldable_device_service.dart';
import 'package:tiiun/services/auth_service.dart';
import 'package:tiiun/pages/main_function/advanced_voice_chat_page.dart';
import 'dart:ui';

class TiiunWaitingPage extends ConsumerStatefulWidget {
  const TiiunWaitingPage({super.key});

  @override
  ConsumerState<TiiunWaitingPage> createState() => _TiiunWaitingPageState();
}

class _TiiunWaitingPageState extends ConsumerState<TiiunWaitingPage>
    with TickerProviderStateMixin {

  // Firebase 및 센서 상태
  bool _isConnected = false;
  String _connectionStatus = 'Firebase 연결 시도 중...';
  int? _currentMotionValue;
  bool _hasGreeted = false;
  bool _isLoading = true;

  // Firebase 스트림 구독 관리
  StreamSubscription<DatabaseEvent>? _firebaseSubscription;
  
  // 시간 업데이트용 타이머
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();
    print('🚀 TiiunWaitingPage 초기화 시작');

    // 폴더블 디바이스 서비스 초기화
    _initializeFoldableService();

    // Firebase 모니터링 시작
    _startMotionMonitoring();
    
    // 시간 업데이트 타이머 시작
    _startTimeTimer();
  }
  
  void _startTimeTimer() {
    _timeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // 시간 업데이트를 위한 setState
        });
      }
    });
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
      final motionRef = database.ref('test');

      if (mounted) {
        setState(() {
          _isConnected = true;
          _isLoading = false;
          _connectionStatus = 'Firebase 연결 성공! motion 값 감지 대기 중...';
        });
      }

      print('✅ Firebase Realtime Database 연결 성공');

      _firebaseSubscription = motionRef.onValue.listen((event) {
        print('💾 Firebase 데이터 수신: ${event.snapshot.value}');

        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;

          try {
            final motionValue = data['motion'] as int? ?? 0;
            final humidityValue = data['humidity'] as int? ?? 0;
            final timestampStr = data['timestamp'] as String? ?? '';

            if (mounted) {
              setState(() {
                _currentMotionValue = motionValue;
                _connectionStatus = 'motion: $motionValue, humidity: $humidityValue';
              });
            }

            print('🎆 센서 데이터 업데이트 - Motion: $motionValue, Humidity: $humidityValue');

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
            builder: (context) => const AdvancedVoiceChatPage(autoStart: true),
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        final authService = ref.read(authServiceProvider);
        await authService.logout();

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

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

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    print('🗑️ TiiunWaitingPage dispose 시작');
    _firebaseSubscription?.cancel();
    _firebaseSubscription = null;
    _timeTimer?.cancel();
    _timeTimer = null;
    print('✅ TiiunWaitingPage dispose 완료');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final hingeSpace = 20; // 힌지 공간 줄임 (40 → 20)
    final topHeight = (screenHeight / 2) - hingeSpace;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 상단 영역 (힌지 공간 위까지)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topHeight,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Color(0xFFF7F9EC),
              ),
              child: _buildTopContent(),
            ),
          ),
          
          // 힌지 공간 (하단 영역과 같은 색깔)
          Positioned(
            top: topHeight,
            left: 0,
            right: 0,
            height: hingeSpace * 2, // 40px 총 높이
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF0E6),
                    Color(0xFFFFE4E1),
                  ],
                ),
              ),
            ),
          ),
          
          // 하단 영역 (힌지 공간 아래)
          Positioned(
            top: topHeight + (hingeSpace * 2),
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomContent(),
          ),
        ],
      ),
    );
  }

  // 상단 영역 (토마토 테마 대기화면)
  Widget _buildTopContent() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      clipBehavior: Clip.hardEdge, // 강제로 클리핑
      decoration: BoxDecoration(
        color: Color(0xFFF7F9EC), // 배경색
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge, // Stack도 클리핑
        children: [
          // 배경 이미지
          Positioned.fill(
            child: Image.asset(
              'assets/images/display/tomato_background.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          // 시간 텍스트
          Positioned(
            left: 20,
            top: 40,
            child: Container(
              // width: 156,
              // height: 66,
              child: Text(
                _getCurrentTime(),
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF1533A),
                  height: 1.1,
                  fontFamily: AppTypography.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // 꽃 아이콘 박스
          Positioned(
            left: 20,
            bottom: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 98,
                  height: 92,
                  padding: EdgeInsets.symmetric(horizontal: 20,),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    border: Border.all(
                      color: AppColors.grey100,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF131927).withOpacity(0.08),
                        offset: Offset(0, 8),
                        blurRadius: 16,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Center(
                      child: Image.asset(
                        'assets/images/display/flower.png',
                        filterQuality: FilterQuality.high,
                      )
                  ),
                ),
              ),
            ),
          ),

          // 활동 박스
          Positioned(
            right: 20,
            bottom: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  width: 210,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    border: Border.all(
                        color: AppColors.grey100,
                        width: 1
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF131927).withOpacity(0.08),
                        offset: Offset(0, 8),
                        blurRadius: 16,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: MoodBox(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 하단 영역 (메뉴)
  Widget _buildBottomContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF0E6),
            Color(0xFFFFE4E1),
          ],
        ),
      ),
      child: SafeArea(
        child: _buildMenuArea(),
      ),
    );
  }

  Widget _buildMenuArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 연결 상태 표시
          _buildConnectionStatus(),
          
          const SizedBox(height: 16),
          
          // 대화 시작 버튼 (큰 버튼)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                print('🔴 수동 대화 시작 버튼 클릭됨');
                _startConversation();
              },
              icon: const Icon(Icons.mic, size: 20),
              label: const Text(
                '대화 시작',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1533A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 작은 메뉴 버튼들 (첫 번째 줄)
          Row(
            children: [
              // 대화 목록
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/conversation_list');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    '대화목록',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // 설정
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/voice_settings');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    '설정',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // 로그아웃
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _handleLogout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    '로그아웃',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // LangChain 테스트 버튼 (두 번째 줄)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/langchain_test');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade50,
                foregroundColor: Colors.purple.shade700,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 1,
              ),
              child: const Text(
                'LangChain 테스트',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isLoading
            ? Colors.orange.shade50
            : _isConnected ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
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
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _connectionStatus,
              style: TextStyle(
                color: _isLoading
                    ? Colors.orange.shade700
                    : _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (_currentMotionValue != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _currentMotionValue == 1 ? Colors.green : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Motion: $_currentMotionValue',
                style: TextStyle(
                  color: _currentMotionValue == 1 ? Colors.white : Colors.grey.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
    );
  }
}

// 활동 박스 위젯 - 원본 코드 그대로
class MoodBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MoodItem(svgPath: 'assets/icons/device/human.svg', label: '명상'),
              SizedBox(width: 12,),
              MoodItem(svgPath: 'assets/icons/device/walking.svg', label: '오후 산책'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MoodItem(svgPath: 'assets/icons/device/headset.svg', label: '음악 감상'),
              SizedBox(width: 12,),
              MoodItem(svgPath: 'assets/icons/device/sleeping.svg', label: '낮잠'),
            ],
          ),
        ],
      ),
    );
  }
}

// 아이템 (SVG 아이콘 + 텍스트)
class MoodItem extends StatelessWidget {
  final String svgPath;
  final String label;

  const MoodItem({required this.svgPath, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          svgPath,
          width: 24,
          height: 24,
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.b2.withColor(Color(0xFFF1533A))
        ),
      ],
    );
  }
}
