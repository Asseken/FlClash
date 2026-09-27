import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/core_update.dart';
import 'package:fluent_ui/fluent_ui.dart' show InfoBadge, ProgressBar;
import 'package:material_ui/material_ui.dart';

import 'dialog.dart';
import 'list.dart';

typedef CoreDownloadHandler =
    Future<String?> Function(
      ValueNotifier<double> progress,
      CancelToken cancelToken,
    );

/// Download dialog for a Core, completing with the downloaded path, with null
/// when the user cancelled, and with the download error otherwise.
Future<String?> showCoreDownloadProgress({
  required CoreDownloadHandler onDownload,
}) async {
  final result = Completer<String?>();
  unawaited(
    dialogs.showCommonDialog<void>(
      dismissible: false,
      child: _CoreDownloadDialog(onDownload: onDownload, result: result),
    ),
  );
  return result.future;
}

class _CoreDownloadDialog extends StatefulWidget {
  final CoreDownloadHandler onDownload;
  final Completer<String?> result;

  const _CoreDownloadDialog({required this.onDownload, required this.result});

  @override
  State<_CoreDownloadDialog> createState() => _CoreDownloadDialogState();
}

class _CoreDownloadDialogState extends State<_CoreDownloadDialog> {
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final CancelToken _cancelToken = CancelToken();

  @override
  void initState() {
    super.initState();
    unawaited(_download());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    try {
      final path = await widget.onDownload(_progress, _cancelToken);
      _close();
      widget.result.complete(path);
    } catch (error) {
      _close();
      if (error is DioException && error.type == DioExceptionType.cancel) {
        widget.result.complete(null);
      } else {
        widget.result.completeError(error);
      }
    }
  }

  void _close() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.coreUpdateDownloading,
      actions: [
        TextButton(
          onPressed: _cancelToken.cancel,
          child: Text(appLocalizations.cancel),
        ),
      ],
      child: ValueListenableBuilder<double>(
        valueListenable: _progress,
        builder: (_, value, _) {
          return Row(
            children: [
              Expanded(
                child: ProgressBar(
                  strokeWidth: 6,
                  value: value > 0 ? value * 100 : null,
                ),
              ),
              const SizedBox(width: 8),
              Text('${(value * 100).toStringAsFixed(1)}%'),
            ],
          );
        },
      ),
    );
  }
}

/// Version picker, resolving with the tag name the user chose, or null.
Future<String?> showCoreUpdateDialog(
  BuildContext context,
  CoreUpdateData data,
) {
  return dialogs.showCommonDialog<String>(
    context: context,
    child: _CoreUpdateDialog(data: data),
  );
}

class _CoreUpdateDialog extends StatefulWidget {
  final CoreUpdateData data;

  const _CoreUpdateDialog({required this.data});

  @override
  State<_CoreUpdateDialog> createState() => _CoreUpdateDialogState();
}

class _CoreUpdateDialogState extends State<_CoreUpdateDialog> {
  late int _selectedIndex = _initialIndex;

  int get _initialIndex {
    final newerReleases = widget.data.newerReleases;
    if (newerReleases.isEmpty) {
      return 0;
    }
    final index = widget.data.releases.indexOf(newerReleases.first);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final releases = widget.data.releases;
    final currentVersion = widget.data.currentVersion;
    return CommonDialog(
      title: appLocalizations.coreUpdate,
      overrideScroll: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(releases[_selectedIndex].tagName),
          child: Text(appLocalizations.goDownload),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentVersion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                '${appLocalizations.coreVersion}: v$currentVersion',
                style: context.textTheme.titleSmall,
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: releases.length,
              itemBuilder: (_, index) {
                final release = releases[index];
                final isCurrent = release.version == currentVersion;
                return CommonSelectedListItem(
                  isSelected: index == _selectedIndex,
                  onSelected: () => setState(() => _selectedIndex = index),
                  onPressed: () => setState(() => _selectedIndex = index),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          isCurrent
                              ? '${release.tagName} (${appLocalizations.coreVersion})'
                              : release.tagName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.data.newerReleases.contains(release)) ...[
                        const SizedBox(width: 8),
                        const InfoBadge(color: Color.fromARGB(255, 248, 6, 6)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
