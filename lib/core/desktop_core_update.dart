import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/core_manifest.dart';
import 'package:fl_clash/core/desktop/helper_client.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/core_update_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Swaps the Core executable the desktop app launches, next to the app itself.
///
/// A Core is only replaceable where the app owns that file: the Helper service
/// verifies the Core against a hash compiled into the Helper, so an updated Core
/// could not run through it, and an AppImage or a package-managed install keeps
/// the file on a read-only mount.
class DesktopCoreUpdate {
  static DesktopCoreUpdate? _instance;

  final String _corePath;
  final bool _isReadonly;
  final bool _isPinnedToApp;
  final Future<String?> Function(CoreDownloadHandler onDownload)?
  _injectedProgress;

  DesktopCoreUpdate._internal()
    : _corePath = appPath.corePath,
      _isReadonly = false,
      _isPinnedToApp = false,
      _injectedProgress = null;

  @visibleForTesting
  DesktopCoreUpdate.forTesting({
    required String corePath,
    bool isReadonly = false,
    bool pinnedToApp = false,
    Future<String?> Function(CoreDownloadHandler onDownload)? showProgress,
  }) : _corePath = corePath,
       _isReadonly = isReadonly,
       _isPinnedToApp = pinnedToApp,
       _injectedProgress = showProgress;

  factory DesktopCoreUpdate() {
    _instance ??= DesktopCoreUpdate._internal();
    return _instance!;
  }

  static const minCoreBytes = 1024 * 1024;

  static Future<bool> _helperPinsCore() async {
    return await helperClient.readiness(logFailure: false) ==
        HelperReadiness.ready;
  }

  Future<String?> _showProgress(CoreDownloadHandler onDownload) {
    final injected = _injectedProgress;
    if (injected != null) {
      return injected(onDownload);
    }
    return showCoreDownloadProgress(onDownload: onDownload);
  }

  Future<bool> downloadAndReplace(String tagName) async {
    if (!system.isDesktop) {
      return false;
    }
    final blockedTip = await _blockedTip();
    if (blockedTip != null) {
      _showMessage(blockedTip);
      return false;
    }
    final coreInfo = globalState.container.read(coreVersionInfoDataProvider);
    final url = buildCoreDownloadUrl(
      tagName: tagName,
      goOs: coreInfo?.goOs ?? hostGoOs(),
      goArch: coreInfo?.goArch ?? hostGoArch(),
    );
    final String? downloadedPath;
    try {
      downloadedPath = await _showProgress((progress, cancelToken) {
        return _download(url, progress, cancelToken);
      });
    } catch (error) {
      _showMessage(userFacingErrorMessage(error, currentAppLocalizations));
      return false;
    }
    if (downloadedPath == null) {
      return false;
    }
    return _replaceAndRestart(downloadedPath, tagName);
  }

  Future<String?> _blockedTip() async {
    if (_isReadonly || system.isAppImage) {
      return currentAppLocalizations.coreUpdateReadonlyTip;
    }
    if (_isPinnedToApp || await _helperPinsCore()) {
      return currentAppLocalizations.coreUpdateHelperTip;
    }
    if (!await _isReplaceable()) {
      return currentAppLocalizations.coreUpdateUnwritableTip;
    }
    return null;
  }

  Future<bool> _isReplaceable() async {
    final probe = File('$_corePath.probe');
    try {
      await probe.writeAsString('');
      return true;
    } catch (_) {
      return false;
    } finally {
      await probe.safeDelete();
    }
  }

  Future<bool> _replaceAndRestart(String downloadedPath, String tagName) async {
    final container = globalState.container;
    final coreAction = container.read(coreActionProvider.notifier);
    final wasRunning = container.read(isStartProvider);
    try {
      await coreAction.stopCore();
    } catch (error) {
      _showMessage(userFacingErrorMessage(error, currentAppLocalizations));
      await File(downloadedPath).safeDelete();
      return false;
    }
    var replaced = false;
    try {
      replaced = await swapCoreFile(
        downloadedPath: downloadedPath,
        corePath: _corePath,
      );
      if (replaced) {
        await CoreManifest.writeCoreSha256(
          await sha256OfFile(_corePath),
          path: manifestPathFor(_corePath),
        );
      }
    } catch (error) {
      commonPrint.log(
        'Unable to replace the Core: ${compactError(error)}',
        logLevel: LogLevel.error,
      );
    } finally {
      await File(downloadedPath).safeDelete();
    }
    if (!replaced) {
      if (wasRunning) {
        await coreAction.restartCore();
      }
      _showMessage(currentAppLocalizations.coreUpdateFailed);
      return false;
    }
    if (wasRunning) {
      try {
        await coreAction.restartCore();
        container.read(coreUpdateProvider.notifier).refreshCurrentVersion();
      } catch (error) {
        _showMessage(userFacingErrorMessage(error, currentAppLocalizations));
        return false;
      }
    }
    _showMessage(currentAppLocalizations.coreUpdateReloadedTip(tagName));
    return true;
  }

