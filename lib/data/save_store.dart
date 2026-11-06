import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'app_paths.dart';

/// 每个工程有独立 saves 目录，天然不会串档。
class SaveStore {
  static const int slotCount = 6;

  static File _jsonFile(String projectId, int slot) =>
      File(p.join(AppPaths.savesDir(projectId).path, 'slot_$slot.json'));

  static File thumbFile(String projectId, String fileName) =>
      File(p.join(AppPaths.savesDir(projectId).path, fileName));

  static Future<List<SaveState?>> readAll(String projectId) async {
    final result = List<SaveState?>.filled(slotCount, null);
    for (var slot = 1; slot <= slotCount; slot++) {
      final file = _jsonFile(projectId, slot);
      if (!await file.exists()) continue;
      try {
        result[slot - 1] = SaveState.fromJson(
          Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map),
        );
      } catch (_) {}
    }
    return result;
  }

  static Future<void> write(String projectId, SaveState state) async {
    final dir = AppPaths.savesDir(projectId);
    await dir.create(recursive: true);
    final file = _jsonFile(projectId, state.slot);
    await file.writeAsString(jsonEncode(state.toJson()), flush: true);
  }

  static Future<void> delete(String projectId, int slot) async {
    final dir = AppPaths.savesDir(projectId);
    final json = _jsonFile(projectId, slot);
    if (await json.exists()) await json.delete();
    for (final ext in const ['png', 'jpg']) {
      final thumb = File(p.join(dir.path, 'slot_$slot.$ext'));
      if (await thumb.exists()) await thumb.delete();
    }
  }
}
