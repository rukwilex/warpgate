enum TerminalMouseButton {
  left(id: 0),

  middle(id: 1),

  right(id: 2),

  wheelUp(id: 64 + 4, isWheel: true),

  wheelDown(id: 64 + 5, isWheel: true),

  wheelLeft(id: 64 + 6, isWheel: true),

  wheelRight(id: 64 + 7, isWheel: true);

  final int id;

  final bool isWheel;

  const TerminalMouseButton({required this.id, this.isWheel = false});
}
