import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

List<List<int>> cells(BufferLine line) {
  final cell = CellData.empty();
  return [
    for (var i = 0; i < line.length; i++)
      () {
        line.getCellData(i, cell);
        return [cell.foreground, cell.background, cell.flags, cell.content];
      }(),
  ];
}

void main() {
  test('scrollback lines are packed and read back cell for cell', () {
    final terminal = Terminal(maxLines: 1000)
      ..reflowEnabled = false
      ..resize(60, 5);
    final text = StringBuffer();
    for (var i = 0; i < 40; i++) {
      text
        ..write('\x1b[1;3${i % 8}m$i bold \x1b[0m')
        ..write('\x1b[48;5;${i * 3}mbg\x1b[0m ')
        ..write(i.isEven ? '漢字テスト' : 'plain ascii text')
        ..write(i % 5 == 0 ? ' 🚀' : '')
        ..write('\r\n');
    }
    final reference = Terminal(maxLines: 1000)
      ..reflowEnabled = false
      ..resize(60, 100);
    terminal.write(text.toString());
    reference.write(text.toString());
    final lines = terminal.mainBuffer.lines;
    var packed = 0;
    for (var i = 0; i < lines.length - 5; i++) {
      if (lines[i].isPacked) packed++;
    }
    expect(packed, greaterThan(30));
    final unpacked = reference.mainBuffer.lines;
    expect(List.generate(unpacked.length, (i) => unpacked[i].isPacked), everyElement(isFalse));
    for (var i = 0; i < 40; i++) {
      expect(lines[i].getText(), unpacked[i].getText(), reason: 'text of line $i');
      expect(cells(lines[i]), cells(unpacked[i]), reason: 'cells of line $i');
    }
  });

  test('editing a packed line unpacks it and keeps the edit', () {
    final line = BufferLine(40)
      ..setCodePoint(0, 'a'.codeUnitAt(0))
      ..setCodePoint(1, 'b'.codeUnitAt(0))
      ..packable = true;
    expect(line.pack(), isTrue);
    expect(line.isPacked, isTrue);
    final version = line.version;
    line.setCodePoint(2, 'c'.codeUnitAt(0));
    expect(line.isPacked, isFalse);
    expect(line.version, greaterThan(version));
    expect(line.getText().trimRight(), 'abc');
  });

  test('clearing scrollback keeps line indexes right', () {
    final terminal = Terminal(maxLines: 100)..resize(20, 3);
    for (var i = 0; i < 30; i++) {
      terminal.write('line $i\r\n');
    }
    terminal.buffer.clearScrollback();
    final lines = terminal.buffer.lines;
    for (var i = 0; i < lines.length; i++) {
      expect(lines[i].index, i);
    }
  });

  test('the glyph cache is shared, bounded and disposes what it drops', () {
    final cache = ParagraphCache.instance..clear();
    final previous = ParagraphCache.maximumSize;
    ParagraphCache.maximumSize = 64;
    addTearDown(() => ParagraphCache.maximumSize = previous);
    final evicted = cache.evictions;
    for (var i = 0; i < 200; i++) {
      final key = ParagraphCache.keyOf(1, 0x41 + (i % 26), 0, 0xFF000000 | i);
      cache.getLayoutFromCache(key) ??
          cache.performAndCacheLayout(
            String.fromCharCode(0x41 + (i % 26)),
            const TerminalStyle().toTextStyle(),
            TextScaler.noScaling,
            key,
          );
    }
    expect(cache.length, 64);
    expect(cache.evictions - evicted, 136);
  });
}
