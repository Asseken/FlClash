import 'dart:ffi';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop_core_update.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// `appPath` resolves through path_provider, which no plugin answers in a test.
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

  late Directory appPathDir;

  setUpAll(() async {
    appPathDir = Directory.systemTemp.createTempSync('flclash_update_app_');
    PathProviderPlatform.instance = _FakePathProvider(appPathDir.path);
    await AppLocalizations.load(const Locale('en'));
  });

  tearDownAll(() {
    if (appPathDir.existsSync()) {
      appPathDir.deleteSync(recursive: true);
    }
  });

  group('buildCoreDownloadUrl', () {
    test('names the release asset the way the Core releases publish it', () {
      expect(
        buildCoreDownloadUrl(
          tagName: 'v1.19.31',
          goOs: 'windows',
          goArch: 'amd64',
        ),
        'https://github.com/Asseken/FlClashCore/releases/download/'
        'v1.19.31/windows-amd64-FlClashCore.exe',
      );
      expect(
        buildCoreDownloadUrl(
          tagName: 'v1.19.31',
          goOs: 'darwin',
          goArch: 'arm64',
        ),
        endsWith('/v1.19.31/darwin-arm64-FlClashCore'),
      );
    });
  });

  group('goArchOf', () {
    test('maps the Dart ABI to the Go architecture name', () {
      expect(goArchOf(Abi.windowsX64), 'amd64');
      expect(goArchOf(Abi.linuxArm64), 'arm64');
      expect(goArchOf(Abi.windowsIA32), '386');
    });
  });

  group('sha256OfFile', () {
    test('hashes the file contents', () async {
      final directory = Directory.systemTemp.createTempSync(
        'flclash_sha_test_',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/core')..writeAsStringSync('abc');

      expect(
        await sha256OfFile(file.path),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
  });

  group('swapCoreFile', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('flclash_swap_test_');
    });

    tearDown(() {
      directory.deleteSync(recursive: true);
    });

    File writeFile(String name, String content) {
      return File('${directory.path}/$name')..writeAsStringSync(content);
    }

    test('replaces the Core and leaves no staging files behind', () async {
      final core = writeFile('FlClashCore', 'old-core');
      final downloaded = writeFile('download', 'new-core');

      final swapped = await swapCoreFile(
        downloadedPath: downloaded.path,
        corePath: core.path,
        minBytes: 4,
      );

      expect(swapped, isTrue);
      expect(core.readAsStringSync(), 'new-core');
      expect(File('${core.path}.bak').existsSync(), isFalse);
      expect(File('${core.path}.new').existsSync(), isFalse);
    });

    test('keeps the running Core when the download is not a Core', () async {
      final core = writeFile('FlClashCore', 'old-core');
      final downloaded = writeFile('download', 'tiny');

      final swapped = await swapCoreFile(
        downloadedPath: downloaded.path,
        corePath: core.path,
        minBytes: 1024,
      );

      expect(swapped, isFalse);
      expect(core.readAsStringSync(), 'old-core');
      expect(File('${core.path}.bak').existsSync(), isFalse);
      expect(File('${core.path}.new').existsSync(), isFalse);
    });

    test('installs a Core where none was installed yet', () async {
      final corePath = '${directory.path}/FlClashCore';
      final downloaded = writeFile('download', 'first-core');

      final swapped = await swapCoreFile(
        downloadedPath: downloaded.path,
        corePath: corePath,
        minBytes: 4,
      );

      expect(swapped, isTrue);
      expect(File(corePath).readAsStringSync(), 'first-core');
    });
  });

  group('downloadAndReplace', () {
    late Directory directory;
    late ProviderContainer container;
    late String corePath;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('flclash_update_test_');
      container = ProviderContainer();
      globalState.container = container;
      corePath = '${directory.path}/FlClashCore';
    });

    tearDown(() {
      container.dispose();
      directory.deleteSync(recursive: true);
    });

    test('leaves a read-only install alone', () async {
      final update = DesktopCoreUpdate.forTesting(
        corePath: corePath,
        isReadonly: true,
      );

      expect(await update.downloadAndReplace('v1.19.31'), isFalse);
      expect(File(corePath).existsSync(), isFalse);
    });

    test('leaves a Core pinned to the app release alone', () async {
      final update = DesktopCoreUpdate.forTesting(
        corePath: corePath,
        pinnedToApp: true,
      );

      expect(await update.downloadAndReplace('v1.19.31'), isFalse);
      expect(File(corePath).existsSync(), isFalse);
    });

    test('leaves a Core it cannot write beside alone', () async {
      final blocker = File('${directory.path}/blocker')..writeAsStringSync('');
      final update = DesktopCoreUpdate.forTesting(
        corePath: '${blocker.path}/FlClashCore',
      );

      expect(await update.downloadAndReplace('v1.19.31'), isFalse);
      expect(blocker.readAsStringSync(), '');
    });

    test('keeps the installed Core when the download fails', () async {
      final core = File(corePath)..writeAsStringSync('installed');
      final update = DesktopCoreUpdate.forTesting(
        corePath: corePath,
        showProgress: (onDownload) {
          return onDownload(ValueNotifier<double>(0), CancelToken());
        },
      );
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
        },
      );
      request.dio.interceptors.add(interceptor);
      addTearDown(() => request.dio.interceptors.remove(interceptor));

      expect(await update.downloadAndReplace('v1.19.31'), isFalse);
      expect(core.readAsStringSync(), 'installed');
      expect(File('$corePath.bak').existsSync(), isFalse);
    });
  });
}
