import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';

/// 记录新手引导是否已经看过。标记文件放在 APP 私有根目录，
/// 删除作品或素材不会影响它，卸载 APP 时随应用数据一起清理。
class OnboardingStore {
  static File get _flag =>
      File(p.join(AppPaths.root.path, '.onboarding_v1_seen'));

  static Future<bool> hasSeen() async {
    try {
      return await _flag.exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      await _flag.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {
      // 写标记失败也不该阻止用户关闭引导。
    }
  }
}
