import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/qr.dart';

void main() {
  test('picks the smallest version that holds the link', () {
    expect(QrMatrix.encode('hello')!.size, 21);
    expect(QrMatrix.encode('https://iqly.net/a/a2')!.size, 25);
    expect(QrMatrix.encode('x' * 106)!.size, 41);
    expect(QrMatrix.encode('x' * 107), isNull);
  });

  test('draws the finders, the timing and the format bits', () {
    final qr = QrMatrix.encode('https://iqly.net/a/a2', mask: 0)!;
    const finder = [
      '1111111',
      '1000001',
      '1011101',
      '1011101',
      '1011101',
      '1000001',
      '1111111',
    ];
    for (final (ox, oy) in [(0, 0), (qr.size - 7, 0), (0, qr.size - 7)]) {
      for (var y = 0; y < 7; y++) {
        final row = [
          for (var x = 0; x < 7; x++) qr.dark(ox + x, oy + y) ? '1' : '0',
        ].join();
        expect(row, finder[y]);
      }
    }
    for (var i = 8; i < qr.size - 8; i++) {
      expect(qr.dark(i, 6), i.isEven);
      expect(qr.dark(6, i), i.isEven);
    }
    // Level M, mask 0: 101010000010010 (ISO 18004 table C.1).
    const format = '101010000010010';
    final read = [
      for (var i = 0; i <= 5; i++) qr.dark(8, i),
      qr.dark(8, 7),
      qr.dark(8, 8),
      qr.dark(7, 8),
      for (var i = 9; i < 15; i++) qr.dark(14 - i, 8),
    ].reversed.map((d) => d ? '1' : '0').join();
    expect(read, format);
    expect(qr.dark(8, qr.size - 8), isTrue);
  });
}
