// 生成安卓启动图标：深空底色 + 光环 + 金色四芒星。
// 用法：dart run tool/gen_icon.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int size = 1024;

void main() {
  final image = img.Image(width: size, height: size, numChannels: 4);

  // 垂直渐变：深靛蓝 → 近黑，再按距离叠加柔和的中心光。
  const cx = 512.0, cy = 468.0;
  for (var y = 0; y < size; y++) {
    final t = y / (size - 1);
    final baseR = 24 * (1 - t) + 8 * t;
    final baseG = 28 * (1 - t) + 9 * t;
    final baseB = 52 * (1 - t) + 18 * t;
    for (var x = 0; x < size; x++) {
      final dx = x - cx, dy = y - cy;
      final d = math.sqrt(dx * dx + dy * dy);
      final v = math.max(0.0, 1 - d / 540);
      final light = v * v;
      image.setPixelRgba(
        x,
        y,
        (baseR + light * 26).round(),
        (baseG + light * 30).round(),
        (baseB + light * 52).round(),
        255,
      );
    }
  }

  // 光环：两圈线段拼出平滑圆环。
  const radius = 258.0;
  for (var deg = 0; deg < 360; deg += 2) {
    final a = deg * math.pi / 180;
    final b = (deg + 2) * math.pi / 180;
    img.drawLine(
      image,
      x1: (cx + radius * math.cos(a)).round(),
      y1: (cy + radius * math.sin(a)).round(),
      x2: (cx + radius * math.cos(b)).round(),
      y2: (cy + radius * math.sin(b)).round(),
      color: img.ColorRgba8(138, 166, 255, 120),
      thickness: 9,
      antialias: true,
    );
    img.drawLine(
      image,
      x1: (cx + radius * math.cos(a)).round(),
      y1: (cy + radius * math.sin(a)).round(),
      x2: (cx + radius * math.cos(b)).round(),
      y2: (cy + radius * math.sin(b)).round(),
      color: img.ColorRgba8(224, 234, 255, 190),
      thickness: 2,
      antialias: true,
    );
  }

  // 四芒星：外层透明光晕 + 主星。
  _star(image, cx, cy, 172, 42, img.ColorRgba8(255, 210, 125, 30));
  _star(image, cx, cy, 146, 36, img.ColorRgba8(255, 214, 130, 70));
  _star(image, cx, cy, 126, 32, img.ColorRgba8(255, 226, 160, 255));
  _star(image, cx, cy, 76, 20, img.ColorRgba8(255, 250, 232, 255));

  // 三颗小星点缀。
  _star(image, 250, 290, 34, 9, img.ColorRgba8(200, 220, 255, 230));
  _star(image, 790, 350, 26, 7, img.ColorRgba8(200, 220, 255, 200));
  _star(image, 700, 700, 20, 6, img.ColorRgba8(255, 220, 150, 200));

  final png = img.encodePng(image);
  final targets = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in targets.entries) {
    final resized = img.copyResize(image, width: entry.value, height: entry.value);
    final file = File('android/app/src/main/res/${entry.key}/ic_launcher.png');
    file.writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('${file.path} (${entry.value}x${entry.value})');
  }
  final big = File('tool/icon_preview.png');
  big.writeAsBytesSync(png);
  stdout.writeln('${big.path} (1024x1024)');
}

void _star(img.Image image, double cx, double cy, double outer, double inner,
    img.Color color) {
  final vertices = <img.Point>[];
  for (var i = 0; i < 8; i++) {
    final rad = (-90 + i * 45) * math.pi / 180;
    final r = i.isEven ? outer : inner;
    vertices.add(img.Point(
      (cx + r * math.cos(rad)).round(),
      (cy + r * math.sin(rad)).round(),
    ));
  }
  img.fillPolygon(image, vertices: vertices, color: color);
}
