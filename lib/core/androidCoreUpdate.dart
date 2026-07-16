//单例只在Android调用

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart%20';

import '../common/app_localizations.dart';
import '../common/file.dart';
import '../common/path.dart';
import '../common/request.dart';
import '../common/system.dart';
import '../common/utils.dart';
import '../plugins/service.dart';
import '../state.dart';
import 'controller.dart';

class AndroidCoreUpdate {
  static AndroidCoreUpdate? _instance;

  AndroidCoreUpdate._internal();

  factory AndroidCoreUpdate() {
    _instance ??= AndroidCoreUpdate._internal();
    return _instance!;
  }

  Future<void> autoCheckCoreUpdate() async {
    if (!system.isAndroid) return;
    Map<String, dynamic> coreVersionData;
    try {
      coreVersionData = await coreController.getCoreVersion();
    } catch (_) {
      return;
    }
    String currentVersion = coreVersionData['core-version'] as String? ?? '';
    if (currentVersion.isEmpty) return;
    currentVersion = currentVersion.replaceAll(RegExp(r'^[vV]'), '');
    if (currentVersion.isEmpty) return;
    final remoteData = await request.checkCoreForUpdate();
    if (remoteData == null) return;
    final tagName = remoteData['tag_name'] as String? ?? '';
    final remoteVersion = tagName.replaceAll(RegExp(r'^[vV]'), '');
    if (remoteVersion.isEmpty) return;
    if (utils.compareVersions(remoteVersion, currentVersion) <= 0) return;

    final context = globalState.navigatorKey.currentContext;
    if (context == null) return;
    final textTheme = Theme.of(context).textTheme;
    final body = remoteData['body'] as String? ?? '';
    final submits = utils.parseReleaseBody(body);

    final res = await globalState.showMessage(
      title: 'Core ${currentAppLocalizations.discoverNewVersion}',
      message: TextSpan(
        text: '$tagName',
        style: textTheme.headlineSmall,
        children: [
          TextSpan(text: '', style: textTheme.bodyMedium),
          for (final submit in submits)
            TextSpan(text: '- $submit', style: textTheme.bodyMedium),
        ],
      ),
      confirmText: currentAppLocalizations.goDownload,
      cancelText: currentAppLocalizations.cancel,
    );
    if (res == true) {
      final wasRunning = (await service?.getRunTime()) != null;
      final abi = await service?.getRuntimeAbi() ?? '';
      if (abi.isEmpty) return;
      final coreTargetPath = await service?.getCoreFilePath() ?? '';
      final downloadUrl =
          'https://github.com/Asseken/FlcashCore/releases/download/$tagName/${abi}-libclash.so';

      final progressNotifier = ValueNotifier<double>(0.0);
      final ctx = globalState.navigatorKey.currentContext;
      if (ctx == null) return;

      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Downloading Core'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (_, progress, __) => Column(
                    children: [
                      LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                      ),
                      const SizedBox(height: 8),
                      Text('${(progress * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final d = Dio();
      final tmpPath = (await appPath.tempFilePath) + '.so';
      try {
        await d.download(
          downloadUrl,
          tmpPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              progressNotifier.value = received / total;
            }
          },
        );
      } catch (e) {
        if (ctx.mounted) Navigator.of(ctx).pop();
        globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: TextSpan(text: 'Download failed: $e'),
          confirmText: currentAppLocalizations.confirm,
        );
        return;
      }

      if (ctx.mounted) Navigator.of(ctx).pop();

      final shouldReplace = await globalState.showMessage(
        title: currentAppLocalizations.tip,
        message: TextSpan(
          text: wasRunning
              ? 'Core downloaded. The running core will be stopped, replaced, and restarted.\n'
              : 'Core downloaded. The core file will be replaced.\n',
          children: [
            TextSpan(text: 'Temp file: $tmpPath\n'),
            if (coreTargetPath.isNotEmpty)
              TextSpan(text: 'Target file: $coreTargetPath\n'),
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

      // Save with versioned filename using dlopen/dlsym approach
      final versionSuffix = tagName.replaceAll(RegExp(r'[vV.]'), '');
      final versionedFileName = 'libclashn$versionSuffix.so';
      final ok =
          await service?.replaceCoreVersionedFile(tmpPath, versionedFileName) ??
          false;
      if (!ok) {
        await File(tmpPath).safeDelete();
        throw Exception('replaceCoreVersionedFile failed');
      }

      // dlopen/dlsym 方案：新 .so 以版本化文件名保存，
      // 下次冷启动时 Core.findVersionedClash() 自动发现并加载。

      final restartCtx = globalState.navigatorKey.currentContext;
      if (restartCtx != null && restartCtx.mounted) {
        ScaffoldMessenger.of(restartCtx).showSnackBar(
          const SnackBar(content: Text('Core updated. Restart app to apply.')),
        );
      }
    }
  }
}

AndroidCoreUpdate? get androidCoreUpdate =>
    system.isAndroid ? AndroidCoreUpdate() : null;
