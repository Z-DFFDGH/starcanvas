import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'app_paths.dart';

class ProjectStore {
  static Future<List<VnProject>> list() async {
    final dir = Directory(p.join(AppPaths.root.path, 'projects'));
    if (!await dir.exists()) return [];
    final result = <VnProject>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final file = File(p.join(entity.path, 'project.json'));
      if (!await file.exists()) continue;
      try {
        result.add(VnProject.fromJsonString(await file.readAsString()));
      } catch (_) {
        // 单个工程损坏不影响其他工程打开。
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  static Future<void> write(VnProject project) async {
    final dir = AppPaths.projectDir(project.id);
    await Directory(p.join(dir.path, 'assets')).create(recursive: true);
    await Directory(p.join(dir.path, 'saves')).create(recursive: true);
    project.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final target = AppPaths.projectFile(project.id);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(project.toJsonString(), flush: true);
    await tmp.rename(target.path);
  }

  static Future<AssetRef> storeAsset(
    String projectId, {
    required AssetKind kind,
    required Uint8List bytes,
    required String ext,
    String? label,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    final dir = AppPaths.assetsDir(projectId);
    await dir.create(recursive: true);
    final id = newId('a');
    final fileName = '$id.$ext';
    await File(p.join(dir.path, fileName)).writeAsBytes(bytes, flush: true);
    return AssetRef(
      id: id,
      kind: kind,
      fileName: fileName,
      bytes: bytes.length,
      width: width,
      height: height,
      durationMs: durationMs,
      label: label,
    );
  }

  static File fileOf(VnProject project, AssetRef asset) =>
      File(p.join(AppPaths.assetsDir(project.id).path, asset.fileName));

  static File assetFile(String projectId, AssetRef asset) =>
      File(p.join(AppPaths.assetsDir(projectId).path, asset.fileName));

  static Future<void> deleteProject(String id) async {
    final dir = AppPaths.projectDir(id);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 清掉素材目录里没有任何引用/记录的残留文件。
  static Future<void> cleanupOrphans(VnProject project) async {
    final dir = AppPaths.assetsDir(project.id);
    if (!await dir.exists()) return;
    final keep = project.assets.map((a) => a.fileName).toSet();
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && !keep.contains(p.basename(entity.path))) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  static Future<int> diskUsage(String id) async {
    final dir = AppPaths.projectDir(id);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }
}
