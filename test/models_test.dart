import 'package:flutter_test/flutter_test.dart';
import 'package:starcanvas/models/models.dart';

AssetRef _asset(String id, AssetKind kind) =>
    AssetRef(id: id, kind: kind, fileName: '$id.png', bytes: 10);

void main() {
  group('模型序列化', () {
    test('VnNode 往返保留五点位、独立道具、显隐与分支', () {
      final node = VnNode(
        id: 'n1',
        title: '开场',
        dialogue: '你好，星绘工坊。',
        backgroundId: 'bg1',
        bgmAction: BgmAction.play,
        bgmId: 'bgm1',
        sfxId: 'sfx1',
        next: 'n2',
      );
      node.slots[0] = StageSlot(assetId: 'char1', visible: false);
      node.slots[2] = StageSlot(assetId: 'char2');
      node.props.add(PropSlot(assetId: 'item1', position: 0));
      node.props.add(PropSlot(assetId: 'item2', position: 4, visible: false));
      node.choices.add(Choice(text: '去左边', target: 'n2'));
      node.choices.add(Choice(text: '去右边', target: 'n3'));

      final back = VnNode.fromJson(node.toJson());

      expect(back.id, 'n1');
      expect(back.title, '开场');
      expect(back.dialogue, '你好，星绘工坊。');
      expect(back.backgroundId, 'bg1');
      expect(back.slots.length, 5);
      expect(back.slots[0].assetId, 'char1');
      expect(back.slots[0].visible, isFalse);
      expect(back.slots[2].assetId, 'char2');
      expect(back.props.length, 2);
      expect(back.props[0].assetId, 'item1');
      expect(back.props[0].position, 0);
      expect(back.props[1].position, 4);
      expect(back.props[1].visible, isFalse);
      expect(back.activeChoices.length, 2);
      expect(back.activeChoices[1].target, 'n3');
      expect(back.bgmAction, BgmAction.play);
      expect(back.bgmId, 'bgm1');
      expect(back.sfxId, 'sfx1');
      expect(back.next, 'n2');
    });

    test('空分支文本会被忽略', () {
      final node = VnNode(id: 'n', title: 't');
      node.choices.add(Choice(text: '   ', target: 'n2'));
      node.choices.add(Choice(text: '真的选项', target: 'n3'));
      expect(node.hasChoices, isTrue);
      expect(node.activeChoices.length, 1);
      expect(node.activeChoices.single.text, '真的选项');
    });

    test('Slot 数量不足时补足 5 个', () {
      final back = VnNode.fromJson({
        'id': 'x',
        'title': 'x',
        'dialogue': '',
        'slots': [
          {'assetId': 'a'},
        ],
        'choices': <dynamic>[],
        'bgmAction': 'keep',
      });
      expect(back.slots.length, 5);
      expect(back.slots[0].assetId, 'a');
      expect(back.slots[1].assetId, isNull);
    });

    test('旧版四点位自动升级：右侧角色留在右边，道具迁到独立列表', () {
      final legacy = <String, dynamic>{
        'id': 'p-old',
        'title': '旧工程',
        'nodes': [
          {
            'id': 'n1',
            'title': '旧节点',
            'dialogue': '',
            'slots': [
              {'assetId': 'c1'},
              {'assetId': 'c2'},
              {'assetId': 'i1'},
              {'assetId': 'c3'},
            ],
          },
        ],
        'assets': [
          _asset('c1', AssetKind.character).toJson(),
          _asset('c2', AssetKind.character).toJson(),
          _asset('c3', AssetKind.character).toJson(),
          _asset('i1', AssetKind.item).toJson(),
        ],
        'ending': <String, dynamic>{},
      };

      final project = VnProject.fromJson(legacy);
      final node = project.nodes.single;

      expect(node.slots.length, 5);
      expect(node.slots[0].assetId, 'c1');
      expect(node.slots[1].assetId, 'c2');
      expect(node.slots[2].assetId, isNull, reason: '中间是新加的空位');
      expect(node.slots[3].assetId, isNull, reason: '旧右点位上的道具已迁走');
      expect(node.slots[4].assetId, 'c3', reason: '旧最右点位应落在新最右点位');
      expect(node.props.length, 1);
      expect(node.props.single.assetId, 'i1');
      expect(node.props.single.position, 3, reason: '旧右点位上的道具保留原位置');
      expect(project.referencedAssetIds().contains('i1'), isTrue);
    });

    test('SaveState 往返保留五点位、独立道具和 BGM', () {
      final state = SaveState(
        slot: 3,
        nodeId: 'n9',
        backgroundId: 'bg2',
        slots: [
          StageSlot(assetId: 'c1'),
          StageSlot(),
          StageSlot(assetId: 'c2', visible: false),
          StageSlot(),
          StageSlot(),
        ],
        props: [
          PropSlot(assetId: 'i1', visible: false, position: 3),
        ],
        bgmId: 'bgm2',
        snippet: '海风吹过……',
        savedAt: 1700000000000,
        thumbFile: 'slot_3.png',
      );
      final back = SaveState.fromJson(state.toJson());
      expect(back.slot, 3);
      expect(back.nodeId, 'n9');
      expect(back.backgroundId, 'bg2');
      expect(back.slots.length, 5);
      expect(back.slots[2].assetId, 'c2');
      expect(back.slots[2].visible, isFalse);
      expect(back.props.single.assetId, 'i1');
      expect(back.props.single.position, 3);
      expect(back.props.single.visible, isFalse);
      expect(back.bgmId, 'bgm2');
      expect(back.snippet, '海风吹过……');
      expect(back.savedAt, 1700000000000);
      expect(back.thumbFile, 'slot_3.png');
    });

    test('自动跳转时间可序列化', () {
      final project = VnProject.fresh('p1', '自动播放');
      project.autoAdvanceMs = 2500;
      final back = VnProject.fromJsonString(project.toJsonString());
      expect(back.autoAdvanceMs, 2500);

      final old = VnProject.fromJson({
        'id': 'p2',
        'title': '旧工程',
        'nodes': <dynamic>[],
        'assets': <dynamic>[],
        'ending': <String, dynamic>{},
      });
      expect(old.autoAdvanceMs, 0);
    });

    test('referencedAssetIds 覆盖封面、开场、节点、道具、结局', () {
      final node = VnNode(
        id: 'n1',
        title: '开场',
        backgroundId: 'bg',
        bgmAction: BgmAction.play,
        bgmId: 'bgm',
        sfxId: 'sfx',
        next: null,
      );
      node.slots[0] = StageSlot(assetId: 'char');
      node.props.add(PropSlot(assetId: 'item'));
      final project = VnProject(
        id: 'p1',
        title: '测试',
        coverId: 'cover',
        openingBgmId: 'open',
        nodes: [node],
        ending: EndingConfig(imageId: 'endImg', audioId: 'endAudio'),
        createdAt: 1,
        updatedAt: 1,
        assets: const [],
      );

      final refs = project.referencedAssetIds();
      for (final id in [
        'cover',
        'open',
        'bg',
        'bgm',
        'sfx',
        'char',
        'item',
        'endImg',
        'endAudio',
      ]) {
        expect(refs.contains(id), isTrue, reason: '应该引用 $id');
      }
    });

    test('clone 是深拷贝，改副本不影响原工程', () {
      final project = VnProject.fresh('p1', '原工程');
      final copy = project.clone();
      copy.title = '副本';
      copy.nodes.first.title = '被改掉的开场';
      copy.nodes.first.slots[0].assetId = 'x';

      expect(project.title, '原工程');
      expect(project.nodes.first.title, '开场');
      expect(project.nodes.first.slots[0].assetId, isNull);
    });
  });
}