  Future<String?> _download(
    String url,
    ValueNotifier<double> progress,
    CancelToken cancelToken,
  ) async {
    final path = '${await appPath.tempFilePath}${appPath.executableExtension}';
    try {
      await request.dio.download(
        url,
        path,
        cancelToken: cancelToken,
        options: Options(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progress.value = received / total;
          }
        },
      );
      return path;
    } on Exception {
      await File(path).safeDelete();
      rethrow;
    }
  }

  void _showMessage(String message) {
    final context = globalState.navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    unawaited(
      dialogs.showMessage(
        title: currentAppLocalizations.tip,
        message: TextSpan(text: message),
      ),
    );
  }
}

DesktopCoreUpdate? get desktopCoreUpdate =>
    system.isDesktop ? DesktopCoreUpdate() : null;

/// Release asset name for a desktop Core: `{goos}-{goarch}-FlClashCore{ext}`.
String buildCoreDownloadUrl({
  required String tagName,
  required String goOs,
  required String goArch,
}) {
  final extension = goOs == 'windows' ? '.exe' : '';
  return 'https://github.com/$coreRepository/releases/download/'
      '$tagName/$goOs-$goArch-FlClashCore$extension';
}

/// The Helper reads the manifest that lives beside the Core it verifies.
@visibleForTesting
String manifestPathFor(String corePath) {
  return p.join(p.dirname(corePath), coreManifestName);
}

String hostGoOs() {
  if (system.isWindows) {
    return 'windows';
  }
  return system.isMacOS ? 'darwin' : 'linux';
}

String hostGoArch() {
  final goArch = goArchOf(Abi.current());
  if (goArch == null) {
    commonPrint.log(
      'Unknown host ABI ${Abi.current()}, assuming amd64',
      logLevel: LogLevel.warning,
    );
    return 'amd64';
  }
  return goArch;
}

@visibleForTesting
String? goArchOf(Abi abi) {
  return switch (abi) {
    Abi.linuxX64 || Abi.macosX64 || Abi.windowsX64 => 'amd64',
    Abi.linuxArm64 || Abi.macosArm64 || Abi.windowsArm64 => 'arm64',
    Abi.linuxIA32 || Abi.windowsIA32 => '386',
    _ => null,
  };
}

/// Hashes a local file without holding it in memory: a Core is tens of megabytes.
@visibleForTesting
Future<String> sha256OfFile(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

/// Moves [downloadedPath] into [corePath] through a staging file, keeping the
/// replaced Core as a backup until the swap finished.
@visibleForTesting
Future<bool> swapCoreFile({
  required String downloadedPath,
  required String corePath,
  int minBytes = DesktopCoreUpdate.minCoreBytes,
}) async {
  final stagingPath = '$corePath.new';
  final backupPath = '$corePath.bak';
  final source = File(downloadedPath);
  if (!await source.exists() || await source.length() < minBytes) {
    commonPrint.log(
      'The downloaded Core is missing or too small to be a Core',
      logLevel: LogLevel.warning,
    );
    return false;
  }
  var backedUp = false;
  try {
    await _retry(() => source.copy(stagingPath), 'stage the downloaded Core');
    await _ensureExecutable(stagingPath);
    if (await File(corePath).exists()) {
      await _retry(() async {
        await File(backupPath).safeDelete();
        await File(corePath).rename(backupPath);
      }, 'back up the running Core');
      backedUp = true;
    }
    await _retry(
      () => File(stagingPath).rename(corePath),
      'install the new Core',
    );
  } catch (error) {
    commonPrint.log(
      'Unable to swap the Core binary: ${compactError(error)}',
      logLevel: LogLevel.error,
    );
    if (backedUp && !await File(corePath).exists()) {
      await _restoreCore(backupPath, corePath);
    }
    await File(stagingPath).safeDelete();
    return false;
  }
  await File(backupPath).safeDelete();
  return true;
}

Future<void> _restoreCore(String backupPath, String corePath) async {
  try {
    await _retry(
      () => File(backupPath).rename(corePath),
      'restore the previous Core',
    );
  } catch (error) {
    commonPrint.log(
      'Unable to restore the previous Core: ${compactError(error)}',
      logLevel: LogLevel.error,
    );
  }
}

// Windows releases a killed process' file handle late, so a rename can lose a
// race it would win on the next attempt.
Future<void> _retry(
  Future<void> Function() operation,
  String description, {
  int attempts = 3,
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      await operation();
      return;
    } catch (error) {
      if (attempt >= attempts) {
        rethrow;
      }
      commonPrint.log(
        '$description failed (attempt $attempt): ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
}

Future<void> _ensureExecutable(String path) async {
  if (system.isWindows) {
    return;
  }
  try {
    final result = await Process.run('chmod', ['+x', path]);
    if (result.exitCode != 0) {
      commonPrint.log(
        'chmod +x exited with ${result.exitCode}: '
        '${result.stderr.toString().trim()}',
        logLevel: LogLevel.warning,
      );
    }
  } catch (error) {
    commonPrint.log(
      'chmod +x failed: ${compactError(error)}',
      logLevel: LogLevel.warning,
    );
  }
}
