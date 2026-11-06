import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/onboarding_store.dart';

/// 首次打开 APP 自动展示的新手引导，也可以从首页「使用说明」再次打开。
/// 不联网、不加载大图，低端机也能秒开。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _closing = false;

  static const List<_Step> _steps = [
    _Step(
      icon: Icons.auto_awesome,
      color: AppColors.primary,
      kicker: '2 分钟上手',
      title: '欢迎来到星绘工坊',
      intro: '不用写代码，也能做出一部能玩的视觉小说。'
          '编辑器、播放器、存档都在这一个 APP 里，作品只保存在你的手机上。',
      points: [
        _Point(Icons.phone_android, '不用导出、不用打包，编辑完直接试玩'),
        _Point(Icons.bolt_outlined, '素材自动压缩，千元机也能流畅运行'),
        _Point(Icons.lock_outline, '完全离线，工程不会上传到任何服务器'),
      ],
      tip: '下面用 9 个小步骤，把从新建到发布的流程走一遍。',
    ),
    _Step(
      icon: Icons.add_circle_outline,
      color: AppColors.gold,
      kicker: 'STEP 1 · 新建作品',
      title: '先建一个空工程',
      intro: '每一个故事都是一个独立工程，类似剪映里的一个本地项目。',
      points: [
        _Point(Icons.touch_app_outlined, '首页右下角点「新建作品」，给故事起个名字'),
        _Point(Icons.auto_awesome_outlined, '创建后自动进入编辑器，并生成第一个剧情节点'),
        _Point(Icons.folder_outlined, '这个工程的封面、素材、存档都会放进自己的文件夹'),
      ],
    ),
    _Step(
      icon: Icons.movie_creation_outlined,
      color: AppColors.accent,
      kicker: 'STEP 2 · 开始模块',
      title: '设置作品的门面',
      intro: '「开始」模块决定别人第一眼看到什么。',
      points: [
        _Point(Icons.title, '作品标题：显示在作品库和播放器顶栏'),
        _Point(Icons.image_outlined, '封面图：上传后按 16:9 裁切，不会把人物拉变形'),
        _Point(Icons.music_note, '开场 BGM：进入第一段剧情时自动播放'),
      ],
      tip: '封面和结局画面建议用同一套画风，作品看起来会更完整。',
    ),
    _Step(
      icon: Icons.layers_outlined,
      color: AppColors.primary,
      kicker: 'STEP 3 · 剧情模块',
      title: '安排舞台上的角色和道具',
      intro: '一段剧情就是一个「节点」。节点里可以随时换背景、换人物。',
      points: [
        _Point(Icons.wallpaper_outlined, '背景随时切换；不想重复上传就选「沿用上一幕」'),
        _Point(Icons.accessibility_new, '角色有 5 个点位：最左 / 左 / 中 / 右 / 最右'),
        _Point(Icons.auto_awesome_mosaic_outlined, '道具是独立列表，不占角色格，可以同时摆多个'),
        _Point(Icons.graphic_eq, '每个节点都能设置 BGM 保持 / 播放 / 停止，以及音效'),
      ],
      tip: '新增节点会自动继承当前舞台，不用每次从头摆。',
    ),
    _Step(
      icon: Icons.chat_bubble_outline,
      color: AppColors.accent,
      kicker: 'STEP 4 · 对话模块',
      title: '写台词，做分支',
      intro: '台词会以打字机效果逐字出现，点一下屏幕可以立即显示全句。',
      points: [
        _Point(Icons.keyboard_outlined, '在台词框里输入这一段的对话'),
        _Point(Icons.alt_route, '最多 4 个分支 A/B/C/D，每个分支下拉选择要跳转的节点'),
        _Point(Icons.arrow_forward, '没有分支时，指定「点击继续到」哪个节点'),
        _Point(Icons.timer_outlined, '还能设置几秒无操作自动跳转，适合做演出节奏'),
      ],
      tip: '有生效分支时，点屏幕不会自动走，必须由玩家点选项。',
    ),
    _Step(
      icon: Icons.flag_outlined,
      color: AppColors.gold,
      kicker: 'STEP 5 · 结束模块',
      title: '给故事一个结尾',
      intro: '结局画面、收尾音频、结局文字都在这里设置。',
      points: [
        _Point(Icons.image_outlined, '结局画面按 16:9 裁切，可以放插画或制作名单'),
        _Point(Icons.music_note, '收尾音频会在结局出现时播放'),
        _Point(Icons.text_fields, '结局文字显示在「— 完 —」下方'),
      ],
    ),
    _Step(
      icon: Icons.play_circle_outline,
      color: AppColors.primary,
      kicker: 'STEP 6 · 试玩与存档',
      title: '在 APP 里直接玩',
      intro: '不用导出安装包。编辑器右上角的播放键，随时进入播放器。',
      points: [
        _Point(Icons.play_arrow, '可以从第一个节点试玩，也可以从当前节点开始'),
        _Point(Icons.screen_rotation, '播放器自动横屏全屏，点屏幕推进剧情'),
        _Point(Icons.save_outlined, '每个作品有 6 个存档位，作品之间完全隔离，不会串档'),
        _Point(Icons.photo_camera_outlined, '存档会自动截取当前舞台，方便认出进度'),
      ],
      tip: '试玩时也可以存档，回到编辑器继续改，存档会保留。',
    ),
    _Step(
      icon: Icons.photo_library_outlined,
      color: AppColors.accent,
      kicker: 'STEP 7 · 素材与清理',
      title: '素材会自动变轻',
      intro: '背景、立绘、道具、BGM、音效都支持从手机里选。',
      points: [
        _Point(Icons.crop, '图片上传后可拖动、双指缩放裁切，防止拉伸变形'),
        _Point(Icons.compress, '图片和音频会自动压缩，节省空间和内存'),
        _Point(Icons.delete_outline, '删除作品时，它的全部素材和存档会一起清理'),
      ],
      tip: '重要原图建议自己另外留一份，APP 里保存的是压缩后的版本。',
    ),
    _Step(
      icon: Icons.rocket_launch_outlined,
      color: AppColors.gold,
      kicker: 'READY',
      title: '可以开始了',
      intro: '最快的上手方式：打开示例《星海之约》，改一句台词，再点播放。',
      points: [
        _Point(Icons.auto_awesome, '第一次启动会自动创建一个示例工程'),
        _Point(Icons.edit_outlined, '在示例上改台词、换背景，比从空白开始更快'),
        _Point(Icons.person_outline, '作者简介在首页右上角的人像按钮里'),
      ],
      tip: '看完后，这条引导不会再自动弹出；想复习可以从「使用说明」重新打开。',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    await OnboardingStore.markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _steps.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _steps.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            const Positioned.fill(child: _Glow()),
            SafeArea(
              child: Column(
                children: [
                  _topBar(isLast),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _steps.length,
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (context, index) => _StepView(
                        step: _steps[index],
                        stepNumber: index + 1,
                        total: _steps.length,
                      ),
                    ),
                  ),
                  _bottomBar(isLast),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text(
            '新手引导',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              '${_index + 1} / ${_steps.length}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.muted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _finish,
            child: Text(
              isLast ? '关闭' : '跳过',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(bool isLast) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.92),
        border: const Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _steps.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.primary
                        : AppColors.muted.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_index > 0) ...[
                TextButton(
                  onPressed: () => _goTo(_index - 1),
                  child: const Text(
                    '上一步',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: isLast ? _finish : () => _goTo(_index + 1),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: isLast ? AppColors.accent : AppColors.primary,
                    foregroundColor: AppColors.bg,
                  ),
                  child: Text(
                    isLast ? '开始创作' : '下一步',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.step,
    required this.stepNumber,
    required this.total,
  });

  final _Step step;
  final int stepNumber;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: step.color.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(step.icon, color: step.color, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                step.kicker,
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: step.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.intro,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.text.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 18),
              for (final point in step.points) ...[
                _PointTile(point: point, color: step.color),
                const SizedBox(height: 8),
              ],
              if (step.tip != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.tip!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.gold.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '第 $stepNumber / $total 步',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.muted.withValues(alpha: 0.65),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  const _PointTile({required this.point, required this.color});

  final _Point point;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(point.icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                point.text,
                style: const TextStyle(fontSize: 13, height: 1.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.75, -0.85),
            radius: 1.2,
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.bg.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.icon,
    required this.color,
    required this.kicker,
    required this.title,
    required this.intro,
    required this.points,
    this.tip,
  });

  final IconData icon;
  final Color color;
  final String kicker;
  final String title;
  final String intro;
  final List<_Point> points;
  final String? tip;
}

class _Point {
  const _Point(this.icon, this.text);

  final IconData icon;
  final String text;
}
