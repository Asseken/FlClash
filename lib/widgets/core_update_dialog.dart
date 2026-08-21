/// Core 版本选择对话框 + 共享下载进度工具。

import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Colors;
import 'package:flutter/material.dart';

import '../../common/context.dart';
import '../../common/print.dart';
import '../../common/system.dart';
import '../../common/utils.dart';
import '../../core/androidCoreUpdate.dart';
import '../../core/desktopCoreUpdate.dart';
import '../../state.dart';
import '../enum/enum.dart';
import '../providers/CoreUpdate.dart';
import 'dialog.dart';

/// 将下载异常映射为面向用户的简短描述。
String describeDownloadError(Object error) {
  if (error is! DioException) return 'Download failed.';
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'Download timed out.',
    DioExceptionType.badResponse =>
      'Download failed (HTTP ${error.response?.statusCode ?? '?'}).',
    DioExceptionType.connectionError => 'Network connection failed.',
    DioExceptionType.cancel => 'Download cancelled.',
    _ => 'Download failed.',
  };
}

/// 带进度条的下载弹窗 — Android / 桌面端共用。
///
/// [onDownload] 接收一个 [ValueNotifier] 用于刷新进度，以及一个 [CancelToken]
/// 用于取消下载（点击弹窗的 Cancel 按钮触发）。
/// 成功时返回临时文件路径；用户取消时返回 null；
/// 其他失败抛出 [Exception]，调用方应 catch 并显示 `'Download failed: $e'`。
Future<String?> showDownloadProgress(
  BuildContext ctx, {
  required Future<String?> Function(
    ValueNotifier<double> progress,
    CancelToken cancelToken,
  )
  onDownload,
}) async {
  final progressNotifier = ValueNotifier<double>(0.0);
  final cancelToken = CancelToken();
  BuildContext? dialogContext;

  void closeDialog() {
    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.of(dialogContext!).pop();
    }
  }

  globalState.showCommonDialog<void>(
    context: ctx,
    dismissible: false,
    child: Builder(
      builder: (dialogCtx) {
        dialogContext = dialogCtx;
        return PopScope(
          canPop: false,
          child: CommonDialog(
            title: 'Downloading Core',
            actions: [
              TextButton(
                onPressed: () => cancelToken.cancel(),
                child: const Text('Cancel'),
              ),
            ],
            child: ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (_, progress, _) => Row(
                children: [
                  Expanded(
                    child: ProgressBar(
                      strokeWidth: 6,
                      value: progress > 0
                          ? (progress * 100).clamp(0.0, 100.0)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text('${(progress * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  try {
    final result = await onDownload(progressNotifier, cancelToken);
    closeDialog();
    return result;
  } on Exception catch (e) {
    closeDialog();
    if (e is DioException && e.type == DioExceptionType.cancel) {
      return null;
    }
    commonPrint.log('Core download failed: $e', logLevel: LogLevel.warning);
    rethrow;
  }
}

/// 显示核心更新版本选择对话框。
///
/// [coreUpdateData] 来自 coreUpdateProvider，包含 release 列表和当前版本信息。
Future<void> showCoreUpdateDialog(
  BuildContext context,
  CoreUpdateData coreUpdateData,
) async {
  final appLocalizations = context.appLocalizations;
  if (coreUpdateData.releases.isEmpty) return;

  final currentVersion = coreUpdateData.currentVersion;
  int? selectedIndex;
  // 默认选中第一个比当前版本新的 release（如果存在）
  if (coreUpdateData.newerReleases.isNotEmpty) {
    selectedIndex = coreUpdateData.releases.indexOf(
      coreUpdateData.newerReleases.first,
    );
  }
  if (selectedIndex == -1) selectedIndex = 0;
  int? localSelected = selectedIndex;

  await globalState.showCommonDialog<void>(
    context: context,
    child: StatefulBuilder(
      builder: (ctx, setDialogState) {
        final selected = localSelected ?? 0;
        final selectedTagName = selected < coreUpdateData.releases.length
            ? coreUpdateData.releases[selected].tagName
            : '';

        return CommonDialog(
          title: 'Core Update',
          overrideScroll: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: selectedTagName.isEmpty
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      if (system.isAndroid) {
                        await androidCoreUpdate?.downloadAndReplace(
                          selectedTagName,
                        );
                      } else if (system.isDesktop) {
                        await desktopCoreUpdate?.downloadAndReplace(
                          selectedTagName,
                        );
                      }
                    },
              child: Text(appLocalizations.goDownload),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentVersion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text.rich(
                    TextSpan(
                      text: '${appLocalizations.coreVersion}: ',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'v$currentVersion',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: coreUpdateData.releases.length,
                  itemBuilder: (_, index) {
                    final release = coreUpdateData.releases[index];
                    final isCurrent = release.version == currentVersion;
                    final isNewer =
                        currentVersion.isNotEmpty &&
                        utils.compareVersions(release.version, currentVersion) >
                            0;

                    return RadioListTile<int>(
                      value: index,
                      groupValue: selected,
                      toggleable: false,
                      selected: selected == index,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              release.tagName,
                              style: Theme.of(ctx).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(${appLocalizations.coreVersion})',
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(ctx).colorScheme.primary,
                                  ),
                            ),
                          ],
                          if (isNewer) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: release.body.isNotEmpty
                          ? Text(
                              release.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(ctx).textTheme.bodySmall,
                            )
                          : null,
                      onChanged: (value) {
                        setDialogState(() => localSelected = value);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
