import 'dart:convert';
import 'dart:math';

enum AssetKind { background, character, item, audio }

extension AssetKindX on AssetKind {
  String get label => switch (this) {
        AssetKind.background => '背景 / 图片',
        AssetKind.character => '角色立绘',
        AssetKind.item => '道具小图',
        AssetKind.audio => '音频',
      };

  bool get isImage => this != AssetKind.audio;
}

String newId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(900) + 100}';

class AssetRef {
  final String id;
  final AssetKind kind;
  final String fileName;
  final int bytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? label;

  const AssetRef({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.bytes,
    this.width,
    this.height,
    this.durationMs,
    this.label,
  });

  String get displayName {
    final l = label?.trim();
    if (l != null && l.isNotEmpty) return l;
    return fileName;
  }

  AssetRef copyWith({
    String? label,
    int? width,
    int? height,
    int? durationMs,
    int? bytes,
  }) =>
      AssetRef(
        id: id,
        kind: kind,
        fileName: fileName,
        bytes: bytes ?? this.bytes,
        width: width ?? this.width,
        height: height ?? this.height,
        durationMs: durationMs ?? this.durationMs,
        label: label ?? this.label,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'fileName': fileName,
        'bytes': bytes,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationMs != null) 'durationMs': durationMs,
        if (label != null && label!.isNotEmpty) 'label': label,
      };

  factory AssetRef.fromJson(Map<String, dynamic> j) => AssetRef(
        id: j['id'] as String,
        kind: AssetKind.values.firstWhere(
          (e) => e.name == j['kind'],
          orElse: () => AssetKind.background,
        ),
        fileName: (j['fileName'] as String?) ?? '',
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        durationMs: (j['durationMs'] as num?)?.toInt(),
        label: j['label'] as String?,
      );
}

/// 四个固定点位：0 最左、1 左、2 右、3 最右。
class StageSlot {
  String? assetId;
  bool visible;

  StageSlot({this.assetId, this.visible = true});

  bool get isEmpty => assetId == null || assetId!.isEmpty;

  StageSlot copy() => StageSlot(assetId: assetId, visible: visible);

  Map<String, dynamic> toJson() => {
        if (assetId != null) 'assetId': assetId,
        'visible': visible,
      };

  factory StageSlot.fromJson(Map<String, dynamic> j) => StageSlot(
        assetId: j['assetId'] as String?,
        visible: (j['visible'] as bool?) ?? true,
      );
}

class Choice {
  String text;
  String? target;

  Choice({this.text = '', this.target});

  Map<String, dynamic> toJson() => {
        'text': text,
        if (target != null && target!.isNotEmpty) 'target': target,
      };

  factory Choice.fromJson(Map<String, dynamic> j) => Choice(
        text: (j['text'] as String?) ?? '',
        target: j['target'] as String?,
      );
}

enum BgmAction { keep, play, stop }

extension BgmActionX on BgmAction {
  String get label => switch (this) {
        BgmAction.keep => '保持',
        BgmAction.play => '播放',
        BgmAction.stop => '停止',
      };
}

class VnNode {
  final String id;
  String title;
  String dialogue;

  /// null 表示沿用上一个节点的背景；首个节点请在编辑器里设置。
  String? backgroundId;

  /// 长度固定为 4，保存的是“绝对舞台状态”。
  final List<StageSlot> slots;

  /// 最多 4 个分支；文本为空的分支会被忽略。
  final List<Choice> choices;

  /// 没有分支时点击继续要去的节点；null 表示进入结局。
  String? next;

  BgmAction bgmAction;
  String? bgmId;
  String? sfxId;

  VnNode({
    required this.id,
    required this.title,
    this.dialogue = '',
    this.backgroundId,
    List<StageSlot>? slots,
    List<Choice>? choices,
    this.next,
    this.bgmAction = BgmAction.keep,
    this.bgmId,
    this.sfxId,
  })  : slots = slots ?? List.generate(4, (_) => StageSlot()),
        choices = choices ?? <Choice>[];

  bool get hasChoices => activeChoices.isNotEmpty;

  List<Choice> get activeChoices =>
      choices.where((c) => c.text.trim().isNotEmpty).toList();

