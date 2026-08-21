import 'package:fl_clash/providers/app.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Colors;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/constant.dart';
import '../../../common/context.dart';
import '../../../common/text.dart';
import '../../../providers/CoreUpdate.dart';
import '../../../state.dart';
import '../../../widgets/card.dart';
import '../../../widgets/core_update_dialog.dart';
import '../../../widgets/text.dart';

class ShowCoreInfo extends StatelessWidget {
  const ShowCoreInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final height = getWidgetHeight(1);
    return SizedBox(
      height: height,
      child: Consumer(
        builder: (_, ref, _) {
          final coreInfo = ref.watch(coreVersionInfoDataProvider);
          final coreUpdateData = ref.watch(coreUpdateProvider);
          final hasUpdate = coreUpdateData.hasUpdate;
          return CommonCard(
            onPressed: () async {
              final coreUpdateNotifier = ref.read(coreUpdateProvider.notifier);
              await coreUpdateNotifier.check();
              if (!context.mounted) return;
              final updatedData = ref.read(coreUpdateProvider);
              if (updatedData.releases.isEmpty) {
                globalState.showMessage(
                  title: appLocalizations.tip,
                  message: const TextSpan(
                    text: 'Failed to fetch core releases.',
                  ),
                  confirmText: appLocalizations.confirm,
                );
                return;
              }
              await showCoreUpdateDialog(context, updatedData);
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TooltipText(
                          text: Text(
                            appLocalizations.coreName,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TooltipText(
                          text: Text(
                            '${coreInfo?.mihoName}',
                            style: context.textTheme.bodySmall?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TooltipText(
                          text: Text(
                            appLocalizations.coreVersion,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TooltipText(
                              text: Text(
                                coreInfo?.coreVersion ?? '',
                                style: context.textTheme.bodySmall?.toLight
                                    .adjustSize(1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUpdate) const InfoBadge(color: Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TooltipText(
                          text: Text(
                            appLocalizations.RunOs,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            // maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TooltipText(
                          text: Text(
                            '${coreInfo?.goOs}-${coreInfo?.goArch}',
                            style: context.textTheme.bodySmall?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
