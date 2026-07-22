// 单例，只在 Android 调用。
// 提供 downloadAndReplace 方法，由 coreUpdateDialog 在用户选择版本后调用。

import 'dart:io';

import 'package:flutter/material.dart';

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
  ///
  /// 流程：获取设备 ABI → 构造下载 URL → 下载到临时文件 → 保存为 libclashn{ver}.so → 提示重启
  Future<void> downloadAndReplace(String tagName) async {
    final abi = await service?.getRuntimeAbi() ?? '';
    if (abi.isEmpty) return;

    final downloadUrl =
        'https://github.com/$coreRepository/releases/download/$tagName/${abi}-libclash.so';

    final ctx = globalState.navigatorKey.currentContext;
    if (ctx == null) return;

    String? tmpPath;
    try {
      tmpPath = await showDownloadProgress(
        ctx,
        onDownload: (progressNotifier) async {
          final path = '${await appPath.tempFilePath}.so';
          await request.dio.download(
            downloadUrl,
            path,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                progressNotifier.value = received / total;
              }
            },
          );
          return path;
        },
      );
    } on Exception catch (e) {
      if (ctx.mounted) {
        globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: TextSpan(text: 'Download failed: $e'),
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

    // Save with versioned filename using dlopen/dlsym approach.
    // Zero-padded segments: v1.19.28 → libclashn011928.so, v2.0.1 → libclashn020001.so
    final versionedFileName = _buildVersionedFileName(tagName);
    final ok =
        await service?.replaceCoreVersionedFile(tmpPath, versionedFileName) ??
        false;
    if (!ok) {
      await File(tmpPath).safeDelete();
      final errorCtx = globalState.navigatorKey.currentContext;
      if (errorCtx != null && errorCtx.mounted) {
        globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: const TextSpan(text: 'Failed to save the core file.'),
          confirmText: currentAppLocalizations.confirm,
        );
      }
      return;
    }

    // dlopen/dlsym 方案：新 .so 以版本化文件名保存，
    // 下次冷启动时 Core.findVersionedClash() 自动发现并加载。
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

/// 平台条件 getter：非 Android 返回 null
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
