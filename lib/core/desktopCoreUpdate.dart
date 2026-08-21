import 'dart:ffi';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../common/app_localizations.dart';
import '../common/constant.dart';
import '../common/file.dart';
import '../common/path.dart';
import '../common/print.dart';
import '../common/request.dart';
import '../common/system.dart';
import '../enum/enum.dart';
import '../core/controller.dart';
import '../models/core.dart';
import '../providers/action.dart';
import '../providers/app.dart';
import '../providers/CoreUpdate.dart';
import '../providers/state.dart';
import '../state.dart';
import '../widgets/core_update_dialog.dart';

class DesktopCoreUpdate {
  static DesktopCoreUpdate? _instance;

  DesktopCoreUpdate._internal();

  factory DesktopCoreUpdate() {
    _instance ??= DesktopCoreUpdate._internal();
    return _instance!;
  }

  /// 下载并替换桌面端核心二进制（FlClashCore.exe 或 FlClashCore）。
  ///
  /// [tagName]  GitHub release 的 tag，如 "v1.9.30"
  /// [downloadUrl] 可直接指定下载地址；如果为 null 则自动拼接。
  Future<bool> downloadAndReplace(String tagName, {String? downloadUrl}) async {
    if (!system.isDesktop) return false;

    final url = downloadUrl ?? _buildDownloadUrl(tagName);

    final ctx = globalState.navigatorKey.currentContext;
    if (ctx == null) return false;

    String? tmpPath;
    try {
      tmpPath = await showDownloadProgress(
        ctx,
        onDownload: (progressNotifier, cancelToken) async {
          final path = (await appPath.tempFilePath) + '.tmp';
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
      return false;
    }

    if (tmpPath == null) return false;

    // 确认替换
    final shouldReplace = await globalState.showMessage(
      title: currentAppLocalizations.tip,
      message: TextSpan(
        text:
            'New Core Downloaded From $tagName.\n\n'
            'The Core Must Be Restarted To Apply The Update.\n'
            'Continue Now?',
      ),
      confirmText: currentAppLocalizations.confirm,
      cancelText: currentAppLocalizations.cancel,
    );

    if (shouldReplace != true) {
      await File(tmpPath).safeDelete();
      return false;
    }

    return _replaceCoreBinary(tmpPath, tagName);
  }

  /// 执行二进制替换：停止 core → 暂存新文件 → rename 原子替换 → 重启 core
  Future<bool> _replaceCoreBinary(String tmpPath, String tagName) async {
    try {
      await coreController.stopListener();
      await coreController.stop();

      // Windows 下 helper 异步杀进程，等待 core 进程完全退出
      await Future.delayed(const Duration(seconds: 1));

      final coreExePath = appPath.corePath;
      final bakPath = '$coreExePath.bak';
      final stagingPath = '$coreExePath.new';

      // 同目录暂存新二进制（同文件系统），chmod + 校验通过后才进入替换。
      // 这样正式文件永远不会出现"写了一半"的中间态。
      await _retryFileOp(
        () async => File(tmpPath).copy(stagingPath),
        description: 'stage new core binary',
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 500),
      );

      // On macOS / Linux the copied file may lack the executable bit because the
      // download temp file has default umask permissions (644).  Process.start()
      // requires +x, so set it explicitly.  Windows ignores this (no-op).
      await _ensureExecutable(stagingPath);
      final stagingSize = await File(stagingPath).length();
      if (stagingSize < 1024 * 1024) {
        throw Exception('Staged core binary is too small ($stagingSize bytes)');
      }

      // 原子替换：旧文件先挪到 .bak，再把暂存文件 rename 成正式名
      final coreFile = File(coreExePath);
      if (await coreFile.exists()) {
        await _retryFileOp(
          () async {
            await File(bakPath).safeDelete();
            await coreFile.rename(bakPath);
          },
          description: 'move current core to backup',
          maxRetries: 3,
          retryDelay: const Duration(milliseconds: 500),
        );
      }
      await _retryFileOp(
        () async => File(stagingPath).rename(coreExePath),
        description: 'move staged core into place',
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 500),
      );

      // 清理临时文件与备份（失败不影响已完成的替换）
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        await File(tmpPath).safeDelete();
        await File(bakPath).safeDelete();
      } catch (_) {}

      // 重新启动 core
      final container = globalState.container;
      final restarted = await container
          .read(coreActionProvider.notifier)
          .startCore();
      if (!restarted) {
        // startCore 内部已吞掉异常并提示，这里抛出让外层恢复备份、不显示成功
        throw Exception('Core restart failed after update');
      }
      if (container.read(isStartProvider)) {
        await container
            .read(setupActionProvider.notifier)
            .setRunning(true, initialize: true);
      } else {
        await container
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);
      }

      // 运行版本已更新，重算更新状态让红点及时消失
      container.read(coreUpdateProvider.notifier).refreshCurrentVersion();

