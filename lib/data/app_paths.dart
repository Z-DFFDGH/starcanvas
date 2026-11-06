import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// 所有工程、素材、存档都在 APP 私有目录里，卸载即清理。
class AppPaths {
  static late Directory root;

  static Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    root = Directory(p.join(base.path, 'starcanvas'));
    await Directory(p.join(root.path, 'projects')).create(recursive: true);
  }

  static Directory projectDir(String id) =>
      Directory(p.join(root.path, 'projects', id));

  static Directory assetsDir(String id) =>
      Directory(p.join(projectDir(id).path, 'assets'));

  static Directory savesDir(String id) =>
      Directory(p.join(projectDir(id).path, 'saves'));

  static File projectFile(String id) =>
      File(p.join(projectDir(id).path, 'project.json'));

  static File demoFlag() => File(p.join(root.path, '.demo_created'));
}
