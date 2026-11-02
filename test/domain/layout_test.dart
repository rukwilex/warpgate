import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/features/workspace/domain/layout.dart';

void main() {
  var counter = 0;
  String nextId() => 's${counter++}';

  group('Layouts', () {
    test('split builds a binary tree around the target pane', () {
      var root = Layouts.split(
        null,
        null,
        'a',
        SplitAxis.horizontal,
        splitId: nextId(),
      );
      root = Layouts.split(
        root,
        'a',
        'b',
        SplitAxis.horizontal,
        splitId: nextId(),
      );
      root = Layouts.split(
        root,
        'b',
        'c',
        SplitAxis.vertical,
        splitId: nextId(),
      );
      expect(Layouts.leaves(root), ['a', 'b', 'c']);
      final split = root as SplitNode;
      expect(split.axis, SplitAxis.horizontal);
      expect((split.second as SplitNode).axis, SplitAxis.vertical);
    });

    test('remove collapses the parent split', () {
      var root = Layouts.split(
        const LeafNode('a'),
        'a',
        'b',
        SplitAxis.horizontal,
        splitId: nextId(),
      );
      root = Layouts.split(
        root,
        'b',
        'c',
        SplitAxis.vertical,
        splitId: nextId(),
      );
      final removed = Layouts.remove(root, 'b');
      expect(Layouts.leaves(removed), ['a', 'c']);
      expect(Layouts.remove(const LeafNode('a'), 'a'), isNull);
    });

    test('swap exchanges leaves without changing structure', () {
      final root = Layouts.split(
        const LeafNode('a'),
        'a',
        'b',
        SplitAxis.horizontal,
        splitId: 'x',
      );
      expect(Layouts.leaves(Layouts.swap(root, 'a', 'b')), ['b', 'a']);
    });

    test('neighbor finds the pane in each direction', () {
      final root = Layouts.preset(LayoutPresetKind.grid, [
        'a',
        'b',
        'c',
        'd',
      ], nextId);
      expect(Layouts.neighbor(root, 'a', PaneDirection.right), 'b');
      expect(Layouts.neighbor(root, 'a', PaneDirection.down), 'c');
      expect(Layouts.neighbor(root, 'd', PaneDirection.up), 'b');
      expect(Layouts.neighbor(root, 'd', PaneDirection.left), 'c');
      expect(Layouts.neighbor(root, 'a', PaneDirection.left), isNull);
    });

    test('resize moves the nearest matching divider and clamps', () {
      final root = Layouts.split(
        const LeafNode('a'),
        'a',
        'b',
        SplitAxis.horizontal,
        splitId: 'x',
      );
      final grown =
          Layouts.resize(root, 'a', PaneDirection.right, 0.1)! as SplitNode;
      expect(grown.ratio, closeTo(0.6, 1e-9));
      var shrunk = root;
      for (var i = 0; i < 20; i++) {
        shrunk = Layouts.resize(shrunk, 'a', PaneDirection.left, 0.1)!;
      }
      expect((shrunk as SplitNode).ratio, Layouts.minRatio);
      expect(Layouts.resize(root, 'a', PaneDirection.down, 0.1), root);
    });

    test('presets place every pane', () {
      for (final kind in LayoutPresetKind.values) {
        final root = Layouts.preset(kind, ['a', 'b', 'c', 'd', 'e'], nextId);
        expect(Layouts.leaves(root).toSet(), {
          'a',
          'b',
          'c',
          'd',
          'e',
        }, reason: kind.name);
      }
      final main =
          Layouts.preset(LayoutPresetKind.mainStack, ['a', 'b', 'c'], nextId)!
              as SplitNode;
      expect(main.first, const LeafNode('a'));
    });

    test('rects cover the unit square', () {
      final root = Layouts.preset(LayoutPresetKind.grid, [
        'a',
        'b',
        'c',
        'd',
      ], nextId);
      final area = Layouts.rects(root).values
          .fold<double>(0, (sum, rect) => sum + rect.width * rect.height);
      expect(area, closeTo(1, 1e-9));
    });

    test('json round trip keeps the tree', () {
      final root = Layouts.preset(LayoutPresetKind.mainStack, [
        'a',
        'b',
        'c',
      ], nextId)!;
      expect(LayoutNode.fromJson(root.toJson()), root);
    });
  });
}
