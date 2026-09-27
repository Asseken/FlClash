import 'dart:async';

import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core_update.dart';
import 'package:fluent_ui/fluent_ui.dart' show InfoBadge;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/constant.dart';
import '../../../common/context.dart';
import '../../../common/dialog.dart';
import '../../../common/system.dart';
import '../../../common/text.dart';
import '../../../core/android_core_update.dart';
import '../../../core/desktop_core_update.dart';
import '../../../widgets/card.dart';
import '../../../widgets/core_update_dialog.dart';
import '../../../widgets/text.dart';

class ShowCoreInfo extends StatelessWidget {
  const ShowCoreInfo({super.key});

  Future<void> _handlePressed(BuildContext context, WidgetRef ref) async {
    await ref.read(coreUpdateProvider.notifier).check();
    if (!context.mounted) {
      return;
    }
    final coreUpdateData = ref.read(coreUpdateProvider);
    if (coreUpdateData.releases.isEmpty) {
      unawaited(
        dialogs.showMessage(
          title: context.appLocalizations.tip,
          message: TextSpan(
            text: context.appLocalizations.coreUpdateListFailed,
          ),
        ),
      );
      return;
    }
    final tagName = await showCoreUpdateDialog(context, coreUpdateData);
    if (tagName == null) {
      return;
    }
    if (system.isAndroid) {
      await androidCoreUpdate?.downloadAndReplace(tagName);
    } else {
      await desktopCoreUpdate?.downloadAndReplace(tagName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final height = getWidgetHeight(1);
    return SizedBox(
      height: height,
      child: Consumer(
        builder: (context, ref, _) {
          final coreInfo = ref.watch(coreVersionInfoDataProvider);
          final hasUpdate = ref.watch(
            coreUpdateProvider.select((state) => state.hasUpdate),
          );
          return CommonCard(
            onPressed: () => _handlePressed(context, ref),
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
                            // maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TooltipText(
                              text: Text(
                                '${coreInfo?.coreVersion}',
                                style: context.textTheme.bodySmall?.toLight
                                    .adjustSize(1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUpdate)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: InfoBadge(color: Color.fromARGB(
                                    255, 248, 6, 6),),
                              ),
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
