import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:warpgate/core/data/app_database.dart';

enum SplitAxis { horizontal, vertical }

enum PaneDirection { left, right, up, down }

sealed class LayoutNode {
  const new();

  factory fromJson(JsonMap json) => switch (json['type']) {
    'split' => SplitNode(
      id: json['id']! as String,
      axis: SplitAxis.values.byName(json['axis']! as String),
      first: LayoutNode.fromJson((json['first']! as Map).cast()),
      second: LayoutNode.fromJson((json['second']! as Map).cast()),
      ratio: (json['ratio']! as num).toDouble(),
    ),
    _ => LeafNode(json['paneId']! as String),
  };

  JsonMap toJson();
}

@immutable
class LeafNode extends LayoutNode {
  const new(this.paneId);

  final String paneId;

  @override
  JsonMap toJson() => {'type': 'leaf', 'paneId': paneId};

  @override
  bool operator ==(Object other) => other is LeafNode && other.paneId == paneId;

  @override
  int get hashCode => paneId.hashCode;
}

@immutable
class SplitNode extends LayoutNode {
  const new({
    required this.id,
    required this.axis,
    required this.first,
    required this.second,
    this.ratio = 0.5,
  });

  final String id;
  final SplitAxis axis;
  final LayoutNode first;
  final LayoutNode second;
  final double ratio;

  SplitNode copyWith({LayoutNode? first, LayoutNode? second, double? ratio}) =>
      SplitNode(
        id: id,
        axis: axis,
        first: first ?? this.first,
        second: second ?? this.second,
        ratio: ratio ?? this.ratio,
      );

  @override
  JsonMap toJson() => {
    'type': 'split',
    'id': id,
    'axis': axis.name,
    'first': first.toJson(),
    'second': second.toJson(),
    'ratio': ratio,
  };

  @override
  bool operator ==(Object other) =>
      other is SplitNode &&
      other.id == id &&
      other.axis == axis &&
      other.first == first &&
      other.second == second &&
      other.ratio == ratio;

  @override
  int get hashCode => Object.hash(id, axis, first, second, ratio);
}

enum LayoutPresetKind {
  columns('Two columns'),
  grid('2 × 2 grid'),
  mainStack('Main and side stack'),
  rows('Two rows');

  new(this.label);

  final String label;
}

abstract final class Layouts {
  static const minRatio = 0.1;
  static const maxRatio = 0.9;

  static List<String> leaves(LayoutNode? node) => switch (node) {
    null => const [],
    LeafNode(:final paneId) => [paneId],
    SplitNode(:final first, :final second) => [
      ...leaves(first),
      ...leaves(second),
    ],
  };

  static bool contains(LayoutNode? node, String paneId) =>
      leaves(node).contains(paneId);

  static LayoutNode split(
    LayoutNode? root,
    String? targetPaneId,
    String newPaneId,
    SplitAxis axis, {
    required String splitId,
    bool before = false,
  }) {
    final fresh = LeafNode(newPaneId);
    if (root == null) return fresh;
    if (targetPaneId == null || !contains(root, targetPaneId)) {
      return SplitNode(
        id: splitId,
        axis: axis,
        first: before ? fresh : root,
        second: before ? root : fresh,
      );
    }
    LayoutNode visit(LayoutNode node) => switch (node) {
      LeafNode(:final paneId) when paneId == targetPaneId => SplitNode(
        id: splitId,
        axis: axis,
        first: before ? fresh : node,
        second: before ? node : fresh,
      ),
      LeafNode() => node,
      SplitNode() => node.copyWith(
        first: visit(node.first),
        second: visit(node.second),
      ),
    };
    return visit(root);
  }

  static LayoutNode? remove(LayoutNode? root, String paneId) {
    LayoutNode? visit(LayoutNode node) {
      switch (node) {
        case LeafNode(paneId: final id):
          return id == paneId ? null : node;
        case SplitNode():
          final first = visit(node.first);
          final second = visit(node.second);
          if (first == null) return second;
          if (second == null) return first;
          return node.copyWith(first: first, second: second);
      }
    }

    return root == null ? null : visit(root);
  }

  static LayoutNode? swap(LayoutNode? root, String a, String b) {
    if (root == null || a == b) return root;
    LayoutNode visit(LayoutNode node) => switch (node) {
      LeafNode(:final paneId) when paneId == a => LeafNode(b),
      LeafNode(:final paneId) when paneId == b => LeafNode(a),
      LeafNode() => node,
      SplitNode() => node.copyWith(
        first: visit(node.first),
        second: visit(node.second),
      ),
    };
    return visit(root);
  }

  static LayoutNode? setRatio(LayoutNode? root, String splitId, double ratio) {
    if (root == null) return null;
    final clamped = ratio.clamp(minRatio, maxRatio);
    LayoutNode visit(LayoutNode node) => switch (node) {
      LeafNode() => node,
      SplitNode(:final id) when id == splitId => node.copyWith(ratio: clamped),
      SplitNode() => node.copyWith(
        first: visit(node.first),
        second: visit(node.second),
      ),
    };
    return visit(root);
  }

