import 'package:fl_clash/core/android_core_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildVersionedCoreFileName', () {
    test('pads every version segment to two digits', () {
      expect(buildVersionedCoreFileName('v1.9.28'), 'libclashn010928.so');
      expect(buildVersionedCoreFileName('v1.19.30'), 'libclashn011930.so');
      expect(buildVersionedCoreFileName('V2.0.1'), 'libclashn020001.so');
    });

    test('produces the name the native loader accepts', () {
      for (final tagName in ['v1.9.28', 'v2.0.1', 'v10.20.30']) {
        expect(
          buildVersionedCoreFileName(tagName),
          matches(RegExp(r'^libclashn\d+\.so$')),
        );
      }
    });
  });
}
