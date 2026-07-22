/// Core 版本选择对话框 + 共享下载进度工具。
///
/// 调用方：lib/views/dashboard/widgets/core_info.dart

import 'package:flutter/material.dart';

import '../../common/context.dart';
import '../../common/print.dart';
import '../../common/system.dart';
import '../../common/utils.dart';
import '../../core/androidCoreUpdate.dart';
import '../../core/desktopCoreUpdate.dart';
import '../enum/enum.dart';
import '../providers/CoreUpdate.dart';

/// 带进度条的下载弹窗 — Android / 桌面端共用。
///
/// [onDownload] 接收一个 [ValueNotifier] 用于刷新进度。
/// 成功时返回临时文件路径。失败时抛出 [Exception]，
/// 调用方应 catch 并显示 `'Download failed: $e'` 给用户。
Future<String?> showDownloadProgress(
  BuildContext ctx, {
  required Future<String?> Function(ValueNotifier<double> progress) onDownload,
}) async {
  final progressNotifier = ValueNotifier<double>(0.0);

  showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Downloading Core'),
      content: SizedBox(
        width: 300,
        child: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (_, progress, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress > 0 ? progress : null,
              ),
              const SizedBox(height: 8),
              Text('${(progress * 100).toStringAsFixed(1)}%'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final result = await onDownload(progressNotifier);
    if (ctx.mounted) Navigator.of(ctx).pop();
    return result;
  } on Exception catch (e) {
    if (ctx.mounted) Navigator.of(ctx).pop();
    commonPrint.log('Core download failed: $e', logLevel: LogLevel.warning);
    return Future.error(e);
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
  final data = coreUpdateData;
  if (data.releases.isEmpty) return;

  final currentVersion = data.currentVersion;
  int? selectedIndex;
  // 默认选中第一个比当前版本新的 release（如果存在）
  if (data.newerReleases.isNotEmpty) {
    selectedIndex = data.releases.indexOf(data.newerReleases.first);
  }
  if (selectedIndex == -1) selectedIndex = 0;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      int? localSelected = selectedIndex;

      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selected = localSelected ?? 0;
          final selectedTagName = selected < data.releases.length
              ? data.releases[selected].tagName
              : '';

          return AlertDialog(
            title: const Text('Core Update'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前版本信息
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
                              style: Theme.of(ctx).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 版本列表
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: data.releases.length,
                      itemBuilder: (_, index) {
                        final release = data.releases[index];
                        final isCurrent = release.version == currentVersion;
                        final isNewer =
                            currentVersion.isNotEmpty &&
                            utils.compareVersions(
                                  release.version,
                                  currentVersion,
                                ) >
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
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.primary,
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
            ),
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
          );
        },
      );
    },
  );
}
