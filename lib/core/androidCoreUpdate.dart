import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/app_localizations.dart';
import '../common/constant.dart';
import '../common/file.dart';
import '../common/path.dart';
import '../common/request.dart';
import '../common/system.dart';
import '../plugins/service.dart';
import '../state.dart';
import '../widgets/core_update_dialog.dart';

class AndroidCoreUpdate {
  static AndroidCoreUpdate? _instance;

  AndroidCoreUpdate._internal();

  factory AndroidCoreUpdate() {
    _instance ??= AndroidCoreUpdate._internal();
    return _instance!;
  }

  /// 下载指定版本的 libclash.so 并保存为版本化文件名。
  ///
  /// [tagName]  GitHub release 的 tag，如 "v1.9.30"
  Future<void> downloadAndReplace(String tagName) async {
    final abi = await service?.getRuntimeAbi() ?? '';
    if (abi.isEmpty) return;

    final downloadUrl =
        'https://github.com/$coreRepository/releases/download/$tagName/$abi-libclash.so';

    final ctx = globalState.navigatorKey.currentContext;
    if (ctx == null) return;

    String? tmpPath;
    try {
      tmpPath = await showDownloadProgress(
        ctx,
        onDownload: (progressNotifier, cancelToken) async {
          final path = '${await appPath.tempFilePath}.so';
          try {
            await request.dio.download(
              downloadUrl,
              path,
              cancelToken: cancelToken,
              options: Options(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
              ),
              onReceiveProgress: (received, total) {
                if (total > 0) {
                  progressNotifier.value = received / total;
                }
              },
            );
            return path;
          } on Exception {
            await File(path).safeDelete();
            rethrow;
          }
        },
      );
    } on Exception catch (e) {
      if (ctx.mounted) {
        globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: TextSpan(text: describeDownloadError(e)),
          confirmText: currentAppLocalizations.confirm,
        );
      }
      return;
    }

    if (tmpPath == null) return;

    final shouldReplace = await globalState.showMessage(
      title: currentAppLocalizations.tip,
      message: TextSpan(
        text:
            'Core $tagName downloaded. The app must be restarted to apply the update.',
        children: [
          const TextSpan(text: '\n'),
          const TextSpan(text: 'Continue now?'),
        ],
      ),
      confirmText: currentAppLocalizations.confirm,
      cancelText: currentAppLocalizations.cancel,
    );
    if (shouldReplace != true) {
      await File(tmpPath).safeDelete();
      return;
    }

    // Zero-padded segments: v1.19.28 → libclashn011928.so, v2.0.1 → libclashn020001.so
    final versionedFileName = _buildVersionedFileName(tagName);
    bool ok;
    String? saveError;
    try {
      ok =
          await service?.replaceCoreVersionedFile(tmpPath, versionedFileName) ??
          false;
    } on PlatformException catch (e) {
      ok = false;
      saveError = e.message;
    } on Exception catch (e) {
      ok = false;
      saveError = e.toString();
    }
    if (!ok) {
      await File(tmpPath).safeDelete();
      final errorCtx = globalState.navigatorKey.currentContext;
      if (errorCtx != null && errorCtx.mounted) {
        globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: TextSpan(
            text: saveError == null
                ? 'Failed to save the core file.'
                : 'Failed to save the core file ($saveError).',
          ),
          confirmText: currentAppLocalizations.confirm,
        );
      }
      return;
    }

    // 下次冷启动时 Core.findVersionedClash() 自动发现并加载新文件
    final restartCtx = globalState.navigatorKey.currentContext;
    if (restartCtx != null && restartCtx.mounted) {
      globalState.showMessage(
        title: currentAppLocalizations.tip,
        message: const TextSpan(text: 'Core updated. Restart app to apply.'),
        confirmText: currentAppLocalizations.confirm,
      );
    }
  }
}

/// 非 Android 平台返回 null
AndroidCoreUpdate? get androidCoreUpdate =>
    system.isAndroid ? AndroidCoreUpdate() : null;

/// 将 GitHub release 的 tag name 转换为零填充版本化文件名。
///
/// 示例：
///   v1.9.28  → libclashn010928.so
///   v1.19.30 → libclashn011930.so
///   v2.0.1   → libclashn020001.so
String _buildVersionedFileName(String tagName) {
  final versionSuffix = tagName
      .replaceAll(RegExp(r'^[vV]'), '')
      .split('.')
      .map((s) => s.padLeft(2, '0'))
      .join();
  return 'libclashn$versionSuffix.so';
}
