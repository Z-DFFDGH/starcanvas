import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../data/project_store.dart';
import '../models/models.dart';

/// 首次启动时生成一个可直接游玩的示例工程，顺便验证图片/音频/分支/存档全链路。
class SampleProject {
  static const _rate = 22050;

  static Future<VnProject> create() async {
    final project = VnProject.fresh(newId('p'), '星海之约');
    await ProjectStore.write(project);
    final id = project.id;

    final bgSunset = _sunset();
    final bgDusk = _dusk();
    final bgNight = _night();
    final bgDawn = _dawn();
    final aoi = _character(
      dress: const (98, 142, 235),
      hair: const (60, 96, 170),
      halo: const (170, 215, 255),
      skin: const (255, 226, 210),
    );
    final hikari = _character(
      dress: const (235, 130, 170),
      hair: const (185, 105, 150),
      halo: const (255, 205, 225),
      skin: const (255, 230, 214),
    );
    final star = _starItem();

    final coverImage = img.Image(width: 1280, height: 720, numChannels: 3);
    img.compositeImage(coverImage, bgSunset);
    final coverA = img.copyResize(aoi, height: 640, interpolation: img.Interpolation.linear);
    final coverH = img.copyResize(hikari, height: 600, interpolation: img.Interpolation.linear);
    img.compositeImage(coverImage, coverA, dstX: 120, dstY: 720 - 640);
    img.compositeImage(coverImage, coverH, dstX: 760, dstY: 720 - 600);
    final coverJpg = img.encodeJpg(coverImage, quality: 86);

    final bgSunsetAsset = await _imageAsset(id, AssetKind.background, img.encodeJpg(bgSunset, quality: 86), '黄昏操场.jpg', 1280, 720);
    final bgDuskAsset = await _imageAsset(id, AssetKind.background, img.encodeJpg(bgDusk, quality: 86), '暮色走廊.jpg', 1280, 720);
    final bgNightAsset = await _imageAsset(id, AssetKind.background, img.encodeJpg(bgNight, quality: 86), '星夜草地.jpg', 1280, 720);
    final bgDawnAsset = await _imageAsset(id, AssetKind.background, img.encodeJpg(bgDawn, quality: 86), '黎明.jpg', 1280, 720);
    final coverAsset = await _imageAsset(id, AssetKind.background, coverJpg, '封面.jpg', 1280, 720);
    final aoiAsset = await _imageAsset(id, AssetKind.character, img.encodePng(aoi), '苍.png', 560, 1000, ext: 'png');
    final hikariAsset = await _imageAsset(id, AssetKind.character, img.encodePng(hikari), '光.png', 560, 1000, ext: 'png');
    final starAsset = await _imageAsset(id, AssetKind.item, img.encodePng(star), '星星.png', 240, 240, ext: 'png');

    final bgmAsset = await _audioAsset(id, _bgmWav(), '星夜摇曳.wav', 12000);
    final sfxAsset = await _audioAsset(id, _chimeWav(), '星光音效.wav', 700);
    final outroAsset = await _audioAsset(id, _outroWav(), '收尾.wav', 5000);

    project.assets.addAll([
      bgSunsetAsset,
      bgDuskAsset,
      bgNightAsset,
      bgDawnAsset,
      coverAsset,
      aoiAsset,
      hikariAsset,
      starAsset,
      bgmAsset,
      sfxAsset,
      outroAsset,
    ]);
    project.coverId = coverAsset.id;
    project.openingBgmId = bgmAsset.id;
    project.ending = EndingConfig(
      imageId: bgDawnAsset.id,
      audioId: outroAsset.id,
      text: '—— 星海之约 · 完 ——\n\n只要抬头，星星就一直在。',
    );

    VnNode makeNode(String title, String dialogue) => VnNode(
          id: newId('n'),
          title: title,
          dialogue: dialogue,
        );

    final n1 = makeNode('开场', '黄昏的操场空无一人。\n只有风穿过铁丝网，发出轻轻的嗡鸣。')
      ..backgroundId = bgSunsetAsset.id
      ..slots[1] = StageSlot(assetId: aoiAsset.id)
      ..next = null;

    final n2 = makeNode('相遇', '「你也留下来看星星吗？」\n她抱着膝盖，坐在看台最高的一级台阶上。')
      ..backgroundId = bgSunsetAsset.id
      ..slots[1] = StageSlot(assetId: aoiAsset.id)
      ..slots[2] = StageSlot(assetId: hikariAsset.id)
      ..bgmAction = BgmAction.keep;

    final n3 = makeNode('观星', '我们并排躺在草地上，数着永远数不完的星星。\n「那颗最亮的，叫什么名字？」')
      ..backgroundId = bgNightAsset.id
      ..slots[0] = StageSlot(assetId: starAsset.id)
      ..slots[1] = StageSlot(assetId: aoiAsset.id)
      ..slots[2] = StageSlot(assetId: hikariAsset.id)
      ..sfxId = sfxAsset.id
      ..bgmAction = BgmAction.keep;

    final n4 = makeNode('分别', '她挥了挥手，背影一点点融进暮色里。\n「明天……还会来吗？」')
      ..backgroundId = bgDuskAsset.id
      ..slots[1] = StageSlot(assetId: aoiAsset.id)
      ..bgmAction = BgmAction.keep;

    final n5 = makeNode('约定', '夜风把她的声音吹得很远，又很清晰。\n「明天，还在这里见。」')
      ..backgroundId = bgNightAsset.id
      ..slots[1] = StageSlot(assetId: aoiAsset.id)
      ..slots[2] = StageSlot(assetId: hikariAsset.id)
      ..bgmAction = BgmAction.keep;

    n1.next = n2.id;
    n2.choices.addAll([
      Choice(text: '「嗯，一起看吧。」', target: n3.id),
      Choice(text: '「对不起，我先回去了。」', target: n4.id),
    ]);
    n2.next = n3.id;
    n3.next = n5.id;
    n4.next = n5.id;
    n5.next = null;

    project.nodes
      ..clear()
      ..addAll([n1, n2, n3, n4, n5]);

    await ProjectStore.write(project);
    return project;
  }

