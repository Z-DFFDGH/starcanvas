import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/onboarding_store.dart';
import '../data/project_repo.dart';
import '../data/project_store.dart';
import '../models/models.dart';
import 'about_page.dart';
import 'editor_page.dart';
import 'onboarding_page.dart';
import 'player_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _booted = false;
  bool _autoGuideOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (_booted) return;
    _booted = true;
    final repo = ProjectRepo.instance;
    if (repo.loading) await repo.init();
    if (!mounted) return;
    final seen = await OnboardingStore.hasSeen();
    if (!mounted || seen || _autoGuideOpened) return;
    _autoGuideOpened = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const OnboardingPage(),
      ),
    );
  }

  Future<void> _createProject() async {
    final controller = TextEditingController(text: '我的故事');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('新建作品', style: TextStyle(fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: '给作品起个名字',
            counterText: '',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || !mounted) return;
    final project = await ProjectRepo.instance.createProject(title);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorPage(project: project)),
    );
    await ProjectRepo.instance.refresh();
  }

  Future<void> _openEditor(VnProject project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorPage(project: project)),
    );
    await ProjectRepo.instance.refresh();
  }

  Future<void> _play(VnProject project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(project: project.clone(), preview: true),
      ),
    );
  }

  Future<void> _delete(VnProject project) async {
    final ok = await confirmAction(
      context,
      title: '删除作品',
      message: '将同时删除《${project.title}》的封面、背景、立绘、道具、音频和全部存档，'
          '无法恢复。确定继续吗？',
      confirmText: '删除',
      danger: true,
    );
    if (!ok || !mounted) return;
    await ProjectRepo.instance.delete(project);
    if (mounted) showToast(context, '已删除《${project.title}》');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ProjectRepo.instance;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: repo,
          builder: (context, _) {
            if (repo.loading) return const _Splash();
            return ListView(
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                _header(repo),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Row(
                    children: [
                      const Text(
                        '我的作品',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${repo.projects.length}',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _showGuide(context),
                        icon: const Icon(Icons.help_outline, color: AppColors.muted),
                        tooltip: '使用说明',
                      ),
                    ],
                  ),
                ),
                if (repo.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppCard(
                      color: const Color(0xFF2A1A20),
                      child: Text(repo.error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  ),
                if (repo.projects.isEmpty)
                  _emptyState()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: repo.projects.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.84,
                      ),
                      itemBuilder: (context, index) => _projectCard(repo.projects[index]),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 26, 20, 10),
                  child: Text(
                    '素材与工程只保存在本机 APP 私有目录，不会上传网络。\n'
                    '删除作品时会连同它的全部素材一起清理。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.6),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF0B0F1E),
        icon: const Icon(Icons.add),
        label: const Text('新建作品', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _header(ProjectRepo repo) {
    final totalBytes = repo.projects.fold<int>(0, (sum, p) => sum + p.totalBytes);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D2747), Color(0xFF2B1B38)],
        ),
        border: Border.all(color: const Color(0xFF313A5E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '星绘工坊',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'STAR CANVAS · 零代码视觉小说',
                    style: TextStyle(fontSize: 9, color: AppColors.muted, letterSpacing: 1),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _showGuide(context),
                tooltip: '使用说明',
                icon: const Icon(Icons.info_outline, color: AppColors.muted, size: 20),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                ),
                tooltip: '作者简介',
                icon: const Icon(Icons.person_outline, color: AppColors.muted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('作品', '${repo.projects.length}'),
              _divider(),
              _stat('本地占用', formatBytes(totalBytes)),
              _divider(),
              _stat('状态', '全部离线'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.only(right: 12),
        color: const Color(0xFF313A5E),
      );

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
        child: Column(
          children: [
            const Icon(Icons.nightlight_round, size: 42, color: AppColors.primary),
            const SizedBox(height: 14),
            const Text('还没有作品', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              '点右下角「新建作品」，从一个开场、一句台词开始。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _createProject,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建作品'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectCard(VnProject project) {
    final cover = project.asset(project.coverId);
    final coverFile = cover == null ? null : ProjectStore.fileOf(project, cover);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(project),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverFile != null)
                    Image.file(
                      coverFile,
                      fit: BoxFit.cover,
                      cacheWidth: 480,
                      errorBuilder: (context, error, stack) => const _CoverFallback(),
                    )
                  else
                    const _CoverFallback(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB3000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 6,
                    child: Row(
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 11, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text(
                          '${project.nodes.length} 节点',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 2,
                    child: _cardMenu(project),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatDate(project.updatedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, color: AppColors.muted),
                          ),
                        ),
                        InkWell(
                          onTap: () => _play(project),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardMenu(VnProject project) {
    return PopupMenuButton<String>(
      tooltip: '更多',
      padding: EdgeInsets.zero,
      color: AppColors.surfaceAlt,
      icon: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_horiz, size: 16, color: Colors.white70),
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _openEditor(project);
          case 'play':
            _play(project);
          case 'delete':
            _delete(project);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
            SizedBox(width: 10),
            Text('编辑'),
          ]),
        ),
        PopupMenuItem(
          value: 'play',
          child: Row(children: [
            Icon(Icons.play_circle_outline, size: 18, color: AppColors.muted),
            SizedBox(width: 10),
            Text('试玩'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            SizedBox(width: 10),
            Text('删除', style: TextStyle(color: AppColors.danger)),
          ]),
        ),
      ],
    );
  }

  void _showGuide(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const OnboardingPage(),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 44, color: AppColors.primary),
          SizedBox(height: 16),
          Text('星绘工坊', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2)),
          SizedBox(height: 18),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted),
          ),
          SizedBox(height: 10),
          Text('第一次启动，正在布置星空…', style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF243055), Color(0xFF3A2140)],
        ),
      ),
      child: Center(
        child: Icon(Icons.auto_stories_outlined, color: Colors.white24, size: 28),
      ),
    );
  }
}

