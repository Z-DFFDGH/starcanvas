import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

class PickedMedia {
  final Uint8List bytes;
  final String name;
  final String ext;

  PickedMedia(this.bytes, this.name, this.ext);
}

class PreparedImage {
  final Uint8List bytes;
  final int width;
  final int height;

  PreparedImage(this.bytes, this.width, this.height);
}

class PreparedAudio {
  final Uint8List bytes;
  final String ext;
  final int? durationMs;
  final String name;

  PreparedAudio(this.bytes, this.ext, this.durationMs, this.name);
}

class AssetService {
  static Future<PickedMedia?> pickImage() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return null;
    final f = files.single;
    final bytes = await f.readAsBytes();
    if (bytes.isEmpty) return null;
    var ext = (f.extension ?? '').toLowerCase();
    if (ext.isEmpty) ext = 'jpg';
    return PickedMedia(bytes, f.name, ext);
  }

  static Future<PickedMedia?> pickAudio() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
    );
    if (files.isEmpty) return null;
    final f = files.single;
    final bytes = await f.readAsBytes();
    if (bytes.isEmpty) return null;
    var ext = (f.extension ?? '').toLowerCase();
    if (ext.isEmpty) ext = 'mp3';
    return PickedMedia(bytes, f.name, ext);
  }

  /// 解码 + 摆正 EXIF 方向 + 限制超大图，避免低端机内存爆掉。
  static img.Image decode(Uint8List bytes, {int maxDim = 2600}) {
    var image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException('无法识别这张图片，请换一张试试');
    }
    image = img.bakeOrientation(image);
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxDim) {
      final scale = maxDim / longest;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }
    return image;
  }

  /// 背景类：裁切结果统一压成 1280x720 JPEG。
  static PreparedImage background(img.Image source) {
    var image = source;
    if (image.width != 1280 || image.height != 720) {
      image = img.copyResize(
        image,
        width: 1280,
        height: 720,
        interpolation: img.Interpolation.linear,
      );
    }
    if (image.numChannels == 4) {
      final flat = img.Image(width: 1280, height: 720, numChannels: 3);
      img.fill(flat, color: img.ColorRgb8(12, 13, 20));
      img.compositeImage(flat, image);
      image = flat;
    }
    final bytes = img.encodeJpg(image, quality: 86);
    return PreparedImage(bytes, 1280, 720);
  }

  /// 立绘/道具：自动裁掉透明边，再按高度压缩。
  static PreparedImage cutout(
    Uint8List bytes, {
    required int maxHeight,
    required int maxWidth,
  }) {
    var image = decode(bytes);
    if (image.numChannels == 4) {
      image = img.trim(image, mode: img.TrimMode.transparent, padding: 4);
    }
    var scale = 1.0;
    if (image.height > maxHeight) scale = maxHeight / image.height;
    if (image.width * scale > maxWidth) scale = maxWidth / image.width;
    if (scale < 1) {
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }
    final png = img.encodePng(image, level: 6);
    return PreparedImage(png, image.width, image.height);
  }

  static String encodeImageInfo(img.Image image) =>
      '${image.width}x${image.height}';

  /// 大图缩放/去透明边放到后台 isolate，避免低端机卡住 UI。
  static Future<PreparedImage> cutoutAsync(
    Uint8List bytes, {
    required int maxHeight,
    required int maxWidth,
  }) =>
      compute(
        _cutoutEntry,
        _CutoutJob(bytes, maxHeight: maxHeight, maxWidth: maxWidth),
      );
}

class _CutoutJob {
  final Uint8List bytes;
  final int maxHeight;
  final int maxWidth;

  const _CutoutJob(this.bytes, {required this.maxHeight, required this.maxWidth});
}

PreparedImage _cutoutEntry(_CutoutJob job) => AssetService.cutout(
      job.bytes,
      maxHeight: job.maxHeight,
      maxWidth: job.maxWidth,
    );

class AudioPreview {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playFile(File file) async {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.play(DeviceFileSource(file.path));
  }

  static Future<void> stop() => _player.stop();
}