  static Future<AssetRef> _imageAsset(
    String projectId,
    AssetKind kind,
    Uint8List bytes,
    String label,
    int width,
    int height, {
    String ext = 'jpg',
  }) =>
      ProjectStore.storeAsset(
        projectId,
        kind: kind,
        bytes: bytes,
        ext: ext,
        label: label,
        width: width,
        height: height,
      );

  static Future<AssetRef> _audioAsset(
    String projectId,
    Uint8List bytes,
    String label,
    int durationMs,
  ) =>
      ProjectStore.storeAsset(
        projectId,
        kind: AssetKind.audio,
        bytes: bytes,
        ext: 'wav',
        label: label,
        durationMs: durationMs,
      );

  // ---------------------------------------------------------------- 绘图

  static img.Image _sky(
    int width,
    int height,
    List<(double, int, int, int)> stops,
  ) {
    final image = img.Image(width: width, height: height, numChannels: 3);
    for (var y = 0; y < height; y++) {
      final t = y / (height - 1);
      var i = 0;
      while (i < stops.length - 2 && t > stops[i + 1].$1) {
        i++;
      }
      final a = stops[i];
      final b = stops[i + 1];
      final span = (b.$1 - a.$1).clamp(0.0001, 1.0);
      final k = ((t - a.$1) / span).clamp(0.0, 1.0);
      final r = (a.$2 + (b.$2 - a.$2) * k).round();
      final g = (a.$3 + (b.$3 - a.$3) * k).round();
      final bl = (a.$4 + (b.$4 - a.$4) * k).round();
      img.drawLine(
        image,
        x1: 0,
        y1: y,
        x2: width - 1,
        y2: y,
        color: img.ColorRgb8(r, g, bl),
      );
    }
    return image;
  }

  static void _stars(img.Image image, int count, int maxY, int seed) {
    final rnd = math.Random(seed);
    for (var i = 0; i < count; i++) {
      final x = rnd.nextInt(image.width);
      final y = rnd.nextInt(maxY);
      final r = rnd.nextInt(3) == 0 ? 2 : 1;
      final alpha = 140 + rnd.nextInt(115);
      img.fillCircle(
        image,
        x: x,
        y: y,
        radius: r,
        color: img.ColorRgba8(255, 250, 230, alpha),
      );
    }
  }

