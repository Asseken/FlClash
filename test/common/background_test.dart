import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/app_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('background_test');
    await useAppPaths(root);
  });

  tearDownAll(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('a picked image is copied into the app data directory', () async {
    final source = File(p.join(root.path, 'picked.png'))
      ..writeAsBytesSync([1, 2, 3]);

    final stored = await backgroundHelper.persistImage(source.path);
    final backgroundDir = await appPath.backgroundDirPath;

    expect(
      p.equals(p.dirname(stored), backgroundDir),
      isTrue,
      reason:
          'the copy must live beside config.yaml, not where the picker left '
          'it: the platform clears that cache and would blank the wallpaper',
    );
    expect(File(stored).readAsBytesSync(), [1, 2, 3]);
    expect(p.basename(stored), startsWith('background_'));
    expect(p.extension(stored), '.png');
    expect(
      source.existsSync(),
      isTrue,
      reason: 'the picker file belongs to the picker, not to this copy',
    );
  });

  test('the same image picked twice yields two independent copies', () async {
    final source = File(p.join(root.path, 'twice.png'))..writeAsBytesSync([9]);

    final first = await backgroundHelper.persistImage(source.path);
    final second = await backgroundHelper.persistImage(source.path);

    expect(first, isNot(second));
    expect(File(first).existsSync(), isTrue);
    expect(File(second).existsSync(), isTrue);
  });

  test('a missing source is returned unchanged', () async {
    final missing = p.join(root.path, 'never_existed.png');

    expect(await backgroundHelper.persistImage(missing), missing);
  });

  test('deleting a copy removes it', () async {
    final source = File(p.join(root.path, 'delete_me.png'))
      ..writeAsBytesSync([4]);
    final stored = await backgroundHelper.persistImage(source.path);

    await backgroundHelper.deleteImage(stored);

    expect(File(stored).existsSync(), isFalse);
  });

  test('deleting refuses a path the helper did not make', () async {
    final outsider = File(p.join(root.path, 'user_picture.png'))
      ..writeAsBytesSync([5]);

    await backgroundHelper.deleteImage(outsider.path);

    expect(outsider.existsSync(), isTrue);
  });
}
