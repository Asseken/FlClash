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
import '../common/file.dart';
import '../common/path.dart';
import '../common/request.dart';
import '../common/system.dart';
import '../core/controller.dart';
import '../models/core.dart';
import '../providers/action.dart';
import '../providers/app.dart';
import '../providers/state.dart';
import '../state.dart';

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

    // 确定下载 URL
    final url = downloadUrl ?? _buildDownloadUrl(tagName);

    // 显示下载进度
    final progressNotifier = ValueNotifier<double>(0.0);
    final ctx = globalState.navigatorKey.currentContext;
    if (ctx == null) return false;

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

    final tmpPath = (await appPath.tempFilePath) + '.tmp';
    try {
      await request.dio.download(
        url,
        tmpPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progressNotifier.value = received / total;
          }
        },
      );
    } catch (e) {
      if (ctx.mounted) Navigator.of(ctx).pop();
      await globalState.showMessage(
        title: currentAppLocalizations.tip,
        message: TextSpan(text: 'Download failed: $e'),
        confirmText: currentAppLocalizations.confirm,
      );
      return false;
    }

    if (ctx.mounted) Navigator.of(ctx).pop();

    // 确认替换
    final shouldReplace = await globalState.showMessage(
      title: currentAppLocalizations.tip,
      message: TextSpan(
        text:
            'New core downloaded from $tagName.\n\n'
            'The app must be restarted to apply the update.\n'
            'Continue now?',
      ),
      confirmText: currentAppLocalizations.confirm,
      cancelText: currentAppLocalizations.cancel,
    );

    if (shouldReplace != true) {
      await File(tmpPath).safeDelete();
      return false;
    }

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
      if (await coreFile.exists()) {
        await coreFile.copy(bakPath);
      }

      // 替换
      final tmpFile = File(tmpPath);
      await tmpFile.copy(coreExePath);

      // 清理临时文件（加小延迟确保 copy 句柄已释放）
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        await tmpFile.safeDelete();
      } catch (_) {
        // 忽略删除失败，临时文件不影响功能
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

      // 提示重启
      final restartCtx = globalState.navigatorKey.currentContext;
      if (restartCtx != null && restartCtx.mounted) {
        ScaffoldMessenger.of(restartCtx).showSnackBar(
          const SnackBar(content: Text('Core updated. Restart app to apply.')),
        );
      }
      return true;
    } catch (e) {
      try {
        await File(tmpPath).safeDelete();
      } catch (_) {
        // 忽略删除失败
      }
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
      coreInfo = globalState.container.read(coreVersionInfoDataProvider);
    } catch (_) {
      // container 可能尚未初始化
    }
    final goos = coreInfo?.goOs ?? _hostGoos();
    final goarch = coreInfo?.goArch ?? _hostGoarch();
    final ext = goos == 'windows' ? '.exe' : '';
    return 'https://github.com/${Request.coreRepository}/releases/download/$tagName/$goos-$goarch-FlClashCore$ext';
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
    // 默认 amd64（最通用的桌面架构）
    return 'amd64';
  }
}

/// 平台条件 getter：非桌面端返回 null
DesktopCoreUpdate? get desktopCoreUpdate =>
    system.isDesktop ? DesktopCoreUpdate() : null;
