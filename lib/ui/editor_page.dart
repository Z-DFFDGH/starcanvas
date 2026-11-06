import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/project_repo.dart';
import '../data/project_store.dart';
import '../models/models.dart';
import '../services/asset_service.dart';
import '../services/audio_compress.dart';
import 'crop_page.dart';
import 'player_page.dart';
import 'stage_view.dart';
import 'widgets.dart';

class EditorPage extends StatefulWidget {
  final VnProject project;

  const EditorPage({super.key, required this.project});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WidgetsBindingObserver {
  late VnProject _project;
  late String _selectedId;

  final _titleCtrl = TextEditingController();
  final _nodeTitleCtrl = TextEditingController();
  final _dialogueCtrl = TextEditingController();
  final _endingCtrl = TextEditingController();

  Timer? _saveTimer;
  bool _saving = false;
  bool _pendingSave = false;
  String? _playingId;
  bool _exiting = false;

  VnNode get _node => _project.node(_selectedId) ?? _project.nodes.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _project = widget.project.clone();
    _selectedId = _project.nodes.first.id;
    _titleCtrl.text = _project.title;
    _nodeTitleCtrl.text = _node.title;
    _dialogueCtrl.text = _node.dialogue;
    _endingCtrl.text = _project.ending.text;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _titleCtrl.dispose();
    _nodeTitleCtrl.dispose();
    _dialogueCtrl.dispose();
    _endingCtrl.dispose();
    AudioPreview.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveTimer?.cancel();
      unawaited(_saveNow());
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => _saveNow());
  }

  Future<void> _saveNow({bool toast = false}) async {
    if (_saving) {
      _pendingSave = true;
      return;
    }
    _saving = true;
    try {
      await ProjectRepo.instance.save(_project);
      if (toast && mounted) showToast(context, '已保存到本机');
    } catch (e) {
      if (mounted) showToast(context, '保存失败：$e');
    } finally {
      _saving = false;
      if (_pendingSave) {
        _pendingSave = false;
        unawaited(_saveNow());
      }
    }
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    _saveTimer?.cancel();
    await _saveNow();
    if (mounted) Navigator.of(context).pop();
  }

  void _selectNode(String id) {
    final node = _project.node(id);
    if (node == null) return;
    setState(() {
      _selectedId = id;
      _nodeTitleCtrl.text = node.title;
      _dialogueCtrl.text = node.dialogue;
    });
    _scheduleSave();
  }

  Future<String?> _askName(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '节点名称', counterText: ''),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  // ---------------------------------------------------------------- 节点条

  Widget _nodeStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
          child: Row(
            children: [
              const Text('剧情节点', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const Spacer(),
              Text(
                '开头 → 分支 → 结局',
                style: TextStyle(fontSize: 10, color: AppColors.muted.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _project.nodes.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == _project.nodes.length) return _addNodeCard();
              final node = _project.nodes[index];
              final selected = node.id == _selectedId;
              return GestureDetector(
                onTap: () => _selectNode(node.id),
                onLongPress: () => _nodeActions(node),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 112,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.13)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.line,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            (index + 1).toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1,
                              color: selected ? AppColors.primary : AppColors.muted,
                            ),
                          ),
                          const Spacer(),
                          if (index == 0)
                            const Icon(Icons.flag_outlined, size: 11, color: AppColors.gold)
                          else if (node.hasChoices)
                            const Icon(Icons.call_split, size: 11, color: AppColors.accent)
                          else if (node.next == null)
                            const Icon(Icons.flag_circle_outlined, size: 11, color: AppColors.muted),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.text : AppColors.text.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        node.dialogue.trim().isEmpty ? '（无台词）' : node.dialogue.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _addNodeCard() {
    return GestureDetector(
      onTap: _addNode,
      child: Container(
        width: 62,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 20, color: AppColors.primary),
            SizedBox(height: 2),
            Text('新增', style: TextStyle(fontSize: 10, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Future<void> _addNode() async {
    final current = _node;
    final name = await _askName('新增剧情节点', '节点 ${_project.nodes.length + 1}');
    if (name == null || !mounted) return;
    final node = current.copyStageAs(newId('n'), name.trim().isEmpty ? '新节点' : name.trim());
    _project.nodes.add(node);
    if (!current.hasChoices && current.next == null) {
      current.next = node.id;
    }
    _selectNode(node.id);
  }

  VnNode _duplicateNode(VnNode source) => VnNode(
        id: newId('n'),
        title: '${source.title} · 副本',
        dialogue: source.dialogue,
        backgroundId: source.backgroundId,
        slots: source.slots.map((s) => s.copy()).toList(),
        choices: source.choices.map((c) => Choice(text: c.text, target: c.target)).toList(),
        next: source.next,
        bgmAction: source.bgmAction,
        bgmId: source.bgmId,
        sfxId: source.sfxId,
      );

  Future<void> _nodeActions(VnNode node) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  Text(node.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('${node.dialogue.length} 字',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('复制节点'),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('从这个节点开始试玩'),
              onTap: () => Navigator.pop(context, 'play'),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.primary),
              title: const Text('在这里新增下一节点'),
              onTap: () => Navigator.pop(context, 'add'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('删除节点', style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'rename':
        final name = await _askName('重命名节点', node.title);
        if (name != null && name.trim().isNotEmpty) {
          setState(() {
            node.title = name.trim();
            if (node.id == _selectedId) _nodeTitleCtrl.text = node.title;
          });
          _scheduleSave();
        }
      case 'duplicate':
        final copy = _duplicateNode(node);
        final index = _project.nodes.indexOf(node);
        _project.nodes.insert(index + 1, copy);
        _selectNode(copy.id);
      case 'play':
        await _playPreview(startNodeId: node.id);
      case 'add':
        _selectNode(node.id);
        await _addNode();
      case 'delete':
        await _deleteNode(node);
    }
  }

  Future<void> _deleteNode(VnNode node) async {
    if (_project.nodes.length <= 1) {
      showToast(context, '至少要保留一个节点');
      return;
    }
    final refs = _project.nodes
        .where((n) =>
            n.id != node.id &&
            (n.next == node.id || n.choices.any((c) => c.target == node.id)))
        .length;
    final ok = await confirmAction(
      context,
      title: '删除节点',
      message: refs == 0
          ? '确定删除「${node.title}」吗？'
          : '有 $refs 个节点会跳转到「${node.title}」，删除后这些跳转会被清空。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok || !mounted) return;
    final index = _project.nodes.indexOf(node);
    _project.nodes.removeAt(index);
    for (final n in _project.nodes) {
      if (n.next == node.id) n.next = null;
      for (final c in n.choices) {
        if (c.target == node.id) c.target = null;
      }
    }
    final target = _project.nodes[index.clamp(0, _project.nodes.length - 1)];
    _selectNode(target.id);
  }

  // ------------------------------------------------------------- 图片/音频

  String _shortName(String name) {
    var base = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (base.length > 18) base = base.substring(0, 18);
    return base.isEmpty ? '素材' : base;
  }

  Future<T> _busy<T>(Future<T> Function() task, String message) async {
    if (!mounted) return task();
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Text(message, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    try {
      return await task();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<AssetRef?> _uploadImage(AssetKind kind) async {
    final picked = await AssetService.pickImage();
    if (picked == null || !mounted) return null;
    try {
      PreparedImage prepared;
      if (kind == AssetKind.background) {
        final result = await Navigator.of(context).push<PreparedImage>(
          MaterialPageRoute(
            builder: (_) => CropPage(bytes: picked.bytes, title: '裁切背景（16:9）'),
          ),
        );
        if (result == null || !mounted) return null;
        prepared = result;
      } else {
        prepared = await _busy(
          () => AssetService.cutoutAsync(
            picked.bytes,
            maxHeight: kind == AssetKind.character ? 1000 : 360,
            maxWidth: kind == AssetKind.character ? 900 : 480,
          ),
          kind == AssetKind.character ? '正在裁掉透明边并压缩立绘…' : '正在处理道具图…',
        );
      }
      final asset = await _busy(
        () => ProjectStore.storeAsset(
          _project.id,
          kind: kind,
          bytes: prepared.bytes,
          ext: kind == AssetKind.background ? 'jpg' : 'png',
          label: _shortName(picked.name),
          width: prepared.width,
          height: prepared.height,
        ),
        '正在存入本地素材库…',
      );
      _project.assets.add(asset);
      _scheduleSave();
      return asset;
    } catch (e) {
      if (mounted) showToast(context, '图片处理失败：$e');
      return null;
    }
  }

  Future<AssetRef?> _uploadAudio() async {
    final picked = await AssetService.pickAudio();
    if (picked == null || !mounted) return null;
    try {
      final compressed = await _busy(
        () async => AudioCompressor.compress(picked.bytes, picked.ext),
        '正在压缩音频…',
      );
      final asset = await _busy(
        () => ProjectStore.storeAsset(
          _project.id,
          kind: AssetKind.audio,
          bytes: compressed.bytes,
          ext: compressed.ext,
          label: _shortName(picked.name),
          durationMs: compressed.durationMs,
        ),
        '正在存入本地素材库…',
      );
      _project.assets.add(asset);
      _scheduleSave();
      return asset;
    } catch (e) {
      if (mounted) showToast(context, '音频处理失败：$e');
      return null;
    }
  }

  Future<AssetRef?> _pickImageAsset({
    required String title,
    required Set<AssetKind> kinds,
    required List<AssetKind> uploadKinds,
  }) async {
    final choice = await showModalBottomSheet<_AssetChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) =>
          _ImagePickerSheet(project: _project, title: title, kinds: kinds, uploadKinds: uploadKinds),
    );
    if (choice == null || !mounted) return null;
    if (choice.uploadKind != null) return _uploadImage(choice.uploadKind!);
    return choice.asset;
  }

  Future<AssetRef?> _pickAudioAsset(String title) async {
    final choice = await showModalBottomSheet<_AssetChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _AudioPickerSheet(project: _project, title: title),
    );
    if (choice == null || !mounted) return null;
    if (choice.uploadKind != null) return _uploadAudio();
    return choice.asset;
  }

  Future<void> _toggleAudio(AssetRef asset) async {
    if (_playingId == asset.id) {
      await AudioPreview.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    await AudioPreview.playFile(ProjectStore.fileOf(_project, asset));
    if (mounted) setState(() => _playingId = asset.id);
  }

  // ------------------------------------------------------------- 模块 UI

  Widget _moduleHeader(IconData icon, String title, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(hint, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          if (trailing != null) ...[
            const Spacer(),
            Text(trailing, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _imageTile({
    required String label,
    required String? assetId,
    required String hint,
    required Future<void> Function() onPick,
    VoidCallback? onClear,
    bool enabled = true,
  }) {
    final asset = _project.asset(assetId);
    final file = asset == null ? null : ProjectStore.fileOf(_project, asset);
    return GestureDetector(
      onTap: enabled ? onPick : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            AssetThumb(file: file, size: 46, radius: 9),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    asset?.displayName ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: asset == null ? AppColors.muted : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            if (asset != null && enabled && onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
                tooltip: '清除',
              ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: enabled ? AppColors.muted : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioTile({
    required String label,
    required String? assetId,
    required String hint,
    required Future<void> Function() onPick,
    bool showClear = true,
    VoidCallback? onClear,
  }) {
    final asset = _project.asset(assetId);
    final playing = asset != null && _playingId == asset.id;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const AssetThumb(
              file: null,
              size: 44,
              radius: 9,
              icon: Icons.music_note,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    asset?.displayName ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: asset == null ? AppColors.muted : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            if (asset != null)
              IconButton(
                onPressed: () => _toggleAudio(asset),
                icon: Icon(
                  playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                  size: 21,
                  color: playing ? AppColors.accent : AppColors.primary,
                ),
                tooltip: playing ? '停止' : '试听',
              ),
            if (showClear)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
                tooltip: '清除',
              )
            else
              const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _startModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader(Icons.flag_outlined, '开始模块', '标题 · 封面 · 开场音乐'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('作品标题'),
              TextField(
                controller: _titleCtrl,
                maxLength: 24,
                decoration: _decoration('给故事起一个名字').copyWith(counterText: ''),
                onChanged: (value) {
                  _project.title = value;
                  setState(() {});
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 12),
              _imageTile(
                label: '封面图（自动裁成 16:9）',
                assetId: _project.coverId,
                hint: '点这里上传封面',
                onPick: () async {
                  final asset = await _pickImageAsset(
                    title: '选择封面',
                    kinds: const {AssetKind.background},
                    uploadKinds: const [AssetKind.background],
                  );
                  if (asset == null || !mounted) return;
                  setState(() => _project.coverId = asset.id);
                  _scheduleSave();
                },
                onClear: () {
                  setState(() => _project.coverId = null);
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 8),
              _audioTile(
                label: '开场 BGM',
                assetId: _project.openingBgmId,
                hint: '不设置也可以，进入后仍可切歌',
                onPick: () async {
                  final asset = await _pickAudioAsset('选择开场 BGM');
                  if (asset == null || !mounted) return;
                  setState(() => _project.openingBgmId = asset.id);
                  _scheduleSave();
                },
                onClear: () {
                  setState(() => _project.openingBgmId = null);
                  _scheduleSave();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _slotCard(VnNode node, int index) {
    final slot = node.slots[index];
    final asset = _project.asset(slot.assetId);
    final file = asset == null ? null : ProjectStore.fileOf(_project, asset);
    final hidden = asset != null && !slot.visible;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                StageView.positionLabels[index],
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const Spacer(),
              if (asset != null)
                GestureDetector(
                  onTap: () {
                    setState(() => slot.visible = !slot.visible);
                    _scheduleSave();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      slot.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 15,
                      color: slot.visible ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () async {
              final picked = await _pickImageAsset(
                title: '选择${StageView.positionLabels[index]}点位的素材',
                kinds: const {AssetKind.character, AssetKind.item},
                uploadKinds: const [AssetKind.character, AssetKind.item],
              );
              if (picked == null || !mounted) return;
              setState(() {
                slot.assetId = picked.id;
                slot.visible = true;
              });
              _scheduleSave();
            },
            child: Row(
              children: [
                Opacity(
                  opacity: hidden ? 0.35 : 1,
                  child: AssetThumb(
                    file: file,
                    size: 40,
                    radius: 8,
                    icon: Icons.person_outline,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    asset?.displayName ?? '点此选择',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: asset == null ? AppColors.muted : AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  final picked = await _pickImageAsset(
                    title: '选择${StageView.positionLabels[index]}点位的素材',
                    kinds: const {AssetKind.character, AssetKind.item},
                    uploadKinds: const [AssetKind.character, AssetKind.item],
                  );
                  if (picked == null || !mounted) return;
                  setState(() {
                    slot.assetId = picked.id;
                    slot.visible = true;
                  });
                  _scheduleSave();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: Text(asset == null ? '选择' : '更换'),
              ),
              const Spacer(),
              if (asset != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      slot.assetId = null;
                      slot.visible = true;
                    });
                    _scheduleSave();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: AppColors.muted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndPlace(AssetKind kind) async {
    final asset = await _uploadImage(kind);
    if (asset == null || !mounted) return;
    final node = _node;
    final empty = node.slots.indexWhere((s) => s.isEmpty);
    if (empty < 0) {
      showToast(context, '四个点位都满了，先清除一个再上传');
      return;
    }
    setState(() {
      node.slots[empty].assetId = asset.id;
      node.slots[empty].visible = true;
    });
    _scheduleSave();
  }

  Widget _storyModule() {
    final node = _node;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader(Icons.auto_stories_outlined, '剧情模块', '背景 · 角色/道具四点位 · 音乐'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('节点名称'),
              TextField(
                controller: _nodeTitleCtrl,
                maxLength: 20,
                decoration: _decoration('例如：初遇').copyWith(counterText: ''),
                onChanged: (value) {
                  node.title = value;
                  setState(() {});
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 12),
              _imageTile(
                label: '背景（16:9）',
                assetId: node.backgroundId,
                hint: '沿用上一节点的背景',
                onPick: () async {
                  final asset = await _pickImageAsset(
                    title: '选择背景',
                    kinds: const {AssetKind.background},
                    uploadKinds: const [AssetKind.background],
                  );
                  if (asset == null || !mounted) return;
                  setState(() => node.backgroundId = asset.id);
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '角色与道具共用同一个舞台的 4 个点位。',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ),
                  if (node.backgroundId != null)
                    TextButton(
                      onPressed: () {
                        setState(() => node.backgroundId = null);
                        _scheduleSave();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        textStyle: const TextStyle(fontSize: 10),
                      ),
                      child: const Text('改为沿用上一幕'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.55,
                children: [
                  for (var i = 0; i < 4; i++) _slotCard(node, i),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadAndPlace(AssetKind.character),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('上传角色', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadAndPlace(AssetKind.item),
                      icon: const Icon(Icons.image_outlined, size: 16),
                      label: const Text('上传道具', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 26),
              _label('BGM 控制'),
              SegmentedButton<BgmAction>(
                segments: const [
                  ButtonSegment(value: BgmAction.keep, label: Text('保持')),
                  ButtonSegment(value: BgmAction.play, label: Text('播放')),
                  ButtonSegment(value: BgmAction.stop, label: Text('停止')),
                ],
                selected: {node.bgmAction},
                showSelectedIcon: false,
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (value) {
                  setState(() => node.bgmAction = value.first);
                  _scheduleSave();
                },
              ),
              if (node.bgmAction == BgmAction.play) ...[
                const SizedBox(height: 8),
                _audioTile(
                  label: '播放这首 BGM',
                  assetId: node.bgmId,
                  hint: '选择 BGM',
                  onPick: () async {
                    final asset = await _pickAudioAsset('选择 BGM');
                    if (asset == null || !mounted) return;
                    setState(() => node.bgmId = asset.id);
                    _scheduleSave();
                  },
                  onClear: () {
                    setState(() => node.bgmId = null);
                    _scheduleSave();
                  },
                ),
              ],
              const SizedBox(height: 8),
              _audioTile(
                label: '进入本节点时播放的音效',
                assetId: node.sfxId,
                hint: '可选，例如脚步声、风铃',
                onPick: () async {
                  final asset = await _pickAudioAsset('选择音效');
                  if (asset == null || !mounted) return;
                  setState(() => node.sfxId = asset.id);
                  _scheduleSave();
                },
                onClear: () {
                  setState(() => node.sfxId = null);
                  _scheduleSave();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String? value,
    required ValueChanged<String?> onChanged,
    String? hint,
    String endingValue = '__ending__',
    String endingLabel = '进入结局',
    bool includeEnding = false,
  }) {
    final items = <DropdownMenuItem<String>>[
      if (hint != null) DropdownMenuItem(value: '', child: Text(hint, style: const TextStyle(color: AppColors.muted))),
      if (includeEnding)
        DropdownMenuItem(
          value: endingValue,
          child: Text(endingLabel, style: const TextStyle(color: AppColors.gold)),
        ),
      for (final n in _project.nodes)
        DropdownMenuItem(
          value: n.id,
          child: Text(
            n.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
    ];
    final valid = items.any((item) => item.value == value) ? value : null;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: valid,
        isExpanded: true,
        isDense: true,
        hint: hint == null ? null : Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        items: items,
        style: const TextStyle(fontSize: 12, color: AppColors.text),
        onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v),
      ),
    );
  }

  Widget _choiceRow(VnNode node, int index) {
    while (node.choices.length <= index) {
      node.choices.add(Choice());
    }
    final choice = node.choices[index];
    final letter = String.fromCharCode(65 + index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              letter,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: ValueKey('choice-${node.id}-$index'),
                  initialValue: choice.text,
                  maxLength: 24,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: '选项 $letter 的文字（留空则不显示）',
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  ),
                  onChanged: (value) {
                    choice.text = value;
                    _scheduleSave();
                  },
                ),
                Row(
                  children: [
                    const Icon(Icons.subdirectory_arrow_right, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _dropdown(
                        value: choice.target ?? '',
                        hint: '选择要跳转的节点',
                        onChanged: (value) {
                          setState(() => choice.target = value);
                          _scheduleSave();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogueModule() {
    final node = _node;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader(Icons.chat_bubble_outline, '对话模块', '台词 · 打字机 · A/B/C/D 分支'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('本节点台词', trailing: '打字机逐字显示'),
              TextField(
                controller: _dialogueCtrl,
                minLines: 3,
                maxLines: 8,
                style: const TextStyle(fontSize: 13, height: 1.5),
                decoration: _decoration('在这里写角色说的话……'),
                onChanged: (value) {
                  node.dialogue = value;
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.call_split, size: 14, color: AppColors.accent),
                  const SizedBox(width: 5),
                  const Text('分支选项', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const Spacer(),
                  Text(
                    node.hasChoices ? '${node.activeChoices.length} 个生效' : '填了文字才出现按钮',
                    style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < 4; i++) _choiceRow(node, i),
              if (node.hasChoices)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '有生效分支时，点击画面不会自动跳转，必须选一个选项。',
                    style: TextStyle(fontSize: 9.5, color: AppColors.muted, height: 1.5),
                  ),
                ),
              const Divider(height: 24),
              _label('没有分支时，点击画面继续到'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: _dropdown(
                  value: node.next ?? '__ending__',
                  includeEnding: true,
                  onChanged: (value) {
                    setState(() => node.next = value);
                    _scheduleSave();
                  },
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: _addNode,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增节点', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final copy = _duplicateNode(node);
                      final index = _project.nodes.indexOf(node);
                      _project.nodes.insert(index + 1, copy);
                      _selectNode(copy.id);
                    },
                    icon: const Icon(Icons.copy_all_outlined, size: 16),
                    label: const Text('复制节点', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _playPreview(startNodeId: node.id),
                    icon: const Icon(Icons.play_arrow_rounded, size: 17),
                    label: const Text('从这试玩', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteNode(node),
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                    label: const Text('删除', style: TextStyle(fontSize: 11.5, color: AppColors.danger)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _endingModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader(Icons.flag_circle_outlined, '结束模块', '结局画面 · 收尾音频 · 结束语'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _imageTile(
                label: '结局画面（16:9）',
                assetId: _project.ending.imageId,
                hint: '不设置就用深色背景 + 结束语',
                onPick: () async {
                  final asset = await _pickImageAsset(
                    title: '选择结局画面',
                    kinds: const {AssetKind.background},
                    uploadKinds: const [AssetKind.background],
                  );
                  if (asset == null || !mounted) return;
                  setState(() => _project.ending.imageId = asset.id);
                  _scheduleSave();
                },
                onClear: () {
                  setState(() => _project.ending.imageId = null);
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 8),
              _audioTile(
                label: '收尾音频',
                assetId: _project.ending.audioId,
                hint: '可选，进入结局时播放',
                onPick: () async {
                  final asset = await _pickAudioAsset('选择收尾音频');
                  if (asset == null || !mounted) return;
                  setState(() => _project.ending.audioId = asset.id);
                  _scheduleSave();
                },
                onClear: () {
                  setState(() => _project.ending.audioId = null);
                  _scheduleSave();
                },
              ),
              const SizedBox(height: 12),
              _label('结局文字'),
              TextField(
                controller: _endingCtrl,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontSize: 13, height: 1.5),
                decoration: _decoration('例如：故事到这里就结束了。'),
                onChanged: (value) {
                  _project.ending.text = value;
                  _scheduleSave();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _playPreview({String? startNodeId}) async {
    _saveTimer?.cancel();
    await _saveNow();
    if (!mounted) return;
    await AudioPreview.stop();
    if (!mounted) return;
    setState(() => _playingId = null);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          project: _project.clone(),
          startNodeId: startNodeId ?? _project.nodes.first.id,
          preview: true,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _exit,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _project.title.isEmpty ? '未命名作品' : _project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '${_project.nodes.length} 个节点 · 自动保存',
                style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '立即保存',
              onPressed: () => _saveNow(toast: true),
              icon: const Icon(Icons.save_outlined, size: 20),
            ),
            IconButton(
              tooltip: '从头试玩',
              onPressed: () => _playPreview(),
              icon: const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 2),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            _nodeStrip(),
            const SizedBox(height: 2),
            Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: StageView(
                  project: _project,
                  backgroundId: node.backgroundId,
                  slots: node.slots,
                  showPlaceholders: true,
                ),
              ),
            ),
            _startModule(),
            _storyModule(),
            _dialogueModule(),
            _endingModule(),
          ],
        ),
      ),
    );
  }
}

class _AssetChoice {
  final AssetKind? uploadKind;
  final AssetRef? asset;

  const _AssetChoice.upload(this.uploadKind) : asset = null;
  const _AssetChoice.pick(this.asset) : uploadKind = null;
}

class _ImagePickerSheet extends StatelessWidget {
  final VnProject project;
  final String title;
  final Set<AssetKind> kinds;
  final List<AssetKind> uploadKinds;

  const _ImagePickerSheet({
    required this.project,
    required this.title,
    required this.kinds,
    required this.uploadKinds,
  });

  String _uploadLabel(AssetKind kind) => switch (kind) {
        AssetKind.background => '上传图片',
        AssetKind.character => '上传角色立绘',
        AssetKind.item => '上传道具小图',
        AssetKind.audio => '上传音频',
      };

  @override
  Widget build(BuildContext context) {
    final assets = project.assets.where((a) => kinds.contains(a.kind)).toList().reversed.toList();
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.56,
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 19, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (uploadKinds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final kind in uploadKinds)
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.pop(context, _AssetChoice.upload(kind)),
                        icon: Icon(
                          kind == AssetKind.character
                              ? Icons.person_add_alt_1
                              : kind == AssetKind.item
                                  ? Icons.image_outlined
                                  : Icons.add_photo_alternate_outlined,
                          size: 16,
                        ),
                        label: Text(_uploadLabel(kind), style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: assets.isEmpty
                  ? const Center(
                      child: Text(
                        '素材库还是空的，\n先上传一张试试。',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.7),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: assets.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final asset = assets[index];
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, _AssetChoice.pick(asset)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    ProjectStore.fileOf(project, asset),
                                    fit: BoxFit.cover,
                                    cacheWidth: 240,
                                    errorBuilder: (context, error, stack) => Container(
                                      color: AppColors.surfaceAlt,
                                      child: const Icon(Icons.broken_image, color: AppColors.muted),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                asset.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioPickerSheet extends StatelessWidget {
  final VnProject project;
  final String title;

  const _AudioPickerSheet({required this.project, required this.title});

  @override
  Widget build(BuildContext context) {
    final assets = project.assets.where((a) => a.kind == AssetKind.audio).toList().reversed.toList();
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 19, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(context, const _AssetChoice.upload(AssetKind.audio)),
                  icon: const Icon(Icons.library_music_outlined, size: 16),
                  label: const Text('从手机上传音频', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: assets.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有音频素材。\n支持 mp3 / wav / ogg / m4a，WAV 会自动压缩。',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.7),
                      ),
                    )
                  : ListView.separated(
                      itemCount: assets.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppColors.line),
                      itemBuilder: (context, index) {
                        final asset = assets[index];
                        return ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.music_note, size: 18, color: AppColors.primary),
                          ),
                          title: Text(
                            asset.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            formatBytes(asset.bytes),
                            style: const TextStyle(fontSize: 10, color: AppColors.muted),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_circle_outline, color: AppColors.muted),
                            onPressed: () => AudioPreview.playFile(ProjectStore.fileOf(project, asset)),
                          ),
                          onTap: () => Navigator.pop(context, _AssetChoice.pick(asset)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
