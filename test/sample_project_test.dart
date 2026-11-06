import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:starcanvas/data/app_paths.dart';
import 'package:starcanvas/models/models.dart';
import 'package:starcanvas/services/sample_project.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  group('示例工程', () {
    late VnProject project;
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('starcanvas_test_');
      PathProviderPlatform.instance = _FakePathProvider(temp.path);
      await AppPaths.init();
      project = await SampleProject.create();
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('有完整节点与素材', () {
      expect(project.title.isNotEmpty, isTrue);
      expect(project.nodes.length, greaterThanOrEqualTo(4));
      expect(project.assets, isNotEmpty);
      expect(project.ending.text.isNotEmpty, isTrue);
    });

    test('所有跳转目标都存在，没有断链', () {
      for (final node in project.nodes) {
        if (node.next != null) {
          expect(project.node(node.next), isNotNull,
              reason: '节点「${node.title}」的继续目标不存在');
        }
        for (final choice in node.activeChoices) {
          if (choice.target != null && choice.target!.isNotEmpty) {
            expect(project.node(choice.target), isNotNull,
                reason: '节点「${node.title}」的选项目标不存在');
          }
        }
      }
    });

    test('所有引用的素材都在资源库里，且文件字节非空', () {
      final refs = project.referencedAssetIds();
      for (final asset in project.assets) {
        expect(refs.contains(asset.id), isTrue,
            reason: '素材 ${asset.id} 没有被任何地方引用');
        expect(asset.bytes, greaterThan(0));
        expect(asset.fileName.isNotEmpty, isTrue);
        if (asset.kind == AssetKind.background) {
          expect(asset.width, 1280);
          expect(asset.height, 720);
        }
      }
    });

    test('每个节点 5 个角色点位、道具位置合法、最多 4 个有效分支', () {
      for (final node in project.nodes) {
        expect(node.slots.length, 5);
        for (final prop in node.props) {
          expect(prop.position, inInclusiveRange(0, 4));
          expect(project.asset(prop.assetId)?.kind, AssetKind.item);
        }
        expect(node.activeChoices.length, lessThanOrEqualTo(4));
      }
    });
  });
}
