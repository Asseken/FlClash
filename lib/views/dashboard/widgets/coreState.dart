import 'package:fl_clash/core/controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/constant.dart';
import '../../../common/context.dart';
import '../../../common/text.dart';
import '../../../core/androidCoreUpdate.dart';
import '../../../enum/enum.dart';
import '../../../models/common.dart';
import '../../../providers/action.dart';
import '../../../providers/app.dart';
import '../../../providers/state.dart';
import '../../../state.dart';
import '../../../widgets/card.dart';
import '../../../widgets/text.dart';

class CoreState extends StatefulWidget {
  const CoreState({super.key});

  @override
  State<CoreState> createState() => _CoreStateState();
}

class _CoreStateState extends State<CoreState> {
  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: Consumer(
        builder: (_, ref, _) {
          final coreStatus = ref.watch(coreStatusProvider);
          final stopDisabled = coreStatus == CoreStatus.disconnected;
          final startDisabled = coreStatus == CoreStatus.connected;
          return CommonCard(
            onPressed: () async {
              await androidCoreUpdate?.autoCheckCoreUpdate();
            },
            info: Info(
              label: appLocalizations.coreStatus,
              iconData: WindowsIcons.default_a_p_n,
            ),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: InkWell(
                        onTap: stopDisabled
                            ? () async {
                                await globalState.showMessage(
                                  message: TextSpan(
                                    text: appLocalizations.disconnected,
                                  ),
                                );
                              }
                            : () async {
                                await coreController.stopListener();
                                final isDisconnected =
                                    ref.read(coreStatusProvider) ==
                                    CoreStatus.disconnected;
                                ref.read(coreStatusProvider.notifier).value =
                                    CoreStatus.disconnected;
                                await coreController.shutdown(!isDisconnected);
                                ref.read(trafficsProvider.notifier).clear();
                                ref
                                    .read(trafficsProvider.notifier)
                                    .addTraffic(const Traffic());
                              },
                        child: TooltipText(
                          text: Text(
                            stopDisabled
                                ? appLocalizations.disconnected
                                : appLocalizations.coreStop,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: InkWell(
                        onTap: startDisabled
                            ? () async {
                                await globalState.showMessage(
                                  message: TextSpan(
                                    text: appLocalizations.connected,
                                  ),
                                );
                              }
                            : () async {
                                await globalState.container
                                    .read(coreActionProvider.notifier)
                                    .connectCore();
                                await globalState.container
                                    .read(coreActionProvider.notifier)
                                    .initCore();
                                if (ref.read(isStartProvider)) {
                                  await ref
                                      .read(setupActionProvider.notifier)
                                      .updateStatus(true, isInit: true);
                                } else {
                                  await ref.read(setupActionProvider.notifier).applyProfile(force: true);
                                }
                              },
                        child: TooltipText(
                          text: Text(
                            startDisabled
                                ? appLocalizations.connected
                                : appLocalizations.coreStart,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: InkWell(
                        onTap: () async {
                          final coreStatus = ref.read(coreStatusProvider);
                          if (coreStatus == CoreStatus.connecting) {
                            return;
                          }
                          final tip = coreStatus == CoreStatus.connected
                              ? context.appLocalizations.forceRestartCoreTip
                              : context.appLocalizations.restartCoreTip;
                          final res = await globalState.showMessage(
                            message: TextSpan(text: tip),
                          );
                          if (res != true) {
                            return;
                          }
                          globalState.container
                              .read(coreActionProvider.notifier)
                              .restartCore();
                        },
                        child: TooltipText(
                          text: Text(
                            appLocalizations.coreRestart,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
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