  static Map<String, Rect> rects(
    LayoutNode? root, [
    Rect bounds = const Rect.fromLTWH(0, 0, 1, 1),
  ]) {
    final result = <String, Rect>{};
    void visit(LayoutNode node, Rect area) {
      switch (node) {
        case LeafNode(:final paneId):
          result[paneId] = area;
        case SplitNode(:final axis, :final ratio, :final first, :final second):
          if (axis == SplitAxis.horizontal) {
            final width = area.width * ratio;
            visit(
              first,
              Rect.fromLTWH(area.left, area.top, width, area.height),
            );
            visit(
              second,
              Rect.fromLTWH(
                area.left + width,
                area.top,
                area.width - width,
                area.height,
              ),
            );
          } else {
            final height = area.height * ratio;
            visit(
              first,
              Rect.fromLTWH(area.left, area.top, area.width, height),
            );
            visit(
              second,
              Rect.fromLTWH(
                area.left,
                area.top + height,
                area.width,
                area.height - height,
              ),
            );
          }
      }
    }

    if (root != null) visit(root, bounds);
    return result;
  }

  static String? neighbor(
    LayoutNode? root,
    String paneId,
    PaneDirection direction,
  ) {
    final all = rects(root);
    final origin = all[paneId];
    if (origin == null) return null;
    const epsilon = 1e-6;
    String? best;
    var bestScore = double.infinity;
    for (final MapEntry(key: id, value: rect) in all.entries) {
      if (id == paneId) continue;
      final (ahead, gap, overlap) = switch (direction) {
        PaneDirection.left => (
          rect.right <= origin.left + epsilon,
          origin.left - rect.right,
          _overlap(rect.top, rect.bottom, origin.top, origin.bottom),
        ),
        PaneDirection.right => (
          rect.left >= origin.right - epsilon,
          rect.left - origin.right,
          _overlap(rect.top, rect.bottom, origin.top, origin.bottom),
        ),
        PaneDirection.up => (
          rect.bottom <= origin.top + epsilon,
          origin.top - rect.bottom,
          _overlap(rect.left, rect.right, origin.left, origin.right),
        ),
        PaneDirection.down => (
          rect.top >= origin.bottom - epsilon,
          rect.top - origin.bottom,
          _overlap(rect.left, rect.right, origin.left, origin.right),
        ),
      };
      if (!ahead || overlap <= epsilon) continue;
      final score = gap * 10 - overlap;
      if (score < bestScore) {
        bestScore = score;
        best = id;
      }
    }
    return best;
  }

  static double _overlap(double a1, double a2, double b1, double b2) =>
      math.max(0, math.min(a2, b2) - math.max(a1, b1));

  static LayoutNode? resize(
    LayoutNode? root,
    String paneId,
    PaneDirection direction,
    double step,
  ) {
    if (root == null) return null;
    final axis =
        direction == PaneDirection.left || direction == PaneDirection.right
        ? SplitAxis.horizontal
        : SplitAxis.vertical;
    final grow =
        direction == PaneDirection.right || direction == PaneDirection.down;
    String? targetSplit;
    double? targetRatio;
    void visit(LayoutNode node) {
      if (node is! SplitNode) return;
      final inFirst = contains(node.first, paneId);
      final inSecond = contains(node.second, paneId);
      if (!inFirst && !inSecond) return;
      if (node.axis == axis) {
        targetSplit = node.id;
        targetRatio = node.ratio + (grow ? step : -step);
      }
      visit(inFirst ? node.first : node.second);
    }

    visit(root);
    if (targetSplit == null) return root;
    return setRatio(root, targetSplit!, targetRatio!);
  }

  static LayoutNode? preset(
    LayoutPresetKind kind,
    List<String> paneIds,
    String Function() nextId,
  ) {
    if (paneIds.isEmpty) return null;
    LayoutNode chain(List<String> ids, SplitAxis axis) {
      if (ids.length == 1) return LeafNode(ids.first);
      return SplitNode(
        id: nextId(),
        axis: axis,
        first: LeafNode(ids.first),
        second: chain(ids.sublist(1), axis),
        ratio: 1 / ids.length,
      );
    }

    switch (kind) {
      case LayoutPresetKind.columns:
        return chain(paneIds, SplitAxis.horizontal);
      case LayoutPresetKind.rows:
        return chain(paneIds, SplitAxis.vertical);
      case LayoutPresetKind.mainStack:
        if (paneIds.length == 1) return LeafNode(paneIds.first);
        return SplitNode(
          id: nextId(),
          axis: SplitAxis.horizontal,
          ratio: 0.62,
          first: LeafNode(paneIds.first),
          second: chain(paneIds.sublist(1), SplitAxis.vertical),
        );
      case LayoutPresetKind.grid:
        if (paneIds.length < 3) return chain(paneIds, SplitAxis.horizontal);
        final columns = math.sqrt(paneIds.length).ceil();
        final rows = <List<String>>[];
        for (var i = 0; i < paneIds.length; i += columns) {
          rows.add(paneIds.sublist(i, math.min(i + columns, paneIds.length)));
        }
        LayoutNode stack(List<List<String>> remaining) {
          final row = chain(remaining.first, SplitAxis.horizontal);
          if (remaining.length == 1) return row;
          return SplitNode(
            id: nextId(),
            axis: SplitAxis.vertical,
            ratio: 1 / remaining.length,
            first: row,
            second: stack(remaining.sublist(1)),
          );
        }

        return stack(rows);
    }
  }

  static LayoutNode remap(
    LayoutNode node,
    String Function(String paneId) paneId,
    String Function() splitId,
  ) => switch (node) {
    LeafNode(paneId: final id) => LeafNode(paneId(id)),
    SplitNode() => SplitNode(
      id: splitId(),
      axis: node.axis,
      ratio: node.ratio,
      first: remap(node.first, paneId, splitId),
      second: remap(node.second, paneId, splitId),
    ),
  };
}
