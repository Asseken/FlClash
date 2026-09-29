import 'dart:io';

import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:riverpod/riverpod.dart';

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
  late ProviderContainer container;

  setUpAll(() {
    appDir = Directory.systemTemp.createTempSync('flclash_theme_app_');
    PathProviderPlatform.instance = _FakePathProvider(appDir.path);
  });

  tearDownAll(() {
    if (appDir.existsSync()) {
      appDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    sourceDir = Directory.systemTemp.createTempSync('flclash_theme_src_');
    container = ProviderContainer();
    container.listen(themeSettingProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    if (sourceDir.existsSync()) {
      sourceDir.deleteSync(recursive: true);
    }
  });

  void setBackgroundImages(List<String> imagePaths) {
    container
        .read(themeSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            backgroundImages: imagePaths,
            backgroundImage: imagePaths.first,
          ),
        );
  }

  test(
    'moves a wallpaper picked into the app cache into the app directory',
    () async {
      final cached = File(p.join(sourceDir.path, 'cached.png'))
        ..writeAsBytesSync(const [1, 2, 3]);
      setBackgroundImages([cached.path]);

      await container
          .read(themeSettingProvider.notifier)
          .persistBackgroundImages();

      final state = container.read(themeSettingProvider);
      final stored = state.backgroundImages.single;
      expect(stored, isNot(cached.path));
      expect(state.backgroundImage, stored);
      expect(p.isWithin(await appPath.backgroundDirPath, stored), isTrue);
      expect(File(stored).readAsBytesSync(), const [1, 2, 3]);
    },
  );

  test('drops a wallpaper whose file is already gone', () async {
    setBackgroundImages([p.join(sourceDir.path, 'gone.png')]);

    await container
        .read(themeSettingProvider.notifier)
        .persistBackgroundImages();

    final state = container.read(themeSettingProvider);
    expect(state.backgroundImages, isEmpty);
    expect(state.backgroundImage, '');
  });

  test('stores an added image in the app directory and selects it', () async {
    final picked = File(p.join(sourceDir.path, 'picked.png'))
      ..writeAsBytesSync(const [1, 2, 3]);

    final stored = await container
        .read(themeSettingProvider.notifier)
        .addBackgroundImage(picked.path);

    final state = container.read(themeSettingProvider);
    expect(stored, isNot(picked.path));
    expect(state.backgroundImages, [stored]);
    expect(state.backgroundImage, stored);
    expect(p.isWithin(await appPath.backgroundDirPath, stored), isTrue);
    expect(File(stored).readAsBytesSync(), const [1, 2, 3]);
  });

  test('removes an image and the file the app owns', () async {
    final picked = File(p.join(sourceDir.path, 'picked.png'))
      ..writeAsBytesSync(const [1, 2, 3]);
    final notifier = container.read(themeSettingProvider.notifier);
    final stored = await notifier.addBackgroundImage(picked.path);

    await notifier.removeBackgroundImage(stored);

    final state = container.read(themeSettingProvider);
    expect(state.backgroundImages, isEmpty);
    expect(state.backgroundImage, '');
    expect(File(stored).existsSync(), isFalse);
  });

  test('keeps a removed image the app does not own', () async {
    final outside = File(p.join(sourceDir.path, 'outside.png'))
      ..writeAsBytesSync(const [1, 2, 3]);
    setBackgroundImages([outside.path]);

    await container
        .read(themeSettingProvider.notifier)
        .removeBackgroundImage(outside.path);

    expect(container.read(themeSettingProvider).backgroundImages, isEmpty);
    expect(outside.existsSync(), isTrue);
  });
}