  static img.Image _sunset() {
    final image = _sky(1280, 720, const [
      (0.0, 32, 38, 84),
      (0.28, 92, 72, 138),
      (0.52, 205, 118, 132),
      (0.68, 245, 172, 122),
      (0.80, 250, 208, 150),
      (1.0, 52, 46, 62),
    ]);
    img.fillCircle(
      image,
      x: 930,
      y: 300,
      radius: 140,
      color: img.ColorRgba8(255, 226, 160, 40),
    );
    img.fillCircle(image, x: 930, y: 300, radius: 78,
        color: img.ColorRgb8(255, 232, 177));
    img.fillCircle(image, x: 930, y: 300, radius: 64,
        color: img.ColorRgb8(255, 244, 208));
    // 远处教学楼剪影
    img.fillRect(image, x1: 0, y1: 560, x2: 1280, y2: 720,
        color: img.ColorRgb8(30, 32, 48));
    img.fillRect(image, x1: 160, y1: 470, x2: 620, y2: 600,
        color: img.ColorRgb8(38, 40, 58));
    for (var i = 0; i < 5; i++) {
      img.fillRect(image, x1: 190 + i * 84, y1: 500, x2: 230 + i * 84, y2: 545,
          color: img.ColorRgba8(255, 214, 150, 70));
    }
    // 草地
    img.fillRect(image, x1: 0, y1: 640, x2: 1280, y2: 720,
        color: img.ColorRgb8(34, 44, 48));
    return image;
  }

  static img.Image _dusk() {
    final image = _sky(1280, 720, const [
      (0.0, 24, 28, 60),
      (0.35, 62, 62, 110),
      (0.65, 138, 92, 128),
      (0.82, 196, 128, 122),
      (1.0, 30, 30, 40),
    ]);
    img.fillCircle(image, x: 250, y: 220, radius: 54,
        color: img.ColorRgba8(240, 235, 220, 190));
    // 走廊柱子
    for (var i = 0; i < 6; i++) {
      img.fillRect(image, x1: 80 + i * 210, y1: 120, x2: 128 + i * 210, y2: 720,
          color: img.ColorRgb8(28, 26, 38));
    }
    img.fillRect(image, x1: 0, y1: 0, x2: 1280, y2: 110,
        color: img.ColorRgb8(24, 22, 34));
    img.fillRect(image, x1: 0, y1: 640, x2: 1280, y2: 720,
        color: img.ColorRgb8(22, 20, 30));
    return image;
  }

  static img.Image _night() {
    final image = _sky(1280, 720, const [
      (0.0, 8, 10, 32),
      (0.45, 18, 28, 70),
      (0.72, 30, 48, 102),
      (0.9, 18, 26, 44),
      (1.0, 10, 14, 22),
    ]);
    _stars(image, 190, 600, 7);
    img.fillCircle(image, x: 1020, y: 180, radius: 92,
        color: img.ColorRgba8(220, 232, 255, 30));
    img.fillCircle(image, x: 1020, y: 180, radius: 58,
        color: img.ColorRgb8(228, 238, 255));
    img.fillCircle(image, x: 1002, y: 165, radius: 10,
        color: img.ColorRgba8(190, 205, 235, 120));
    // 山丘
    img.fillPolygon(
      image,
      vertices: [
        img.Point(0, 640),
        img.Point(300, 540),
        img.Point(560, 640),
        img.Point(820, 560),
        img.Point(1100, 650),
        img.Point(1280, 590),
        img.Point(1280, 720),
        img.Point(0, 720),
      ],
      color: img.ColorRgb8(12, 20, 30),
    );
    img.fillRect(image, x1: 0, y1: 660, x2: 1280, y2: 720,
        color: img.ColorRgb8(10, 16, 24));
    return image;
  }

  static img.Image _dawn() {
    final image = _sky(1280, 720, const [
      (0.0, 52, 72, 128),
      (0.35, 132, 158, 205),
      (0.62, 246, 196, 172),
      (0.82, 255, 224, 190),
      (1.0, 96, 96, 112),
    ]);
    img.fillCircle(image, x: 640, y: 470, radius: 210,
        color: img.ColorRgba8(255, 236, 200, 45));
    img.fillCircle(image, x: 640, y: 470, radius: 100,
        color: img.ColorRgb8(255, 246, 220));
    img.fillRect(image, x1: 0, y1: 640, x2: 1280, y2: 720,
        color: img.ColorRgb8(52, 58, 70));
    img.fillRect(image, x1: 0, y1: 680, x2: 1280, y2: 720,
        color: img.ColorRgb8(38, 42, 52));
    _stars(image, 40, 240, 21);
    return image;
  }

