import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcanvas/services/audio_compress.dart';

/// 造一个 44.1kHz / 双声道 / 16bit 的 WAV。
Uint8List makeWav({
  int sampleRate = 44100,
  int channels = 2,
  int frames = 4410,
}) {
  final dataSize = frames * channels * 2;
  final bytes = Uint8List(44 + dataSize);
  final view = ByteData.sublistView(bytes);
  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  writeAscii(0, 'RIFF');
  view.setUint32(4, 36 + dataSize, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little); // PCM
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * channels * 2, Endian.little);
  view.setUint16(32, channels * 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  view.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < frames; i++) {
    final sample = (i % 200) * 60 - 6000;
    for (var c = 0; c < channels; c++) {
      view.setInt16(44 + (i * channels + c) * 2, sample, Endian.little);
    }
  }
  return bytes;
}

void main() {
  group('AudioCompressor', () {
    test('WAV 转 22050Hz 单声道，体积变小', () {
      final input = makeWav();
      final out = AudioCompressor.compress(input, 'wav');

      expect(out.ext, 'wav');
      expect(out.bytes.length, lessThan(input.length));
      expect(out.durationMs, closeTo(100, 5));

      final view = ByteData.sublistView(out.bytes);
      expect(String.fromCharCodes(out.bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(out.bytes.sublist(8, 12)), 'WAVE');
      expect(view.getUint16(22, Endian.little), 1); // mono
      expect(view.getUint32(24, Endian.little), 22050);
      expect(view.getUint16(34, Endian.little), 16);
    });

    test('mp3 原样保存，不二次转码', () {
      final fake = Uint8List.fromList(List.generate(128, (i) => i));
      final out = AudioCompressor.compress(fake, 'mp3');
      expect(out.ext, 'mp3');
      expect(out.bytes, fake);
      expect(out.durationMs, isNull);
    });

    test('损坏的 WAV 不崩溃，退回原文件', () {
      final broken = Uint8List.fromList(List.generate(60, (i) => i));
      final out = AudioCompressor.compress(broken, 'wav');
      expect(out.bytes.length, 60);
    });
  });
}
