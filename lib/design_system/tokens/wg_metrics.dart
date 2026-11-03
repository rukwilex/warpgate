import 'package:flutter/material.dart';
import 'package:warpgate_core/features/settings/domain/appearance.dart';

export 'package:warpgate_core/features/settings/domain/appearance.dart' show WgDensity;

@immutable
class WgSpace extends ThemeExtension<WgSpace> {
  const new({
    this.hair = 2,
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 20,
    this.xxl = 24,
    this.xxxl = 32,
    this.huge = 48,
  });

  final double hair;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double huge;

  @override
  WgSpace copyWith() => this;

  @override
  WgSpace lerp(WgSpace? other, double t) => other ?? this;
}

@immutable
class WgRadii extends ThemeExtension<WgRadii> {
  const new({
    this.xs = 4,
    this.sm = 6,
    this.md = 8,
    this.lg = 12,
    this.xl = 16,
    this.round = 999,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double round;

  BorderRadius get xsAll => BorderRadius.circular(xs);
  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get xlAll => BorderRadius.circular(xl);

  @override
  WgRadii copyWith() => this;

  @override
  WgRadii lerp(WgRadii? other, double t) => other ?? this;
}

@immutable
class WgSizes extends ThemeExtension<WgSizes> {
  const new({
    required this.row,
    required this.control,
    this.touch = false,
    this.icon = 16,
    this.iconLarge = 24,
    this.dot = 8,
    this.hairline = 1,
    this.focusRing = 2,
    this.rowCompact = 32,
    this.touchTarget = 44,
    this.tabBar = 36,
    this.statusBar = 28,
    this.rail = 52,
    this.sidebar = 264,
    this.splitterHit = 8,
    this.paneMin = 120,
    this.keycap = 18,
    this.keyRow = 44,
    this.palette = 600,
    this.dialog = 440,
    this.dialogWide = 640,
    this.sheetMax = 720,
    this.readable = 640,
    this.tabMax = 220,
    this.tabMin = 120,
    this.gridTile = 112,
    this.progressBar = 4,
    this.markerBar = 2,
    this.contentMax = 1200,
    this.stroke = 1.5,
    this.listMax = 448,
    this.paletteTop = 96,
    this.fieldShort = 132,
    this.metaColumn = 72,
    this.keyRecorder = 72,
    this.lockPanel = 330,
    this.previewMax = 220,
    this.resultCard = 396,
    this.titleBar = 40,
    this.captionButton = 46,
    this.captionGlyph = 10,
    this.trafficLights = 80,
    this.emptyText = 400,
    this.columnName = 200,
    this.columnMin = 56,
    this.columnSize = 88,
    this.columnModified = 136,
    this.columnPermissions = 104,
    this.columnOwner = 96,
    this.treeWidth = 220,
    this.treeIndent = 14,
    this.dragLabel = 300,
    this.filesPanelMin = 240,
    this.terminalMin = 160,
    this.terminalPadding = 6,
    this.completionList = 240,
    this.logoMark = 18,
    this.logoLarge = 40,
  });

  factory forDensity(WgDensity density, {required bool touch}) {
    if (touch) return const WgSizes(row: 44, control: 44, touch: true);
    return switch (density) {
      WgDensity.compact => const WgSizes(row: 32, control: 32, titleBar: 36),
      WgDensity.comfortable => const WgSizes(row: 36, control: 36),
    };
  }

  final double row;
  final double control;
  final bool touch;
  final double icon;
  final double iconLarge;
  final double dot;
  final double hairline;
  final double focusRing;
  final double rowCompact;
  final double touchTarget;
  final double tabBar;
  final double statusBar;
  final double rail;
  final double sidebar;
  final double splitterHit;
  final double paneMin;
  final double keycap;
  final double keyRow;
  final double palette;
  final double dialog;
  final double dialogWide;
  final double sheetMax;
  final double readable;
  final double tabMax;
  final double tabMin;
  final double gridTile;
  final double progressBar;
  final double markerBar;
  final double contentMax;
  final double stroke;
  final double listMax;
  final double paletteTop;
  final double fieldShort;
  final double metaColumn;
  final double keyRecorder;
  final double lockPanel;
  final double previewMax;
  final double resultCard;
  final double titleBar;
  final double captionButton;
  final double captionGlyph;
  final double trafficLights;
  final double emptyText;
  final double columnName;
  final double columnMin;
  final double columnSize;
  final double columnModified;
  final double columnPermissions;
  final double columnOwner;
  final double treeWidth;
  final double treeIndent;
  final double dragLabel;
  final double filesPanelMin;
  final double terminalMin;
  final double terminalPadding;
  final double completionList;
  final double logoMark;
  final double logoLarge;

  @override
  WgSizes copyWith() => this;

  @override
  WgSizes lerp(WgSizes? other, double t) => other ?? this;
}

@immutable
class WgMotion extends ThemeExtension<WgMotion> {
  const new({
    this.fast = const Duration(milliseconds: 140),
    this.medium = const Duration(milliseconds: 200),
    this.slow = const Duration(milliseconds: 360),
    this.tooltipWait = const Duration(milliseconds: 500),
    this.live = const Duration(milliseconds: 1200),
    this.resizeThrottle = const Duration(milliseconds: 80),
    this.hoverSwitch = const Duration(milliseconds: 600),
    this.typeAhead = const Duration(milliseconds: 900),
    this.cwdPoll = const Duration(milliseconds: 1500),
    this.curve = const Cubic(0.22, 1, 0.36, 1),
  });

  final Duration fast;
  final Duration medium;
  final Duration slow;
  final Duration tooltipWait;
  final Duration live;
  final Duration resizeThrottle;
  final Duration hoverSwitch;
  final Duration typeAhead;
  final Duration cwdPoll;
  final Curve curve;

  WgMotion reduced() => WgMotion(
    fast: Duration.zero,
    medium: Duration.zero,
    slow: Duration.zero,
    live: Duration.zero,
    resizeThrottle: resizeThrottle,
    hoverSwitch: hoverSwitch,
    typeAhead: typeAhead,
    cwdPoll: cwdPoll,
  );

  @override
  WgMotion copyWith() => this;

  @override
  WgMotion lerp(WgMotion? other, double t) => other ?? this;
}

abstract final class WgTerminalZoom {
  static const double min = 8;
  static const double max = 36;
  static const double step = 1;

  static double clamp(double value) => value.clamp(min, max).roundToDouble();
}

abstract final class WgBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
}
