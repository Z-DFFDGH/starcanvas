import 'dart:typed_data';

class CompressedAudio {
  final Uint8List bytes;
  final String ext;
  final int? durationMs;

  const CompressedAudio(this.bytes, this.ext, this.durationMs);
}

/// 轻量音频处理：
/// - WAV 统一转成 22050Hz / 单声道 / 16bit，体积可降为原来的 1/4 ~ 1/8；
/// - mp3 / ogg / m4a 本身已压缩，原样保存，避免二次转码掉音质。
class AudioCompressor {
  static const int targetSampleRate = 22050;

  static CompressedAudio compress(Uint8List input, String inputExt) {
    final ext = inputExt.toLowerCase().replaceAll('.', '');
    if (ext == 'wav' || _looksLikeWav(input)) {
      final converted = _convertWav(input);
      if (converted != null) return converted;
    }
    final safeExt = ext.isEmpty ? 'mp3' : ext;
    return CompressedAudio(input, safeExt, null);
  }

  static bool _looksLikeWav(Uint8List b) =>
      b.length > 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x41 &&
      b[10] == 0x56 &&
      b[11] == 0x45;

  static CompressedAudio? _convertWav(Uint8List input) {
    if (input.length < 44) return null;
    final data = ByteData.sublistView(input);
    var offset = 12;
    int? fmtOffset;
    int? fmtSize;
    int? dataOffset;
    int? dataSize;
    while (offset + 8 <= input.length) {
      final id = String.fromCharCodes(input.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);
      if (id == 'fmt ') {
        fmtOffset = offset + 8;
        fmtSize = size;
      } else if (id == 'data') {
        dataOffset = offset + 8;
        dataSize = size;
      }
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }
    if (fmtOffset == null || dataOffset == null) return null;
    if (fmtSize == null || fmtSize < 16) return null;
    final audioFormat = data.getUint16(fmtOffset, Endian.little);
    final channels = data.getUint16(fmtOffset + 2, Endian.little);
    final sampleRate = data.getUint32(fmtOffset + 4, Endian.little);
    final bits = data.getUint16(fmtOffset + 14, Endian.little);
    // 只处理最常见的 PCM 16bit，其它格式保持原样。
    if (audioFormat != 1 || bits != 16 || channels < 1) return null;
    final dataEnd = (dataOffset + dataSize!).clamp(0, input.length);
    final bytesPerFrame = 2 * channels;
    final frameCount = (dataEnd - dataOffset) ~/ bytesPerFrame;
    if (frameCount <= 0) return null;

    final mono = Float64List(frameCount);
    for (var i = 0; i < frameCount; i++) {
      var sum = 0;
      for (var c = 0; c < channels; c++) {
        sum += data.getInt16(dataOffset + i * bytesPerFrame + c * 2, Endian.little);
      }
      mono[i] = sum / channels / 32768.0;
    }

    final outCount = sampleRate == targetSampleRate
        ? frameCount
        : (frameCount * targetSampleRate / sampleRate).floor();
    final out = Int16List(outCount);
    final ratio = sampleRate / targetSampleRate;
    for (var i = 0; i < outCount; i++) {
      final src = i * ratio;
      final i0 = src.floor().clamp(0, frameCount - 1);
      final i1 = (i0 + 1).clamp(0, frameCount - 1);
      final t = src - i0;
      final v = mono[i0] * (1 - t) + mono[i1] * t;
      out[i] = (v * 32767).round().clamp(-32768, 32767);
    }

    final pcm = out.buffer.asUint8List(out.offsetInBytes, out.lengthInBytes);
    final result = BytesBuilder(copy: false);
    result.add(_wavHeader(pcm.length));
    result.add(pcm);
    final durationMs = (outCount / targetSampleRate * 1000).round();
    return CompressedAudio(result.takeBytes(), 'wav', durationMs);
  }

  static Uint8List _wavHeader(int dataLength) {
    final header = ByteData(44);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, targetSampleRate, Endian.little);
    header.setUint32(28, targetSampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, dataLength, Endian.little);
    return header.buffer.asUint8List();
  }
}
