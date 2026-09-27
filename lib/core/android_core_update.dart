import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/core_update_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Installs a published Core next to the one bundled in the APK. The running
/// Core keeps serving until the next cold start, when the native loader picks
/// the downloaded file up in place of the bundled copy.
class AndroidCoreUpdate {
  static AndroidCoreUpdate? _instance;

  AndroidCoreUpdate._internal();

  factory AndroidCoreUpdate() {
    _instance ??= AndroidCoreUpdate._internal();
    return _instance!;
  }

  Future<bool> downloadAndReplace(String tagName) async {
    final abi = await service?.getRuntimeAbi() ?? '';
    if (abi.isEmpty) {
      return false;
    }
    final url =
        'https://github.com/$coreRepository/releases/download/$tagName/$abi-libclash.so';
    final String? downloadedPath;
    try {
      downloadedPath = await showCoreDownloadProgress(
        onDownload: (progress, cancelToken) {
          return _download(url, progress, cancelToken);
        },
      );
    } catch (error) {
      _showMessage(userFacingErrorMessage(error, currentAppLocalizations));
      return false;
    }
    if (downloadedPath == null) {
      return false;
    }
    return _install(downloadedPath, tagName);
  }

  Future<bool> _install(String downloadedPath, String tagName) async {
    var installed = false;
    try {
      installed =
          await service?.replaceCoreVersionedFile(
            downloadedPath,
            buildVersionedCoreFileName(tagName),
          ) ??
          false;
    } catch (error) {
      commonPrint.log(
        'Unable to install the Core: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
    if (!installed) {
      await File(downloadedPath).safeDelete();
      _showMessage(currentAppLocalizations.coreUpdateFailed);
      return false;
    }
    _showMessage(currentAppLocalizations.coreUpdateRestartTip(tagName));
    return true;
  }

  Future<String?> _download(
    String url,
    ValueNotifier<double> progress,
    CancelToken cancelToken,
  ) async {
    final path = '${await appPath.tempFilePath}.so';
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

final androidCoreUpdate = system.isAndroid ? AndroidCoreUpdate() : null;

/// `v1.19.30` becomes `libclashn011930.so`, the only name the native loader
/// accepts, so every segment is padded to two digits.
String buildVersionedCoreFileName(String tagName) {
  final suffix = tagName
      .replaceAll(RegExp(r'^[vV]'), '')
      .split('.')
      .map((segment) => segment.padLeft(2, '0'))
      .join();
  return 'libclashn$suffix.so';
}
