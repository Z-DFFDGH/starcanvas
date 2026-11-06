import 'package:flutter/foundation.dart';

import '../data/app_paths.dart';
import '../data/project_store.dart';
import '../models/models.dart';
import '../services/sample_project.dart';

class ProjectRepo extends ChangeNotifier {
  ProjectRepo._();

  static final ProjectRepo instance = ProjectRepo._();

  final List<VnProject> projects = [];
  bool loading = true;
  String? error;

  Future<void> init() async {
    try {
      await AppPaths.init();
      projects
        ..clear()
        ..addAll(await ProjectStore.list());
      final flag = AppPaths.demoFlag();
      if (!await flag.exists()) {
        if (projects.isEmpty) {
          final demo = await SampleProject.create();
          projects.add(demo);
        }
        await flag.writeAsString('${DateTime.now().millisecondsSinceEpoch}');
        projects
          ..clear()
          ..addAll(await ProjectStore.list());
      }
    } catch (e) {
      error = '初始化失败：$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<VnProject> createProject(String title) async {
    final clean = title.trim();
    final project = VnProject.fresh(
      newId('p'),
      clean.isEmpty ? '未命名作品' : clean,
    );
    await ProjectStore.write(project);
    projects.insert(0, project);
    notifyListeners();
    return project;
  }

  Future<void> save(VnProject project) async {
    await ProjectStore.write(project);
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.insert(0, project);
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  Future<void> delete(VnProject project) async {
    await ProjectStore.deleteProject(project.id);
    projects.removeWhere((p) => p.id == project.id);
    notifyListeners();
  }

  Future<void> refresh() async {
    projects
      ..clear()
      ..addAll(await ProjectStore.list());
    notifyListeners();
  }
}
