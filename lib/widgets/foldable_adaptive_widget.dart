// lib/widgets/foldable_adaptive_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/foldable_device_service.dart';
import '../design_system/colors.dart';

/// 폴더블 디바이스 적응형 위젯
/// Z플립의 반접힘 상태에서 상단과 하단을 다르게 표시할 수 있습니다.
class FoldableAdaptiveWidget extends ConsumerWidget {
  final Widget Function(BuildContext context, WindowLayoutInfo? windowInfo) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const FoldableAdaptiveWidget({
    super.key,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldableService = ref.watch(foldableDeviceServiceProvider);

    return StreamBuilder<WindowLayoutInfo>(
      stream: foldableService.windowInfoStream,
      initialData: foldableService.currentWindowInfo,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorWidget ?? _buildErrorWidget(snapshot.error);
        }

        if (!snapshot.hasData) {
          return loadingWidget ?? _buildLoadingWidget();
        }

        return builder(context, snapshot.data);
      },
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorWidget(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('폴더블 디바이스 감지 오류'),
          Text('$error'),
        ],
      ),
    );
  }
}

/// Z플립 최적화 레이아웃 위젯
class ZFlipLayout extends StatelessWidget {
  final Widget topContent;
  final Widget bottomContent;
  final Widget? flatContent;
  final Color? hingeColor;
  final double hingeThickness;

  const ZFlipLayout({
    super.key,
    required this.topContent,
    required this.bottomContent,
    this.flatContent,
    this.hingeColor,
    this.hingeThickness = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return FoldableAdaptiveWidget(
      builder: (context, windowInfo) {
        // 폴더블 디바이스가 아니거나 완전히 펼쳐진 상태
        if (windowInfo == null ||
            !windowInfo.deviceInfo.isFoldable ||
            windowInfo.currentFoldState == FoldState.flat) {
          return flatContent ?? _buildFlatLayout();
        }

        // Z플립 반접힘 모드
        if (windowInfo.isZFlipHalfOpened) {
          return _buildZFlipHalfOpenedLayout(windowInfo);
        }

        // 기타 상태는 기본 레이아웃
        return flatContent ?? _buildFlatLayout();
      },
    );
  }

  Widget _buildFlatLayout() {
    return Column(
      children: [
        Expanded(child: topContent),
        Expanded(child: bottomContent),
      ],
    );
  }

  Widget _buildZFlipHalfOpenedLayout(WindowLayoutInfo windowInfo) {
    final topHeight = windowInfo.topAreaHeight;
    final bottomHeight = windowInfo.bottomAreaHeight;
    final hingeHeight = windowInfo.hingeHeight;

    return Column(
      children: [
        // 상단 영역
        SizedBox(
          height: topHeight,
          child: topContent,
        ),

        // 힌지 영역 (시각적 구분)
        if (hingeHeight > 0)
          Container(
            height: hingeHeight,
            color: hingeColor ?? AppColors.grey300,
            child: Center(
              child: Container(
                height: hingeThickness,
                color: AppColors.grey500,
              ),
            ),
          ),

        // 하단 영역
        SizedBox(
          height: bottomHeight,
          child: bottomContent,
        ),
      ],
    );
  }
}

/// 폴더블 상태 인디케이터 위젯
class FoldableStatusIndicator extends ConsumerWidget {
  final bool showDetails;
  final EdgeInsets? padding;