  VnNode copyWith({
    String? title,
    String? dialogue,
    String? backgroundId,
    bool clearBackground = false,
    List<StageSlot>? slots,
    List<Choice>? choices,
    String? next,
    bool clearNext = false,
    BgmAction? bgmAction,
    String? bgmId,
    bool clearBgm = false,
    String? sfxId,
    bool clearSfx = false,
  }) =>
      VnNode(
        id: id,
        title: title ?? this.title,
        dialogue: dialogue ?? this.dialogue,
        backgroundId: clearBackground ? null : (backgroundId ?? this.backgroundId),
        slots: slots ?? this.slots.map((s) => s.copy()).toList(),
        choices: choices ?? this.choices.map((c) => Choice(text: c.text, target: c.target)).toList(),
        next: clearNext ? null : (next ?? this.next),
        bgmAction: bgmAction ?? this.bgmAction,
        bgmId: clearBgm ? null : (bgmId ?? this.bgmId),
        sfxId: clearSfx ? null : (sfxId ?? this.sfxId),
      );

  /// 新建节点时复制当前舞台，保证画面连续。
  VnNode copyStageAs(String newId, String newTitle) => VnNode(
        id: newId,
        title: newTitle,
        backgroundId: backgroundId,
        slots: slots.map((s) => s.copy()).toList(),
        bgmAction: BgmAction.keep,
        bgmId: bgmId,
        next: null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dialogue': dialogue,
        if (backgroundId != null) 'backgroundId': backgroundId,
        'slots': slots.map((s) => s.toJson()).toList(),
        'choices': choices.map((c) => c.toJson()).toList(),
        if (next != null) 'next': next,
        'bgmAction': bgmAction.name,
        if (bgmId != null) 'bgmId': bgmId,
        if (sfxId != null) 'sfxId': sfxId,
      };

  factory VnNode.fromJson(Map<String, dynamic> j) {
    final slots = <StageSlot>[];
    final rawSlots = (j['slots'] as List?) ?? const [];
    for (var i = 0; i < 4; i++) {
      if (i < rawSlots.length && rawSlots[i] is Map) {
        slots.add(StageSlot.fromJson(Map<String, dynamic>.from(rawSlots[i] as Map)));
      } else {
        slots.add(StageSlot());
      }
    }
    final choices = <Choice>[];
    for (final raw in (j['choices'] as List?) ?? const []) {
      if (raw is Map) choices.add(Choice.fromJson(Map<String, dynamic>.from(raw)));
    }
    return VnNode(
      id: (j['id'] as String?) ?? newId('n'),
      title: (j['title'] as String?) ?? '未命名',
      dialogue: (j['dialogue'] as String?) ?? '',
      backgroundId: j['backgroundId'] as String?,
      slots: slots,
      choices: choices,
      next: j['next'] as String?,
      bgmAction: BgmAction.values.firstWhere(
        (e) => e.name == j['bgmAction'],
        orElse: () => BgmAction.keep,
      ),
      bgmId: j['bgmId'] as String?,
      sfxId: j['sfxId'] as String?,
    );
  }
}

class EndingConfig {
  String? imageId;
  String? audioId;
  String text;

  EndingConfig({this.imageId, this.audioId, this.text = ''});

  Map<String, dynamic> toJson() => {
        if (imageId != null) 'imageId': imageId,
        if (audioId != null) 'audioId': audioId,
        'text': text,
      };

  factory EndingConfig.fromJson(Map<String, dynamic> j) => EndingConfig(
        imageId: j['imageId'] as String?,
        audioId: j['audioId'] as String?,
        text: (j['text'] as String?) ?? '',
      );
}

class VnProject {
  final String id;
  String title;
  String? coverId;
  String? openingBgmId;
  final List<VnNode> nodes;
  EndingConfig ending;
  final int createdAt;
  int updatedAt;

  /// 素材库：所有上传过的图片/音频，可被多个节点复用。
  final List<AssetRef> assets;

  VnProject({
    required this.id,
    required this.title,
    this.coverId,
    this.openingBgmId,
    required this.nodes,
    required this.ending,
    required this.createdAt,
    required this.updatedAt,
    required this.assets,
  });

