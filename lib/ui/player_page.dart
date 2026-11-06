import 'dart:async';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../data/project_store.dart';
import '../data/save_store.dart';
import '../models/models.dart';
import 'stage_view.dart';
import 'widgets.dart';

/// 游玩/预览播放器。
///
/// 横屏全屏，负责打字机、舞台、音频、分支和存读档；
/// 存档写在当前工程的 saves/ 目录里，和其他工程完全隔离。
class PlayerPage extends StatefulWidget {
  final VnProject project;
  final String? startNodeId;
  final bool preview;

  const PlayerPage({
    super.key,
    required this.project,
    this.startNodeId,
    this.preview = false,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  static const _typingTick = Duration(milliseconds: 28);

  VnNode? _node;
  String? _bg;
  List<StageSlot> _slots = List.generate(5, (_) => StageSlot());
  List<PropSlot> _props = [];
  String? _bgmId;

  String _fullText = '';
  String _shownText = '';
  List<int> _runes = const [];
  int _shownCount = 0;
  Timer? _typer;
  Timer? _autoTimer;
  bool _ended = false;

  AudioPlayer? _bgm;
  AudioPlayer? _sfx;
  int _bgmToken = 0;

  final GlobalKey _captureKey = GlobalKey();
  bool _savingShot = false;

  bool get _typing => _shownCount < _runes.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _bgm = AudioPlayer();
    _sfx = AudioPlayer();
    _bgm!.setReleaseMode(ReleaseMode.loop);
    _sfx!.setReleaseMode(ReleaseMode.stop);

    final start =
        widget.project.node(widget.startNodeId) ?? widget.project.startNode;
    _enterNode(start, initial: true, notify: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typer?.cancel();
    _autoTimer?.cancel();
    _bgmToken++;
    _bgm?.dispose();
    _sfx?.dispose();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _autoTimer?.cancel();
      _bgm?.pause();
    } else if (state == AppLifecycleState.resumed && !_ended) {
      _bgm?.resume();
      _scheduleAutoAdvance();
    }
  }

  // ---------------------------------------------------------------- 剧情推进

  void _enterNode(VnNode node, {bool initial = false, bool notify = true}) {
    _typer?.cancel();
    _autoTimer?.cancel();
    _node = node;
    if (node.backgroundId != null) _bg = node.backgroundId;
    _slots = node.slots.map((s) => s.copy()).toList();
    _props = node.props.map((p) => p.copy()).toList();
    _fullText = node.dialogue;
    _runes = _fullText.runes.toList();
    _shownCount = 0;
    _shownText = '';
    _ended = false;
    if (notify) {
      setState(() {});
    }
    unawaited(_applyBgm(node, initial: initial));
    if (node.sfxId != null) unawaited(_playSfx(node.sfxId!));
    _startTyping();
  }

  Future<void> _applyBgm(VnNode node, {required bool initial}) async {
    final player = _bgm;
    if (player == null) return;
    try {
      switch (node.bgmAction) {
        case BgmAction.stop:
          _bgmToken++;
          await player.stop();
          _bgmId = null;
        case BgmAction.play:
          final id = node.bgmId;
          if (id != null && id.isNotEmpty && id != _bgmId) {
            await _playBgm(id);
          }
        case BgmAction.keep:
          final opening = widget.project.openingBgmId;
          if (initial && _bgmId == null && opening != null && opening.isNotEmpty) {
            await _playBgm(opening);
          }
      }
    } catch (_) {}
  }

  Future<void> _playBgm(String id) async {
    final player = _bgm;
    if (player == null) return;
    final asset = widget.project.asset(id);
    if (asset == null) return;
    final file = ProjectStore.fileOf(widget.project, asset);
    if (!await file.exists()) return;
    final token = ++_bgmToken;
    try {
      await player.stop();
      if (!mounted || token != _bgmToken) return;
      await player.play(DeviceFileSource(file.path), volume: 0.75);
      if (token == _bgmToken) _bgmId = id;
    } catch (_) {}
  }

  Future<void> _playSfx(String id) async {
    final player = _sfx;
    if (player == null) return;
    final asset = widget.project.asset(id);
    if (asset == null) return;
    final file = ProjectStore.fileOf(widget.project, asset);
    if (!await file.exists()) return;
    try {
      await player.stop();
      await player.play(DeviceFileSource(file.path), volume: 0.85);
    } catch (_) {}
  }

  void _startTyping() {
    _typer?.cancel();
    if (_runes.isEmpty) {
      _scheduleAutoAdvance();
      return;
    }
    _typer = Timer.periodic(_typingTick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_shownCount < _runes.length) _shownCount++;
        _shownText = String.fromCharCodes(_runes.take(_shownCount));
      });
      if (_shownCount >= _runes.length) {
        timer.cancel();
        _scheduleAutoAdvance();
      }
    });
  }

  void _completeTyping() {
    _typer?.cancel();
    setState(() {
      _shownCount = _runes.length;
      _shownText = _fullText;
    });
    _scheduleAutoAdvance();
  }

  /// 无选项时按工程设置自动进入下一节点；打字过程中不计时。
  void _scheduleAutoAdvance() {
    _autoTimer?.cancel();
    final node = _node;
    if (node == null || _ended || _typing) return;
    if (node.hasChoices) return;
    final ms = widget.project.autoAdvanceMs;
    if (ms <= 0) return;
    _autoTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) _advance();
    });
  }

  void _advance() {
    if (_ended) return;
    final node = _node;
    if (node == null) return;
    _autoTimer?.cancel();
    if (_typing) {
      _completeTyping();
      return;
    }
    if (node.hasChoices) return;
    final next = node.next;
    if (next == null || next.isEmpty) {
      _showEnding();
      return;
    }
    final target = widget.project.node(next);
    if (target == null) {
      _showEnding();
      return;
    }
    _enterNode(target);
  }

  void _choose(Choice choice) {
    _autoTimer?.cancel();
    if (_typing) {
      _completeTyping();
      return;
    }
    final target = choice.target;
    if (target == null || target.isEmpty) {
      _showEnding();
      return;
    }
    final node = widget.project.node(target);
    if (node == null) {
      _showEnding();
      return;
    }
    _enterNode(node);
  }

  Future<void> _showEnding() async {
    if (_ended || !mounted) return;
    _typer?.cancel();
    _bgmToken++;
    try {
      await _bgm?.stop();
    } catch (_) {}
    _bgmId = null;
    if (!mounted) return;
    setState(() => _ended = true);
    final audio = widget.project.ending.audioId;
    if (audio != null && audio.isNotEmpty) unawaited(_playSfx(audio));
  }

  Future<void> _restart() async {
    _bgmToken++;
    try {
      await _bgm?.stop();
      await _sfx?.stop();
    } catch (_) {}
    _bgmId = null;
    _bg = null;
    _slots = List.generate(5, (_) => StageSlot());
    _props = [];
    if (!mounted) return;
    _enterNode(widget.project.startNode, initial: true);
  }

  void _close() {
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- 存档

  Future<void> _openSaves({required bool load}) async {
    if (_node == null) return;
    _autoTimer?.cancel();
    final result = await showModalBottomSheet<_SaveTap>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _SaveSlotsSheet(
        project: widget.project,
        saveMode: !load,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      _scheduleAutoAdvance();
      return;
    }
    if (result.save) {
      await _saveToSlot(result.slot);
      if (mounted) _scheduleAutoAdvance();
    } else if (result.state != null) {
      await _loadState(result.state!);
    }
  }

  Future<void> _saveToSlot(int slot) async {
    if (_savingShot) return;
    final node = _node;
    if (node == null) return;
    _savingShot = true;
    try {
      final thumb = await _captureThumb();
      final fileName = 'slot_$slot.png';
      if (thumb != null) {
        final file = SaveStore.thumbFile(widget.project.id, fileName);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(thumb, flush: true);
      }
      final snippet = _fullText.length > 40
          ? _fullText.substring(0, 40)
          : _fullText;
      final state = SaveState(
        slot: slot,
        nodeId: node.id,
        backgroundId: _bg,
        slots: _slots.map((s) => s.copy()).toList(),
        props: _props.map((p) => p.copy()).toList(),
        bgmId: _bgmId,
        snippet: snippet.trim(),
        savedAt: DateTime.now().millisecondsSinceEpoch,
        thumbFile: thumb != null ? fileName : '',
      );
      await SaveStore.write(widget.project.id, state);
      if (mounted) showToast(context, '已保存到 $slot 号位');
    } catch (_) {
      if (mounted) showToast(context, '存档失败，请重试');
    } finally {
      _savingShot = false;
    }
  }

  Future<void> _loadState(SaveState state) async {
    final node = widget.project.node(state.nodeId);
    if (node == null) {
      if (mounted) showToast(context, '这个存档的剧情节点已经被删除');
      return;
    }
    _typer?.cancel();
    _autoTimer?.cancel();
    _bgmToken++;
    try {
      await _bgm?.stop();
    } catch (_) {}
    _bgmId = null;
    if (!mounted) return;
    setState(() {
      _node = node;
      _bg = state.backgroundId;
      _slots = state.slots.map((s) => s.copy()).toList();
      _props = state.props.map((p) => p.copy()).toList();
      _fullText = node.dialogue;
      _runes = _fullText.runes.toList();
      _shownCount = 0;
      _shownText = '';
      _ended = false;
    });
    _startTyping();
    if (state.bgmId != null && state.bgmId!.isNotEmpty) {
      unawaited(_playBgm(state.bgmId!));
    }
    if (node.sfxId != null) unawaited(_playSfx(node.sfxId!));
  }

  Future<Uint8List?> _captureThumb() async {
    final boundary = _captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    try {
      final image = await boundary.toImage(pixelRatio: 0.45);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- 界面

  @override
  Widget build(BuildContext context) {
    final node = _node;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _ended ? null : _advance,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              key: _captureKey,
              child: StageView(
                project: widget.project,
                backgroundId: _bg,
                slots: _slots,
                props: _props,
              ),
            ),
            if (!_ended && node != null) _topBar(),
            if (!_ended && node != null) _bottomUi(node),
            if (_ended) _endingView(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.62),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                _toolButton(Icons.arrow_back_rounded, '返回', _close),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    widget.project.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (widget.preview) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      '预览',
                      style: TextStyle(color: AppColors.primary, fontSize: 10),
                    ),
                  ),
                ],
                const Spacer(),
                _toolButton(
                  Icons.save_outlined,
                  '存档',
                  () => _openSaves(load: false),
                ),
                _toolButton(
                  Icons.folder_open_rounded,
                  '读档',
                  () => _openSaves(load: true),
                ),
                _toolButton(Icons.restart_alt_rounded, '重开', _restart),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _bottomUi(VnNode node) {
    final showChoices = node.hasChoices && !_typing;
    final choices = showChoices ? node.activeChoices : const <Choice>[];
    final shortSide = MediaQuery.sizeOf(context).shortestSide;
    final fontSize = shortSide < 380 ? 15.0 : 17.0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.82),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 6),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (choices.isNotEmpty) ...[
                      _choiceList(choices),
                      const SizedBox(height: 10),
                    ],
                    _dialogueBox(node, fontSize),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choiceList(List<Choice> choices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 7,
          children: [
            for (var i = 0; i < choices.length; i++)
              SizedBox(
                width: itemWidth,
                child: _choiceButton(choices[i], i),
              ),
          ],
        );
      },
    );
  }

  Widget _choiceButton(Choice choice, int index) {
    final letter = String.fromCharCode(65 + index);
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => _choose(choice),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  choice.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogueBox(VnNode node, double fontSize) {
    final hasTitle = node.title.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle) ...[
            Row(
              children: [
                Container(width: 3, height: 13, color: AppColors.accent),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
          ],
          Text(
            _shownText.isEmpty ? ' ' : _shownText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: fontSize,
              height: 1.62,
            ),
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: 1.25),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _typing
                    ? '轻触跳过'
                    : (node.hasChoices ? '选择一个选项' : '轻触继续'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                node.hasChoices && !_typing
                    ? Icons.touch_app_outlined
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _endingView() {
    final ending = widget.project.ending;
    final image = widget.project.asset(ending.imageId);
    final text = ending.text.trim().isEmpty ? '故事到这里就结束了。' : ending.text;
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF05060A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image.file(
                ProjectStore.fileOf(widget.project, image),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) =>
                    const ColoredBox(color: Color(0xFF0B0D16)),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '— 完 —',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 13,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 17,
                            height: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _restart,
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: const Text('重新开始'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _close,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: Text(
                              widget.preview ? '返回编辑器' : '返回作品库',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveTap {
  final int slot;
  final SaveState? state;
  final bool save;

  const _SaveTap.save(this.slot)
      : state = null,
        save = true;

  const _SaveTap.load(this.slot, this.state) : save = false;
}

class _SaveSlotsSheet extends StatefulWidget {
  final VnProject project;
  final bool saveMode;

  const _SaveSlotsSheet({required this.project, required this.saveMode});

  @override
  State<_SaveSlotsSheet> createState() => _SaveSlotsSheetState();
}

class _SaveSlotsSheetState extends State<_SaveSlotsSheet> {
  List<SaveState?>? _saves;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final saves = await SaveStore.readAll(widget.project.id);
    if (mounted) setState(() => _saves = saves);
  }

  Future<void> _onTap(int slot, SaveState? state) async {
    if (widget.saveMode) {
      if (state != null) {
        final ok = await confirmAction(
          context,
          title: '覆盖 $slot 号存档？',
          message: '这个位置原来的进度会被新的进度替换。',
          confirmText: '覆盖',
        );
        if (!ok || !mounted) return;
      }
      Navigator.of(context).pop(_SaveTap.save(slot));
    } else {
      if (state == null) return;
      Navigator.of(context).pop(_SaveTap.load(slot, state));
    }
  }

  Future<void> _delete(int slot) async {
    final ok = await confirmAction(
      context,
      title: '删除 $slot 号存档？',
      message: '只删除这一条存档，不影响作品和素材。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok || !mounted) return;
    await SaveStore.delete(widget.project.id, slot);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final saves = _saves;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 4),
              child: Row(
                children: [
                  Text(
                    widget.saveMode ? '保存进度' : '读取进度',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '每个作品独立存档',
                    style: TextStyle(
                      color: AppColors.muted.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: saves == null
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: SaveStore.slotCount,
                      itemBuilder: (context, index) {
                        final slot = index + 1;
                        return _slotCard(slot, saves[index]);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(
                widget.saveMode ? '轻触存到空位，长按可删除旧存档' : '轻触读取存档，长按可删除',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotCard(int slot, SaveState? state) {
    final thumb = state != null && state.thumbFile.isNotEmpty
        ? SaveStore.thumbFile(widget.project.id, state.thumbFile)
        : null;
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onTap(slot, state),
        onLongPress: state == null ? null : () => _delete(slot),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb != null)
                Image.file(
                  thumb,
                  fit: BoxFit.cover,
                  cacheWidth: 480,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) =>
                      const _EmptyThumb(),
                )
              else
                const _EmptyThumb(),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.fromLTRB(9, 14, 9, 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state == null
                            ? (widget.saveMode ? '+ 存入 $slot 号位' : '$slot 号 · 空')
                            : '$slot 号 · ${_nodeTitle(state)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (state != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          formatDate(state.savedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nodeTitle(SaveState state) {
    final node = widget.project.node(state.nodeId);
    return node?.title ?? '已删除的节点';
  }
}

class _EmptyThumb extends StatelessWidget {
  const _EmptyThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1E31), Color(0xFF101220)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.bookmark_border_rounded,
          color: AppColors.muted.withValues(alpha: 0.55),
          size: 24,
        ),
      ),
    );
  }
}
