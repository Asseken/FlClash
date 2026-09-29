import 'dart:io';

import 'package:fl_clash/common/background.dart';
import 'package:fl_clash/common/path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// The app directory resolves through path_provider, which no plugin answers in
/// a test.
class _FakePathProvider extends PathProviderPlatform {
  final String root;

  _FakePathProvider(this.root);

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appDir;
  late Directory sourceDir;

  setUpAll(() {
    appDir = Directory.systemTemp.createTempSync('flclash_background_app_');
    PathProviderPlatform.instance = _FakePathProvider(appDir.path);
  });

  tearDownAll(() {
    if (appDir.existsSync()) {
      appDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    sourceDir = Directory.systemTemp.createTempSync('flclash_background_src_');
  });

  tearDown(() {
    if (sourceDir.existsSync()) {
      sourceDir.deleteSync(recursive: true);
    }
  });

  File sourceFile(String name) {
    return File(p.join(sourceDir.path, name))
      ..writeAsBytesSync(const [1, 2, 3]);
  }

  test('copies a picked image into the app directory', () async {
    final source = sourceFile('picked.png');

    final stored = await backgroundHelper.persistImage(source.path);

    expect(stored, isNot(source.path));
    expect(p.isWithin(await appPath.backgroundDirPath, stored), isTrue);
    expect(File(stored).readAsBytesSync(), const [1, 2, 3]);
  });

  test('returns a missing source unchanged', () async {
    final missing = p.join(sourceDir.path, 'gone.png');

    expect(await backgroundHelper.persistImage(missing), missing);
  });

  test('moves stored paths and drops the ones whose file is gone', () async {
    final legacy = sourceFile('legacy.png');
    final missing = p.join(sourceDir.path, 'gone.png');
    final kept = await backgroundHelper.persistImage(
      sourceFile('kept.png').path,
    );

    final stored = await backgroundHelper.persistImages([
      legacy.path,
      missing,
      kept,
    ]);

    expect(stored, hasLength(2));
    expect(stored.last, kept);
    expect(p.isWithin(await appPath.backgroundDirPath, stored.first), isTrue);
    expect(File(stored.first).readAsBytesSync(), const [1, 2, 3]);
  });

  test('deletes an image it owns', () async {
    final stored = await backgroundHelper.persistImage(
      sourceFile('stored.png').path,
    );

    await backgroundHelper.deleteImage(stored);

    expect(File(stored).existsSync(), isFalse);
  });

  test('never deletes a file outside the app directory', () async {
    final outside = sourceFile('outside.png');

    await backgroundHelper.deleteImage(outside.path);

    expect(outside.existsSync(), isTrue);
  });
}
