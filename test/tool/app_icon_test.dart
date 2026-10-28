import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Windows picks the entry that matches the size the shell asks for and scales
/// any that is missing, so a gap in the ladder reads as a blurry shortcut.
const _ladder = [16, 20, 24, 28, 32, 40, 48, 56, 60, 64, 72, 84, 96, 128, 256];

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

List<int> _sizesOf(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  expect(data.getUint16(0, Endian.little), 0, reason: 'not an icon file');
  expect(data.getUint16(2, Endian.little), 1, reason: 'not an icon file');
  final count = data.getUint16(4, Endian.little);
  final sizes = <int>[];
  for (var index = 0; index < count; index++) {
    final entry = 6 + index * 16;
    final width = bytes[entry];
    final length = data.getUint32(entry + 8, Endian.little);
    final start = data.getUint32(entry + 12, Endian.little);
    expect(
      bytes.sublist(start, start + 8),
      _pngSignature,
      reason: '$path entry $index is not PNG compressed',
    );
    expect(
      start + length <= bytes.length,
      isTrue,
      reason: '$path entry $index runs past the file',
    );
    sizes.add(width == 0 ? 256 : width);
  }
  return sizes;
}

void main() {
  test('the Windows icons cover every size Explorer asks for', () {
    for (final path in [
      'windows/runner/resources/app_icon.ico',
      'assets/images/icon.ico',
    ]) {
      final sizes = _sizesOf(path);
      expect(
        sizes.toSet().length,
        sizes.length,
        reason: '$path repeats a size',
      );
      expect(
        sizes.toSet(),
        _ladder.toSet(),
        reason: '$path is missing a size the shell would have to scale',
      );
    }
  });
}