      // 提示更新完成
      final restartCtx = globalState.navigatorKey.currentContext;
      if (restartCtx != null && restartCtx.mounted) {
        globalState.showMessage(
          title: currentAppLocalizations.tip,
          message: const TextSpan(
            text:
                'Core Updated And Reloaded Successfully.\n'
                'We Recommend Restarting The App For The Best Experience.',
          ),
          confirmText: currentAppLocalizations.confirm,
        );
      }
      return true;
    } catch (e) {
      // 尝试恢复备份
      final coreExePath = appPath.corePath;
      final bakPath = '$coreExePath.bak';
      final stagingPath = '$coreExePath.new';
      try {
        final bakFile = File(bakPath);
        if (await bakFile.exists()) {
          await File(stagingPath).safeDelete();
          await bakFile.rename(coreExePath);
          commonPrint.log(
            'Core update failed, restored backup: $e',
            logLevel: LogLevel.warning,
          );
        } else {
          await File(stagingPath).safeDelete();
        }
      } catch (restoreErr) {
        commonPrint.log(
          'Failed to restore core backup: $restoreErr',
          logLevel: LogLevel.error,
        );
      }

      try {
        await File(tmpPath).safeDelete();
      } catch (_) {}

      await globalState.showMessage(
        title: currentAppLocalizations.tip,
        message: TextSpan(text: 'Failed to replace core: $e'),
        confirmText: currentAppLocalizations.confirm,
      );
      return false;
    }
  }

  /// 根据 tagName 构建对应的下载 URL。
  ///
  /// GitHub Releases 命名规则：{goos}-{goarch}-FlClashCore{ext}
  /// goos:  darwin / linux / windows
  /// goarch: amd64 / arm64
  /// ext:    .exe（Windows），其他系统无扩展名
  ///
  /// 优先根据当前运行 core 的 goOs/goArch 匹配；回退到 Dart 判断当前平台。
  String _buildDownloadUrl(String tagName) {
    coreVersionInfo? coreInfo;
    try {
      if (globalState.isAttach) {
        coreInfo = globalState.container.read(coreVersionInfoDataProvider);
      }
    } catch (_) {
      // container 可能尚未初始化 — 允许回退
    }
    final goos = coreInfo?.goOs ?? _hostGoos();
    final goarch = coreInfo?.goArch ?? _hostGoarch();
    final ext = goos == 'windows' ? '.exe' : '';
    return 'https://github.com/$coreRepository/releases/download/$tagName/$goos-$goarch-FlClashCore$ext';
  }

  /// 带重试的文件操作，用于应对 Windows 下文件句柄延迟释放。
  static Future<void> _retryFileOp(
    Future<void> Function() op, {
    required String description,
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await op();
        return;
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        commonPrint.log(
          '_retryFileOp [$description] attempt ${attempt + 1} failed, retrying: $e',
          logLevel: LogLevel.debug,
        );
        await Future.delayed(retryDelay);
      }
    }
  }

  /// Set the executable permission bits (owner + group + other) on [path].
  /// No-op on Windows — `Process.start` on Windows uses the file extension,
  /// not the POSIX executable bit.
  static Future<void> _ensureExecutable(String path) async {
    if (!system.isWindows) {
      try {
        final result = await Process.run('chmod', ['+x', path]);
        if (result.exitCode != 0) {
          commonPrint.log(
            'chmod +x failed (exit ${result.exitCode}): ${result.stderr}',
            logLevel: LogLevel.warning,
          );
        }
      } catch (e) {
        commonPrint.log('chmod +x failed: $e', logLevel: LogLevel.warning);
      }
    }
  }

  /// 在 core 未启动时（coreInfo 不可用），用 Dart 判断当前平台的 Go OS 名称
  String _hostGoos() {
    if (system.isWindows) return 'windows';
    if (system.isMacOS) return 'darwin';
    if (system.isLinux) return 'linux';
    return 'windows';
  }

  /// 在 core 未启动时，用 Dart 判断当前主机的 Go arch 名称
  String _hostGoarch() {
    // Dart 没有直接获取 GOARCH 的能力，用 Abi 推断
    if (Abi.current() == Abi.linuxX64 ||
        Abi.current() == Abi.macosX64 ||
        Abi.current() == Abi.windowsX64) {
      return 'amd64';
    }
    if (Abi.current() == Abi.linuxArm64 ||
        Abi.current() == Abi.macosArm64 ||
        Abi.current() == Abi.windowsArm64) {
      return 'arm64';
    }
    // 未知 ABI — 回退到 amd64 但记录警告
    commonPrint.log(
      'DesktopCoreUpdate: Unknown Dart ABI: ${Abi.current()}, defaulting to amd64',
      logLevel: LogLevel.warning,
    );
    return 'amd64';
  }
}

/// 平台条件 getter：非桌面端返回 null
DesktopCoreUpdate? get desktopCoreUpdate =>
    system.isDesktop ? DesktopCoreUpdate() : null;
