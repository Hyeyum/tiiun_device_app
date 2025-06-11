// lib/pages/foldable_demo_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiiun/services/foldable_device_service.dart';
import 'package:tiiun/widgets/foldable_adaptive_widget.dart';
import 'package:tiiun/design_system/colors.dart';
import 'package:tiiun/design_system/typography.dart';

class FoldableDemoPage extends ConsumerStatefulWidget {
  const FoldableDemoPage({super.key});

  @override
  ConsumerState<FoldableDemoPage> createState() => _FoldableDemoPageState();
}

class _FoldableDemoPageState extends ConsumerState<FoldableDemoPage>
    with TickerProviderStateMixin {

  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159, // 2π
    ).animate(_rotationController);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('폴더블 디바이스 데모'),
        backgroundColor: AppColors.main600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 폴더블 서비스 재초기화
              final foldableService = ref.read(foldableDeviceServiceProvider);
              foldableService.initialize();
            },
          ),
        ],
      ),
      body: ZFlipLayout(
        // 상단 영역: 디바이스 정보 및 상태
        topContent: _buildTopArea(),
        // 하단 영역: 컨트롤 및 테스트
        bottomContent: _buildBottomArea(),
        // 일반 디바이스용
        flatContent: _buildFullScreenContent(),
      ),
    );
  }

  /// 상단 영역 (Z플립 텐트 모드에서)
  Widget _buildTopArea() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.main100,
            AppColors.main200,
            AppColors.main300,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 폴더블 상태 표시
            const Row(
              children: [
                FoldableStatusIndicator(showDetails: true),
                Spacer(),
              ],
            ),

            const SizedBox(height: 20),

            // 회전하는 디바이스 아이콘
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
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
                      Icons.smartphone,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            const FoldableText(
              '폴더블 디바이스 감지 중',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              foldedStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // 실시간 디바이스 정보
            _buildDeviceInfoCard(),
          ],
        ),
      ),
    );
  }

  /// 하단 영역 (Z플립 텐트 모드에서)
  Widget _buildBottomArea() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.main300,
            AppColors.main400,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 폴드 상태 테스트 버튼들
            _buildTestButtons(),

            const FoldableSpacing(normalSpacing: 20, foldedSpacing: 12),

            // 실시간 윈도우 정보
            _buildWindowInfoCard(),
          ],
        ),
      ),
    );
  }

  /// 일반 디바이스용 전체 화면
  Widget _buildFullScreenContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.main100,
            AppColors.main400,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 폴더블 상태
              const FoldableStatusIndicator(showDetails: true),

              const SizedBox(height: 40),

              // 메인 아이콘
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value,
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
                        Icons.tablet_android,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // 제목
              const Text(
                '폴더블 디바이스 데모',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              // 설명
              const Text(
                'Z플립을 반으로 접어서 텐트 모드로 만들어보세요!\n상단과 하단이 분리되어 표시됩니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              // 디바이스 정보 카드
              _buildDeviceInfoCard(),

              const SizedBox(height: 20),

              // 테스트 버튼들
              _buildTestButtons(),

              const Spacer(),

              // 윈도우 정보
              _buildWindowInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// 디바이스 정보 카드
  Widget _buildDeviceInfoCard() {
    return FoldableAdaptiveWidget(
      builder: (context, windowInfo) {
        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.main600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const FoldableText(
                      '디바이스 정보',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      foldedStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (windowInfo != null) ...[
                  _buildInfoRow('폴더블 지원', windowInfo.deviceInfo.isFoldable ? '✅ 예' : '❌ 아니오'),
                  _buildInfoRow('화면 크기', '${windowInfo.deviceInfo.screenWidth} × ${windowInfo.deviceInfo.screenHeight}'),
                  _buildInfoRow('밀도', '${windowInfo.deviceInfo.density.toStringAsFixed(1)}x'),
                  _buildInfoRow('폴드 상태', _getFoldStateText(windowInfo.currentFoldState)),
                  if (windowInfo.foldingFeatures.isNotEmpty) ...[
                    _buildInfoRow('폴딩 기능', '${windowInfo.foldingFeatures.length}개'),
                    if (windowInfo.isZFlipHalfOpened)
                      _buildInfoRow('Z플립 모드', '🎪 텐트 모드'),
                  ],
                ] else ...[
                  const FoldableText(
                    '디바이스 정보를 가져오는 중...',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 테스트 버튼들
  Widget _buildTestButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final foldableService = ref.read(foldableDeviceServiceProvider);
                  final info = await foldableService.getCurrentWindowInfo();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('윈도우 정보 업데이트: ${info?.currentFoldState ?? "없음"}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const FoldableText(
                  '새로고침',
                  style: TextStyle(fontSize: 14),
                  foldedStyle: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final foldableService = ref.read(foldableDeviceServiceProvider);
                  final isFoldable = await foldableService.isDeviceFoldable();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isFoldable ? '폴더블 디바이스입니다!' : '일반 디바이스입니다.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle),
                label: const FoldableText(
                  '감지 테스트',
                  style: TextStyle(fontSize: 14),
                  foldedStyle: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.point600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 윈도우 정보 카드
  Widget _buildWindowInfoCard() {
    return FoldableAdaptiveWidget(
      builder: (context, windowInfo) {
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.window,
                      color: AppColors.main600,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const FoldableText(
                      '실시간 윈도우 정보',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      foldedStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (windowInfo != null) ...[
                  FoldableText(
                    '마지막 업데이트: ${DateTime.fromMillisecondsSinceEpoch(windowInfo.timestamp).toString().substring(11, 19)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                    foldedStyle: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                    ),
                  ),

                  if (windowInfo.foldingFeatures.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    for (final feature in windowInfo.foldingFeatures)
                      FoldableText(
                        '폴딩: ${feature.orientation} / ${feature.state}',
                        style: const TextStyle(fontSize: 10),
                        foldedStyle: const TextStyle(fontSize: 8),
                      ),
                  ],
                ] else ...[
                  const FoldableText(
                    '정보 로딩 중...',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 정보 행 빌더
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FoldableText(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
            foldedStyle: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
            ),
          ),
          FoldableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            foldedStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 폴드 상태 텍스트 변환
  String _getFoldStateText(FoldState state) {
    switch (state) {
      case FoldState.flat:
        return '📱 완전히 펼쳐짐';
      case FoldState.halfOpened:
        return '📐 반쯤 접힘';
      case FoldState.unknown:
        return '❓ 알 수 없음';
    }
  }
}
