import 'dart:typed_data';

import '../models/models.dart';

/// 在线素材能力的预留接口。
///
/// 星绘工坊当前是完全离线的：素材只从本机相册/文件选择，工程也只写在
/// App 私有目录。以后接网时，只需要实现 [AssetHub] 并把实例交给
/// [AssetHubConfig.install]，编辑器里的“选择素材”入口就可以多一个
/// “在线素材”来源，而播放器、存档和本地工程格式都不需要改。
///
/// 约定：
/// - 下载得到的字节仍然交给 `ProjectStore.storeAsset` 落盘并生成
///   `AssetRef`，工程只引用本机文件，断网也能继续玩；
/// - [RemoteAsset.downloadUrl] 可以是完整 URL，也可以由实现自行拼接；
/// - 鉴权、缓存、重试由具体实现负责，不要写进 UI。
abstract class AssetHub {
  /// 是否已连上在线服务。离线实现返回 false。
  bool get isOnline;

  /// 浏览/搜索在线素材。分页从 0 开始。
  Future<RemoteAssetPage> browse({
    AssetKind? kind,
    String query = '',
    int page = 0,
    int pageSize = 24,
  });

  /// 下载素材原始字节（图片或音频）。
  Future<Uint8List> download(RemoteAsset asset);

  /// 把自己的素材发布到在线素材库（可选能力，未开放时可抛异常）。
  Future<RemoteAsset> publish(RemoteUpload upload);
}

/// 在线素材条目。字段刻意与本地 [AssetRef] 对齐，方便转换。
class RemoteAsset {
  const RemoteAsset({
    required this.id,
    required this.title,
    required this.kind,
    required this.downloadUrl,
    this.author = '',
    this.ext = '',
    this.previewUrl,
    this.description,
    this.license,
    this.width,
    this.height,
    this.durationMs,
  });

  final String id;
  final String title;
  final AssetKind kind;
  final String downloadUrl;
  final String author;
  final String ext;
  final String? previewUrl;
  final String? description;
  final String? license;
  final int? width;
  final int? height;
  final int? durationMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'downloadUrl': downloadUrl,
        'author': author,
        'ext': ext,
        if (previewUrl != null) 'previewUrl': previewUrl,
        if (description != null) 'description': description,
        if (license != null) 'license': license,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory RemoteAsset.fromJson(Map<String, dynamic> j) => RemoteAsset(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        kind: AssetKind.values.firstWhere(
          (e) => e.name == j['kind'],
          orElse: () => AssetKind.background,
        ),
        downloadUrl: (j['downloadUrl'] ?? '').toString(),
        author: (j['author'] ?? '').toString(),
        ext: (j['ext'] ?? '').toString(),
        previewUrl: j['previewUrl'] as String?,
        description: j['description'] as String?,
        license: j['license'] as String?,
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        durationMs: (j['durationMs'] as num?)?.toInt(),
      );
}

class RemoteAssetPage {
  const RemoteAssetPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<RemoteAsset> items;
  final int page;
  final bool hasMore;

  static const empty = RemoteAssetPage(items: [], page: 0, hasMore: false);
}

/// 发布素材时提交的元数据。
class RemoteUpload {
  const RemoteUpload({
    required this.title,
    required this.kind,
    required this.bytes,
    required this.ext,
    this.description = '',
    this.author = '',
    this.license = '',
  });

  final String title;
  final AssetKind kind;
  final Uint8List bytes;
  final String ext;
  final String description;
  final String author;
  final String license;
}

class AssetHubException implements Exception {
  AssetHubException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 当前版本使用的离线实现：所有在线能力都明确报错，避免 UI 静默失败。
class OfflineAssetHub implements AssetHub {
  const OfflineAssetHub();

  @override
  bool get isOnline => false;

  @override
  Future<RemoteAssetPage> browse({
    AssetKind? kind,
    String query = '',
    int page = 0,
    int pageSize = 24,
  }) async {
    throw AssetHubException('当前版本为离线版，在线素材功能尚未开放。');
  }

  @override
  Future<Uint8List> download(RemoteAsset asset) async {
    throw AssetHubException('当前版本为离线版，无法下载在线素材。');
  }

  @override
  Future<RemoteAsset> publish(RemoteUpload upload) async {
    throw AssetHubException('当前版本为离线版，暂不支持向他人提供素材。');
  }
}

/// 全局入口。以后接入服务端时，在 App 启动阶段调用一次 [install] 即可。
class AssetHubConfig {
  AssetHubConfig._();

  static AssetHub instance = const OfflineAssetHub();
  static String? baseUrl;

  static bool get isOnline => instance.isOnline;

  static void install(AssetHub hub, {String? baseUrl}) {
    instance = hub;
    AssetHubConfig.baseUrl = baseUrl;
  }
}
