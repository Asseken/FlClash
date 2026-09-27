import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/core/desktop/core_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('flclash_manifest_test_');
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  test('reads the Core SHA256 from the runtime manifest', () async {
    const hash =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    final file = File('${directory.path}/manifest.json')
      ..writeAsStringSync('{"coreSha256":"$hash"}');

    expect(await CoreManifest.readCoreSha256(path: file.path), hash);
  });

  test('rejects malformed or non-SHA256 manifest values', () async {
    final file = File('${directory.path}/manifest.json')
      ..writeAsStringSync('{"coreSha256":"not-a-sha256"}');

    expect(await CoreManifest.readCoreSha256(path: file.path), isNull);
  });

  test('returns null when the manifest is missing', () async {
    expect(
      await CoreManifest.readCoreSha256(
        path: '${directory.path}/missing-manifest.json',
      ),
      isNull,
    );
  });

  test('records the hash a replaced Core has to match', () async {
    final hash = List.filled(32, 'ab').join();
    final file = File('${directory.path}/manifest.json');

    expect(await CoreManifest.writeCoreSha256(hash, path: file.path), isTrue);
    expect(await CoreManifest.readCoreSha256(path: file.path), hash);
  });

  test('keeps the other manifest keys', () async {
    final hash = List.filled(32, 'cd').join();
    final file = File('${directory.path}/manifest.json')
      ..writeAsStringSync(
        '{"coreSha256":"${List.filled(32, 'ab').join()}","other":7}',
      );

    expect(await CoreManifest.writeCoreSha256(hash, path: file.path), isTrue);

    final values = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(values['coreSha256'], hash);
    expect(values['other'], 7);
  });

  test('refuses a value that is not a SHA256', () async {
    expect(
      await CoreManifest.writeCoreSha256(
        'not-a-sha256',
        path: '${directory.path}/manifest.json',
      ),
      isFalse,
    );
  });
}