  const FoldableStatusIndicator({
    super.key,
    this.showDetails = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldableService = ref.watch(foldableDeviceServiceProvider);

    return StreamBuilder<WindowLayoutInfo>(
      stream: foldableService.windowInfoStream,
      initialData: foldableService.currentWindowInfo,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final windowInfo = snapshot.data!;

        return Container(
          padding: padding ?? const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(windowInfo).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getStatusColor(windowInfo),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(windowInfo),
                color: _getStatusColor(windowInfo),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusText(windowInfo),
                style: TextStyle(
                  color: _getStatusColor(windowInfo),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showDetails) ...[
                const SizedBox(width: 8),
                Text(
                  '${windowInfo.deviceInfo.screenWidth}×${windowInfo.deviceInfo.screenHeight}',
                  style: TextStyle(
                    color: _getStatusColor(windowInfo).withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(WindowLayoutInfo windowInfo) {
    if (!windowInfo.deviceInfo.isFoldable) {
      return Icons.smartphone;
    }

    switch (windowInfo.currentFoldState) {
      case FoldState.flat:
        return Icons.tablet_android;
      case FoldState.halfOpened:
        return windowInfo.isZFlipHalfOpened
            ? Icons.laptop_mac  // Z플립 텐트 모드
            : Icons.tablet_mac; // 기타 반접힘
      case FoldState.unknown:
        return Icons.device_unknown;
    }
  }

  Color _getStatusColor(WindowLayoutInfo windowInfo) {
    if (!windowInfo.deviceInfo.isFoldable) {
      return AppColors.grey500;
    }

    switch (windowInfo.currentFoldState) {
      case FoldState.flat:
        return AppColors.main600;
      case FoldState.halfOpened:
        return AppColors.point600;
      case FoldState.unknown:
        return AppColors.grey400;
    }
  }

  String _getStatusText(WindowLayoutInfo windowInfo) {
    if (!windowInfo.deviceInfo.isFoldable) {
      return '일반 디바이스';
    }

    switch (windowInfo.currentFoldState) {
      case FoldState.flat:
        return '펼침';
      case FoldState.halfOpened:
        return windowInfo.isZFlipHalfOpened ? 'Z플립 텐트' : '반접힘';
      case FoldState.unknown:
        return '알 수 없음';
    }
  }
}

/// 폴더블 상태에 따른 간격 조정 위젯
class FoldableSpacing extends ConsumerWidget {
  final double normalSpacing;
  final double? foldedSpacing;
  final Axis direction;

  const FoldableSpacing({
    super.key,
    required this.normalSpacing,
    this.foldedSpacing,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldableService = ref.watch(foldableDeviceServiceProvider);

    return StreamBuilder<WindowLayoutInfo>(
      stream: foldableService.windowInfoStream,
      initialData: foldableService.currentWindowInfo,
      builder: (context, snapshot) {
        final windowInfo = snapshot.data;

        // 폴더블 디바이스이고 반접힘 상태일 때 간격 조정
        double spacing = normalSpacing;
        if (windowInfo != null &&
            windowInfo.deviceInfo.isFoldable &&
            windowInfo.currentFoldState == FoldState.halfOpened) {
          spacing = foldedSpacing ?? (normalSpacing * 0.5);
        }

        return direction == Axis.vertical
            ? SizedBox(height: spacing)
            : SizedBox(width: spacing);
      },
    );
  }
}

/// 폴더블 상태에 따른 텍스트 크기 조정 위젯
class FoldableText extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? foldedStyle;
  final TextAlign? textAlign;
  final int? maxLines;

  const FoldableText(
      this.text, {
        super.key,
        this.style,
        this.foldedStyle,
        this.textAlign,
        this.maxLines,
      });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldableService = ref.watch(foldableDeviceServiceProvider);

    return StreamBuilder<WindowLayoutInfo>(
      stream: foldableService.windowInfoStream,
      initialData: foldableService.currentWindowInfo,
      builder: (context, snapshot) {
        final windowInfo = snapshot.data;

        // 폴더블 디바이스이고 반접힘 상태일 때 스타일 조정
        TextStyle? effectiveStyle = style;
        if (windowInfo != null &&
            windowInfo.deviceInfo.isFoldable &&
            windowInfo.currentFoldState == FoldState.halfOpened) {
          effectiveStyle = foldedStyle ?? style?.copyWith(fontSize: (style?.fontSize ?? 14) * 0.8);
        }

        return Text(
          text,
          style: effectiveStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null,
        );
      },
    );
  }
}