  factory VnProject.fresh(String id, String title) {
    final node = VnNode(
      id: newId('n'),
      title: '开场',
      dialogue: '在这里输入第一句台词……',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    return VnProject(
      id: id,
      title: title,
      nodes: [node],
      ending: EndingConfig(text: '故事到这里就结束了。'),
      createdAt: now,
      updatedAt: now,
      assets: [],
    );
  }

  VnNode? node(String? id) {
    if (id == null) return null;
    final i = nodes.indexWhere((n) => n.id == id);
    return i < 0 ? null : nodes[i];
  }

  AssetRef? asset(String? id) {
    if (id == null) return null;
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  VnNode get startNode => nodes.isEmpty ? VnNode(id: 'missing', title: '空') : nodes.first;

  int indexOfNode(String? id) =>
      id == null ? -1 : nodes.indexWhere((n) => n.id == id);

  Set<String> referencedAssetIds() {
    final ids = <String>{};
    void add(String? id) {
      if (id != null && id.isNotEmpty) ids.add(id);
    }

    add(coverId);
    add(openingBgmId);
    add(ending.imageId);
    add(ending.audioId);
    for (final n in nodes) {
      add(n.backgroundId);
      add(n.bgmId);
      add(n.sfxId);
      for (final s in n.slots) {
        add(s.assetId);
      }
    }
    return ids;
  }

  /// 从素材库里移除某个素材，并清空所有指向它的引用。
  void removeAssetRefs(String assetId) {
    if (coverId == assetId) coverId = null;
    if (openingBgmId == assetId) openingBgmId = null;
    if (ending.imageId == assetId) ending.imageId = null;
    if (ending.audioId == assetId) ending.audioId = null;
    for (final n in nodes) {
      if (n.backgroundId == assetId) n.backgroundId = null;
      if (n.bgmId == assetId) {
        n.bgmId = null;
        n.bgmAction = BgmAction.keep;
      }
      if (n.sfxId == assetId) n.sfxId = null;
      for (final s in n.slots) {
        if (s.assetId == assetId) {
          s.assetId = null;
          s.visible = true;
        }
      }
    }
    assets.removeWhere((a) => a.id == assetId);
  }

  int get totalBytes => assets.fold(0, (sum, a) => sum + a.bytes);

  String toJsonString({bool pretty = true}) {
    final map = <String, dynamic>{
      'version': 1,
      'id': id,
      'title': title,
      if (coverId != null) 'coverId': coverId,
      if (openingBgmId != null) 'openingBgmId': openingBgmId,
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'ending': ending.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'assets': assets.map((a) => a.toJson()).toList(),
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  factory VnProject.fromJson(Map<String, dynamic> j) {
    final nodes = <VnNode>[];
    for (final raw in (j['nodes'] as List?) ?? const []) {
      if (raw is Map) nodes.add(VnNode.fromJson(Map<String, dynamic>.from(raw)));
    }
    if (nodes.isEmpty) {
      nodes.add(VnNode(id: newId('n'), title: '开场'));
    }
    final assets = <AssetRef>[];
    for (final raw in (j['assets'] as List?) ?? const []) {
      if (raw is Map) assets.add(AssetRef.fromJson(Map<String, dynamic>.from(raw)));
    }
    return VnProject(
      id: (j['id'] as String?) ?? newId('p'),
      title: (j['title'] as String?) ?? '未命名作品',
      coverId: j['coverId'] as String?,
      openingBgmId: j['openingBgmId'] as String?,
      nodes: nodes,
      ending: EndingConfig.fromJson(
        j['ending'] is Map ? Map<String, dynamic>.from(j['ending'] as Map) : const {},
      ),
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      assets: assets,
    );
  }

  factory VnProject.fromJsonString(String source) =>
      VnProject.fromJson(Map<String, dynamic>.from(jsonDecode(source) as Map));

  VnProject clone() => VnProject.fromJsonString(toJsonString(pretty: false));
}

class SaveState {
  final int slot;
  final String nodeId;
  final String? backgroundId;
  final List<StageSlot> slots;
  final String? bgmId;
  final String snippet;
  final int savedAt;
  final String thumbFile;

  SaveState({
    required this.slot,
    required this.nodeId,
    required this.backgroundId,
    required this.slots,
    required this.bgmId,
    required this.snippet,
    required this.savedAt,
    required this.thumbFile,
  });

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'nodeId': nodeId,
        if (backgroundId != null) 'backgroundId': backgroundId,
        'slots': slots.map((s) => s.toJson()).toList(),
        if (bgmId != null) 'bgmId': bgmId,
        'snippet': snippet,
        'savedAt': savedAt,
        'thumbFile': thumbFile,
      };

  factory SaveState.fromJson(Map<String, dynamic> j) {
    final slots = <StageSlot>[];
    for (final raw in (j['slots'] as List?) ?? const []) {
      if (raw is Map) slots.add(StageSlot.fromJson(Map<String, dynamic>.from(raw)));
    }
    while (slots.length < 4) {
      slots.add(StageSlot());
    }
    return SaveState(
      slot: (j['slot'] as num?)?.toInt() ?? 1,
      nodeId: (j['nodeId'] as String?) ?? '',
      backgroundId: j['backgroundId'] as String?,
      slots: slots,
      bgmId: j['bgmId'] as String?,
      snippet: (j['snippet'] as String?) ?? '',
      savedAt: (j['savedAt'] as num?)?.toInt() ?? 0,
      thumbFile: (j['thumbFile'] as String?) ?? '',
    );
  }
}
