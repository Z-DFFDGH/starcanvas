import 'package:flutter_test/flutter_test.dart';
import 'package:starcanvas/models/models.dart';

void main() {
  group('模型序列化', () {
    test('VnNode 往返保留四点位、显隐与分支', () {
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
      node.slots[3] = StageSlot(assetId: 'item1');
      node.choices.add(Choice(text: '去左边', target: 'n2'));
      node.choices.add(Choice(text: '去右边', target: 'n3'));

      final back = VnNode.fromJson(node.toJson());

      expect(back.id, 'n1');
      expect(back.title, '开场');
      expect(back.dialogue, '你好，星绘工坊。');
      expect(back.backgroundId, 'bg1');
      expect(back.slots.length, 4);
      expect(back.slots[0].assetId, 'char1');
      expect(back.slots[0].visible, isFalse);
      expect(back.slots[3].assetId, 'item1');
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

    test('Slot 数量不足时补足 4 个', () {
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
      expect(back.slots.length, 4);
      expect(back.slots[0].assetId, 'a');
      expect(back.slots[1].assetId, isNull);
    });

    test('SaveState 往返', () {
      final state = SaveState(
        slot: 3,
        nodeId: 'n9',
        backgroundId: 'bg2',
        slots: [
          StageSlot(assetId: 'c1'),
          StageSlot(),
          StageSlot(assetId: 'i1', visible: false),
          StageSlot(),
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
      expect(back.slots[2].assetId, 'i1');
      expect(back.slots[2].visible, isFalse);
      expect(back.bgmId, 'bgm2');
      expect(back.snippet, '海风吹过……');
      expect(back.savedAt, 1700000000000);
      expect(back.thumbFile, 'slot_3.png');
    });

    test('referencedAssetIds 覆盖封面、开场、节点、结局', () {
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
      node.slots[1] = StageSlot(assetId: 'item');
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
