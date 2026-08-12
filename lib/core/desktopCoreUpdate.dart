// 桌面端 Core 更新逻辑（Windows / macOS / Linux 共用）。
//
// 下载指定版本的桌面核心二进制并替换当前运行的文件。
// 需要先停止 core 进程才能替换，替换后提示用户重启应用。
//
// Android 端的对应实现在 [androidCoreUpdate.dart] 中。

import 'dart:ffi';
import 'dart:io';

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
  ///
  /// 流程：停止 core → 下载到临时文件 → 备份旧文件 → 替换 → 提示重启
  Future<bool> downloadAndReplace(String tagName, {String? downloadUrl}) async {
    if (!system.isDesktop) return false;

    final url = downloadUrl ?? _buildDownloadUrl(tagName);

    final ctx = globalState.navigatorKey.currentContext;
    if (ctx == null) return false;

    String? tmpPath;
    try {
      tmpPath = await showDownloadProgress(
        ctx,
        onDownload: (progressNotifier) async {
          final path = (await appPath.tempFilePath) + '.tmp';
          await request.dio.download(
            url,
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

  /// 执行二进制替换：停止 core → 备份 → 替换（带重试）→ 验证 → 重启 core
  Future<bool> _replaceCoreBinary(String tmpPath, String tagName) async {
    try {
      // 停止 core
      await coreController.stopListener();
      await coreController.shutdown(false);

      // 等待 core 进程完全退出（Windows 下 helper 异步杀进程）
      await Future.delayed(const Duration(seconds: 1));

      // 备份旧文件
      final coreExePath = appPath.corePath;
      final bakPath = '$coreExePath.bak';
      final coreFile = File(coreExePath);
      final hasBackup = await coreFile.exists();
      if (hasBackup) {
        await coreFile.copy(bakPath);
      }

      // 替换（Windows 下文件句柄可能未释放，加重试）
      await _retryFileOp(
        () async => File(tmpPath).copy(coreExePath),
        description: 'copy new core binary',
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 500),
      );

      // On macOS / Linux the copied file may lack the executable bit because the
      // download temp file has default umask permissions (644).  Process.start()
      // requires +x, so set it explicitly.  Windows ignores this (no-op).
      // We set the target even on the first successful attempt so that the
      // recovered backup (below) also gets +x if needed.
      await _ensureExecutable(coreExePath);

      // 清理临时文件
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        await File(tmpPath).safeDelete();
      } catch (_) {}

      // 验证替换后的文件存在且大小合理
      final newFile = File(coreExePath);
      if (!await newFile.exists()) {
        throw Exception('Replaced core binary is missing');
      }
      final newSize = await newFile.length();
      if (newSize < 1024 * 1024) {
        throw Exception('Replaced core binary is too small ($newSize bytes)');
      }

      // 重新启动 core
      final container = globalState.container;
      await container.read(coreActionProvider.notifier).connectCore();
      await container.read(coreActionProvider.notifier).initCore();
      if (container.read(isStartProvider)) {
        await container
            .read(setupActionProvider.notifier)
            .updateStatus(true, isInit: true);
      } else {
        await container
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);
      }

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
      try {
        final bakFile = File(bakPath);
        if (await bakFile.exists()) {
          await bakFile.copy(coreExePath);
          await _ensureExecutable(coreExePath);
          commonPrint.log(
            'Core update failed, restored backup: $e',
            logLevel: LogLevel.warning,
          );
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
        commonPrint.log(
          'chmod +x failed: $e',
          logLevel: LogLevel.warning,
        );
      }
    }
  }

  /// 在 core 未启动时（coreInfo 不可用），用 Dart 判断当前平台的 Go OS 名称
  String _hostGoos() {
    if (system.isWindows) return 'windows';
    if (system.isMacOS) return 'darwin';
    if (system.isLinux) return 'linux';
    return 'windows'; // unreachable
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