  static img.Image _ring(
    img.Image image, {
    required int cx,
    required int cy,
    required int radius,
    required int thickness,
    required img.Color color,
  }) {
    for (var r = radius; r < radius + thickness; r++) {
      img.drawCircle(image, x: cx, y: cy, radius: r, color: color);
    }
    return image;
  }

  static img.Image _character({
    required (int, int, int) dress,
    required (int, int, int) hair,
    required (int, int, int) halo,
    required (int, int, int) skin,
  }) {
    final image = img.Image(width: 600, height: 1000, numChannels: 4);
    final hairColor = img.ColorRgb8(hair.$1, hair.$2, hair.$3);
    final dressColor = img.ColorRgb8(dress.$1, dress.$2, dress.$3);
    final dressLight = img.ColorRgb8(
      (dress.$1 + 30).clamp(0, 255),
      (dress.$2 + 30).clamp(0, 255),
      (dress.$3 + 30).clamp(0, 255),
    );
    final skinColor = img.ColorRgb8(skin.$1, skin.$2, skin.$3);

    // 光环
    img.fillCircle(image, x: 300, y: 170, radius: 120,
        color: img.ColorRgba8(halo.$1, halo.$2, halo.$3, 26));
    _ring(image, cx: 300, cy: 165, radius: 92, thickness: 9,
        color: img.ColorRgba8(halo.$1, halo.$2, halo.$3, 235));

    // 长发与身体
    img.fillCircle(image, x: 300, y: 355, radius: 150, color: hairColor);
    img.fillPolygon(
      image,
      vertices: [
        img.Point(185, 380),
        img.Point(415, 380),
        img.Point(455, 1000),
        img.Point(145, 1000),
      ],
      color: hairColor,
    );
    img.fillPolygon(
      image,
      vertices: [
        img.Point(205, 520),
        img.Point(395, 520),
        img.Point(475, 1000),
        img.Point(125, 1000),
      ],
      color: dressColor,
    );
    // 裙摆亮边
    img.fillPolygon(
      image,
      vertices: [
        img.Point(135, 940),
        img.Point(465, 940),
        img.Point(480, 1000),
        img.Point(120, 1000),
      ],
      color: dressLight,
    );
    // 手臂
    img.fillPolygon(
      image,
      vertices: [
        img.Point(205, 545),
        img.Point(250, 560),
        img.Point(190, 840),
        img.Point(150, 820),
      ],
      color: skinColor,
    );
    img.fillPolygon(
      image,
      vertices: [
        img.Point(350, 560),
        img.Point(395, 545),
        img.Point(450, 820),
        img.Point(410, 840),
      ],
      color: skinColor,
    );
    // 领口 + 蝴蝶结
    img.fillRect(image, x1: 240, y1: 515, x2: 360, y2: 560,
        color: img.ColorRgb8(250, 250, 255));
    img.fillPolygon(
      image,
      vertices: [
        img.Point(300, 555),
        img.Point(255, 530),
        img.Point(250, 585),
      ],
      color: dressLight,
    );
    img.fillPolygon(
      image,
      vertices: [
        img.Point(300, 555),
        img.Point(345, 530),
        img.Point(350, 585),
      ],
      color: dressLight,
    );
    img.fillCircle(image, x: 300, y: 557, radius: 11,
        color: img.ColorRgb8(255, 246, 220));

    // 脸
    img.fillCircle(image, x: 300, y: 385, radius: 102, color: skinColor);
    // 刘海
    img.fillPolygon(
      image,
      vertices: [
        img.Point(196, 360),
        img.Point(214, 268),
        img.Point(300, 236),
        img.Point(386, 268),
        img.Point(404, 360),
        img.Point(372, 306),
        img.Point(330, 300),
        img.Point(300, 322),
        img.Point(270, 300),
        img.Point(228, 306),
      ],
      color: hairColor,
    );
    // 眼睛
    img.fillCircle(image, x: 262, y: 392, radius: 9,
        color: img.ColorRgb8(46, 52, 88));
    img.fillCircle(image, x: 338, y: 392, radius: 9,
        color: img.ColorRgb8(46, 52, 88));
    img.fillCircle(image, x: 259, y: 388, radius: 3,
        color: img.ColorRgb8(255, 255, 255));
    img.fillCircle(image, x: 335, y: 388, radius: 3,
        color: img.ColorRgb8(255, 255, 255));
    // 腮红
    img.fillCircle(image, x: 235, y: 425, radius: 13,
        color: img.ColorRgba8(255, 160, 170, 60));
    img.fillCircle(image, x: 365, y: 425, radius: 13,
        color: img.ColorRgba8(255, 160, 170, 60));
    // 嘴
    img.drawLine(image, x1: 290, y1: 440, x2: 310, y2: 440,
        color: img.ColorRgb8(196, 118, 118), thickness: 2);
    return image;
  }

