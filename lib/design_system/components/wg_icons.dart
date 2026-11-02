import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

abstract final class WgIcons {
  static const IconData terminal = LucideIcons300.squareTerminal;
  static const IconData server = LucideIcons300.server;
  static const IconData folder = LucideIcons300.folder;
  static const IconData folderOpen = LucideIcons300.folderOpen;
  static const IconData folderPlus = LucideIcons300.folderPlus;
  static const IconData file = LucideIcons300.file;
  static const IconData fileText = LucideIcons300.fileText;
  static const IconData image = LucideIcons300.image;
  static const IconData link = LucideIcons300.link;
  static const IconData key = LucideIcons300.keyRound;
  static const IconData lock = LucideIcons300.lock;
  static const IconData unlock = LucideIcons300.lockOpen;
  static const IconData shield = LucideIcons300.shieldCheck;
  static const IconData settings = LucideIcons300.settings;
  static const IconData search = LucideIcons300.search;
  static const IconData plus = LucideIcons300.plus;
  static const IconData minus = LucideIcons300.minus;
  static const IconData close = LucideIcons300.x;
  static const IconData check = LucideIcons300.check;
  static const IconData chevronRight = LucideIcons300.chevronRight;
  static const IconData chevronDown = LucideIcons300.chevronDown;
  static const IconData chevronLeft = LucideIcons300.chevronLeft;
  static const IconData arrowUp = LucideIcons300.arrowUp;
  static const IconData arrowDown = LucideIcons300.arrowDown;
  static const IconData arrowLeft = LucideIcons300.arrowLeft;
  static const IconData arrowRight = LucideIcons300.arrowRight;
  static const IconData arrowLeftRight = LucideIcons300.arrowLeftRight;
  static const IconData splitHorizontal = LucideIcons300.columns2;
  static const IconData splitVertical = LucideIcons300.rows2;
  static const IconData grid = LucideIcons300.layoutGrid;
  static const IconData list = LucideIcons300.list;
  static const IconData layout = LucideIcons300.layoutDashboard;
  static const IconData maximize = LucideIcons300.maximize2;
  static const IconData minimize = LucideIcons300.minimize2;
  static const IconData swap = LucideIcons300.repeat2;
  static const IconData sidebar = LucideIcons300.panelLeft;
  static const IconData transfer = LucideIcons300.arrowDownUp;
  static const IconData upload = LucideIcons300.upload;
  static const IconData download = LucideIcons300.download;
  static const IconData pause = LucideIcons300.pause;
  static const IconData play = LucideIcons300.play;
  static const IconData retry = LucideIcons300.rotateCw;
  static const IconData refresh = LucideIcons300.refreshCw;
  static const IconData trash = LucideIcons300.trash2;
  static const IconData edit = LucideIcons300.pencil;
  static const IconData copy = LucideIcons300.copy;
  static const IconData paste = LucideIcons300.clipboard;
  static const IconData eye = LucideIcons300.eye;
  static const IconData eyeOff = LucideIcons300.eyeOff;
  static const IconData broadcast = LucideIcons300.radioTower;
  static const IconData multiExec = LucideIcons300.listChecks;
  static const IconData snippet = LucideIcons300.code;
  static const IconData forward = LucideIcons300.cable;
  static const IconData workspace = LucideIcons300.layers;
  static const IconData tag = LucideIcons300.tag;
  static const IconData group = LucideIcons300.boxes;
  static const IconData more = LucideIcons300.ellipsis;
  static const IconData info = LucideIcons300.info;
  static const IconData warning = LucideIcons300.triangleAlert;
  static const IconData error = LucideIcons300.circleAlert;
  static const IconData offline = LucideIcons300.wifiOff;
  static const IconData plug = LucideIcons300.plug;
  static const IconData bot = LucideIcons300.bot;
  static const IconData history = LucideIcons300.history;
  static const IconData save = LucideIcons300.save;
  static const IconData home = LucideIcons300.house;
  static const IconData keyboard = LucideIcons300.keyboard;
  static const IconData fingerprint = LucideIcons300.fingerprintPattern;
  static const IconData archive = LucideIcons300.archive;
  static const IconData scrollText = LucideIcons300.scrollText;
  static const IconData monitor = LucideIcons300.monitor;
  static const IconData window = LucideIcons300.appWindow;
  static const IconData hidden = LucideIcons300.eyeClosed;
  static const IconData sortAsc = LucideIcons300.arrowUpNarrowWide;
  static const IconData sortDesc = LucideIcons300.arrowDownWideNarrow;
  static const IconData permissions = LucideIcons300.fileLock;
  static const IconData move = LucideIcons300.move;
  static const IconData import = LucideIcons300.fileInput;
  static const IconData export = LucideIcons300.fileOutput;
  static const IconData zoomIn = LucideIcons300.zoomIn;
  static const IconData zoomOut = LucideIcons300.zoomOut;
}

class WgIcon extends StatelessWidget {
  const new(this.icon, {super.key, this.color, this.size, this.label});

  final IconData icon;
  final Color? color;
  final double? size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    return Icon(
      icon,
      size: size ?? iconTheme.size,
      color: color ?? iconTheme.color,
      semanticLabel: label,
    );
  }
}
