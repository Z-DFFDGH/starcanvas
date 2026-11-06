import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/project_store.dart';
import '../models/models.dart';

/// 舞台渲染：编辑器预览和播放器共用同一套点位/缩放规则。
/// 四个点位 x 中心：最左 9% · 左 30% · 右 70% · 最右 91%。
class StageView extends StatelessWidget {
  final VnProject project;
  final String? backgroundId;
  final List<StageSlot> slots;
  final bool showPlaceholders;

  const StageView({
    super.key,
    required this.project,
    required this.backgroundId,
    required this.slots,
    this.showPlaceholders = false,
  });

  static const positions = [0.09, 0.30, 0.70, 0.91];
  static const positionLabels = ['最左', '左', '右', '最右'];

  @override
  Widget build(BuildContext context) {
    final background = project.asset(backgroundId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final charHeight = math.min(h * 0.82, w * 0.55);
        final itemHeight = math.min(h * 0.18, w * 0.15);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (background != null)
                Image.file(
                  ProjectStore.fileOf(project, background),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) => const _StageFallback(),
                )
              else
                const _StageFallback(),
              for (var i = 0; i < 4; i++)
                _slot(
                  project: project,
                  slot: slots.length > i ? slots[i] : StageSlot(),
                  index: i,
                  width: w,
                  height: h,
                  charHeight: charHeight,
                  itemHeight: itemHeight,
                ),
              if (showPlaceholders)
                for (var i = 0; i < 4; i++)
                  if (slots.length <= i || slots[i].assetId == null)
                    Positioned(
                      left: w * positions[i] - 30,
                      bottom: 6,
                      width: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            positionLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _slot({
    required VnProject project,
    required StageSlot slot,
    required int index,
    required double width,
    required double height,
    required double charHeight,
    required double itemHeight,
  }) {
    final asset = project.asset(slot.assetId);
    if (asset == null || !slot.visible) return const SizedBox.shrink();
    final isItem = asset.kind == AssetKind.item;
    final targetHeight = isItem ? itemHeight : charHeight;
    final double ratio;
    if (asset.width != null && asset.height != null && asset.height! > 0) {
      ratio = asset.width! / asset.height!;
    } else {
      ratio = isItem ? 1.0 : 0.56;
    }
    final targetWidth = targetHeight * ratio;
    final centerX = width * positions[index];
    final left = centerX - targetWidth / 2;
    final top = isItem ? height * 0.55 - targetHeight / 2 : height - targetHeight;
    return Positioned(
      left: left,
      top: top,
      width: targetWidth,
      height: targetHeight,
      child: Image.file(
        ProjectStore.fileOf(project, asset),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
    );
  }
}

class _StageFallback extends StatelessWidget {
  const _StageFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF161A2C), Color(0xFF0C0D14)],
        ),
      ),
      child: Center(
        child: Icon(Icons.image_outlined, color: AppColors.line, size: 40),
      ),
    );
  }
}

/// 编辑器里带 16:9 边框的预览卡片。
class StagePreviewCard extends StatelessWidget {
  final VnProject project;
  final VnNode node;

  const StagePreviewCard({super.key, required this.project, required this.node});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: StageView(
            project: project,
            backgroundId: node.backgroundId,
            slots: node.slots,
            showPlaceholders: true,
          ),
        ),
      ),
    );
  }
}
