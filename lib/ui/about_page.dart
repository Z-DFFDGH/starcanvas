import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import 'widgets.dart';

/// 作者介绍页。风格参考个人作品集：深色、卡片、少量强调色。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const version = '1.1.0';
  static const repoUrl = 'https://github.com/Z-DFFDGH/starcanvas';

  Future<void> _open(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) showToast(context, '没能打开链接，请手动访问');
    } catch (_) {
      if (context.mounted) showToast(context, '没能打开链接，请手动访问');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _topBar(context),
                      const SizedBox(height: 8),
                      _hero(),
                      const SizedBox(height: 18),
                      _quote(),
                      const SizedBox(height: 18),
                      _section(
                        title: '关于我',
                        child: Text(
                          '高二理科生，自媒体博主，也是独立开发者。'
                          '平时做《蔚蓝档案》《暗区突围》等二创剪辑，常用 AE、PR、FL Studio 和 RVC 音色克隆；'
                          '写代码以 Python 为主，正在补 JS / HTML / CSS，也在折腾 AI Agent 与 ComfyUI。\n\n'
                          '白天上课，晚上剪片、写代码，偶尔仰望星空。',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.75,
                            color: AppColors.text.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        title: '正在做的事',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _SkillChip(icon: Icons.menu_book_outlined, text: '视觉小说工具'),
                            _SkillChip(icon: Icons.movie_creation_outlined, text: '二创剪辑'),
                            _SkillChip(icon: Icons.smart_toy_outlined, text: 'AI 实验'),
                            _SkillChip(icon: Icons.code, text: '独立开发'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        title: '找到我',
                        child: Column(
                          children: [
                            _LinkTile(
                              icon: Icons.alternate_email,
                              title: 'GitHub · @Z-DFFDGH',
                              subtitle: '代码、工具和实验都在这里',
                              url: 'https://github.com/Z-DFFDGH',
                              onTap: _open,
                            ),
                            const SizedBox(height: 8),
                            _LinkTile(
                              icon: Icons.auto_awesome_mosaic_outlined,
                              title: '个人作品集',
                              subtitle: '关于我、作品与联系方式',
                              url: 'https://github.com/Z-DFFDGH/portfolio',
                              onTap: _open,
                            ),
                            const SizedBox(height: 8),
                            _LinkTile(
                              icon: Icons.code,
                              title: '星绘工坊 · 开源仓库',
                              subtitle: 'Flutter 源码 · MIT License',
                              url: repoUrl,
                              onTap: _open,
                            ),
                            const SizedBox(height: 8),
                            _LinkTile(
                              icon: Icons.download_outlined,
                              title: '下载最新版 APK',
                              subtitle: '在 GitHub Releases 获取安装包',
                              url: '$repoUrl/releases',
                              onTap: _open,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        title: '关于星绘工坊',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _InfoRow(label: '版本', value: 'v$version'),
                            _InfoRow(label: '技术', value: 'Flutter · 纯本地离线'),
                            _InfoRow(label: '工程', value: '编辑器 + 播放器一体'),
                            _InfoRow(label: '许可', value: 'MIT License'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.22),
                                ),
                              ),
                              child: const Text(
                                '本应用不联网、不上传任何工程或素材。'
                                '请只使用自己拥有版权或已获授权的图片与音频；'
                                '删除作品时，绑定在工程里的素材与存档会一起清理。',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.65,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '用 Flutter 写的 · 2026 · 哈基蚌',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          tooltip: '返回',
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: const Text(
            'ABOUT',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 2,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A3560), Color(0xFF3A2348)],
            ),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '蚌',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '哈基蚌',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        const Text(
          '@Z-DFFDGH',
          style: TextStyle(fontSize: 12, color: AppColors.primary, letterSpacing: 1.2),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: const [
            _Tag('高二理科生'),
            _Tag('自媒体博主'),
            _Tag('独立开发者'),
          ],
        ),
      ],
    );
  }

  Widget _quote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2648), Color(0xFF241B38)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 34, color: AppColors.accent),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '「二次元拯救世界」',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                SizedBox(height: 3),
                Text(
                  '人生信条 · 也是做这些东西的理由',
                  style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome, color: AppColors.gold, size: 18),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title, padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.6, -0.75),
          radius: 1.1,
          colors: [
            const Color(0xFF1A2450).withValues(alpha: 0.85),
            AppColors.bg,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  final Future<void> Function(BuildContext context, String url) onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(context, url),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
