import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/theme.dart';
import '../services/asset_service.dart';

/// 固定 16:9 的自适应裁切页：拖动 + 双指缩放，输出统一尺寸，绝不拉伸变形。
class CropPage extends StatefulWidget {
  final Uint8List bytes;
  final String title;

  const CropPage({super.key, required this.bytes, this.title = '裁切画面'});

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  img.Image? _image;
  Uint8List? _preview;
  String? _error;

  double _zoom = 1;
  Offset _offset = Offset.zero;
  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  Size _frame = Size.zero;
  Size _base = Size.zero;

  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      var image = AssetService.decode(widget.bytes);
      final longest = math.max(image.width, image.height);
      if (longest > 1600) {
        final scale = 1600 / longest;
        image = img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.linear,
        );
      }
      _image = image;
      _preview = img.encodeJpg(image, quality: 92);
    } catch (e) {
      _error = e is FormatException ? e.message : '图片打开失败';
    }
    if (mounted) setState(() {});
  }

  void _reset() {
    setState(() {
      _zoom = 1;
      _offset = Offset.zero;
    });
  }

  void _confirm() {
    final image = _image;
    if (image == null || _frame.width == 0) return;
    setState(() => _working = true);
    final w = _base.width * _zoom;
    final h = _base.height * _zoom;
    final eff = _base.width / image.width * _zoom;
    if (eff <= 0) return;
    final sx = ((w - _frame.width) / 2 - _offset.dx) / eff;
    final sy = ((h - _frame.height) / 2 - _offset.dy) / eff;
    final sw = _frame.width / eff;
    final sh = _frame.height / eff;
    final x = sx.round().clamp(0, image.width - 1);
    final y = sy.round().clamp(0, image.height - 1);
    final cw = sw.round().clamp(1, image.width - x);
    final ch = sh.round().clamp(1, image.height - y);
    final cropped = img.copyCrop(image, x: x, y: y, width: cw, height: ch);
    final prepared = AssetService.background(cropped);
    if (mounted) Navigator.of(context).pop(prepared);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090F),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _image == null ? null : _reset,
            child: const Text('重置'),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: AppColors.muted)),
              ),
            )
          : _image == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      '双指缩放 · 拖动调整位置',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          var fw = constraints.maxWidth - 32;
                          var fh = fw * 9 / 16;
                          final maxH = constraints.maxHeight - 24;
                          if (fh > maxH) {
                            fh = maxH;
                            fw = fh * 16 / 9;
                          }
                          _frame = Size(fw, fh);
                          final image = _image!;
                          final baseScale = math.max(
                            fw / image.width,
                            fh / image.height,
                          );
                          _base = Size(
                            image.width * baseScale,
                            image.height * baseScale,
                          );
                          final w = _base.width * _zoom;
                          final h = _base.height * _zoom;
                          final maxX = math.max(0.0, (w - fw) / 2);
                          final maxY = math.max(0.0, (h - fh) / 2);
                          final offset = Offset(
                            _offset.dx.clamp(-maxX, maxX),
                            _offset.dy.clamp(-maxY, maxY),
                          );
                          return Center(
                            child: GestureDetector(
                              onDoubleTap: _reset,
                              onScaleStart: (d) {
                                _startZoom = _zoom;
                                _startOffset = offset;
                                _startFocal = d.focalPoint;
                              },
                              onScaleUpdate: (d) {
                                final zoom =
                                    (_startZoom * d.scale).clamp(1.0, 4.0);
                                final nw = _base.width * zoom;
                                final nh = _base.height * zoom;
                                final mx = math.max(0.0, (nw - fw) / 2);
                                final my = math.max(0.0, (nh - fh) / 2);
                                final off = _startOffset +
                                    (d.focalPoint - _startFocal);
                                setState(() {
                                  _zoom = zoom;
                                  _offset = Offset(
                                    off.dx.clamp(-mx, mx),
                                    off.dy.clamp(-my, my),
                                  );
                                });
                              },
                              child: Container(
                                width: fw,
                                height: fh,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.7),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: (fw - w) / 2 + offset.dx,
                                        top: (fh - h) / 2 + offset.dy,
                                        width: w,
                                        height: h,
                                        child: Image.memory(
                                          _preview!,
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.low,
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: CustomPaint(
                                          size: Size(fw, fh),
                                          painter: _GridPainter(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _working
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(44, 48),
                                  foregroundColor: AppColors.muted,
                                  side: const BorderSide(color: AppColors.line),
                                ),
                                child: const Text('取消'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: _working ? null : _confirm,
                                child: Text(_working ? '处理中…' : '完成裁切'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