  static img.Image _starItem() {
    final image = img.Image(width: 240, height: 240, numChannels: 4);
    img.fillCircle(image, x: 120, y: 120, radius: 92,
        color: img.ColorRgba8(255, 220, 120, 30));
    img.fillCircle(image, x: 120, y: 120, radius: 64,
        color: img.ColorRgba8(255, 230, 150, 40));
    final vertices = <img.Point>[];
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? 86.0 : 36.0;
      vertices.add(
        img.Point(
          (120 + math.cos(angle) * r).round(),
          (120 + math.sin(angle) * r).round(),
        ),
      );
    }
    img.fillPolygon(image, vertices: vertices,
        color: img.ColorRgb8(255, 214, 92));
    img.fillCircle(image, x: 96, y: 92, radius: 10,
        color: img.ColorRgba8(255, 255, 255, 170));
    return image;
  }

  // ---------------------------------------------------------------- 音频

  static Uint8List _wav(List<double> samples) {
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    }
    final data = pcm.buffer.asUint8List();
    final header = ByteData(44);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + data.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, _rate, Endian.little);
    header.setUint32(28, _rate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, data.length, Endian.little);
    final builder = BytesBuilder(copy: false);
    builder.add(header.buffer.asUint8List());
    builder.add(data);
    return builder.takeBytes();
  }

  static Uint8List _bgmWav() {
    const seconds = 12;
    final n = _rate * seconds;
    final out = List<double>.filled(n, 0);
    const chords = [
      [220.0, 261.63, 329.63],
      [174.61, 220.0, 261.63],
      [130.81, 196.0, 261.63],
      [196.0, 246.94, 293.66],
    ];
    const melody = [523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25, 440.0];
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final chord = chords[(t ~/ 3) % chords.length];
      final local = t % 3;
      final env = (local / 0.8).clamp(0.0, 1.0) *
          ((3 - local) / 1.0).clamp(0.0, 1.0);
      var v = 0.0;
      for (final f in chord) {
        v += math.sin(2 * math.pi * f * t) * 0.055 * env;
        v += math.sin(2 * math.pi * f * 2 * t) * 0.012 * env;
      }
      final noteIndex = (t * 2).floor() % melody.length;
      final noteLocal = (t * 2) % 1;
      final noteEnv = math.exp(-noteLocal * 3.5) * 0.05;
      v += math.sin(2 * math.pi * melody[noteIndex] * t) * noteEnv;
      out[i] = v;
    }
    return _wav(out);
  }

  static Uint8List _chimeWav() {
    const seconds = 0.7;
    final n = (_rate * seconds).round();
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final env = math.exp(-t * 7);
      final v = math.sin(2 * math.pi * 880 * t) * 0.28 +
          math.sin(2 * math.pi * 1320 * t) * 0.12 +
          math.sin(2 * math.pi * 1760 * t) * 0.06;
      out[i] = v * env;
    }
    return _wav(out);
  }

  static Uint8List _outroWav() {
    const seconds = 5;
    final n = _rate * seconds;
    final out = List<double>.filled(n, 0);
    const chord = [261.63, 329.63, 392.0, 523.25];
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final fade = (t / 1.2).clamp(0.0, 1.0) *
          ((seconds - t) / 2.2).clamp(0.0, 1.0);
      var v = 0.0;
      for (final f in chord) {
        v += math.sin(2 * math.pi * f * t) * 0.045;
      }
      v += math.sin(2 * math.pi * 1046.5 * t) * 0.02 * math.exp(-t * 0.9);
      out[i] = v * fade;
    }
    return _wav(out);
  }
}
