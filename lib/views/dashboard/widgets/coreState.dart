import 'package:fl_clash/core/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/constant.dart';
import '../../../common/context.dart';
import '../../../common/text.dart';
import '../../../enum/enum.dart';
import '../../../providers/action.dart';
import '../../../providers/app.dart';
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
          // final coreStatus = ref.read(coreStatusProvider);
          return CommonCard(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: InkWell(
                        onTap: () async {
                          final isDisconnected =
                              ref.read(coreStatusProvider) ==
                              CoreStatus.disconnected;
                          ref.read(coreStatusProvider.notifier).value =
                              CoreStatus.disconnected;
                          await coreController.shutdown(!isDisconnected);
                        },
                        child: TooltipText(
                          text: Text(
                            appLocalizations.coreStop,
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
                          globalState.container
                              .read(coreActionProvider.notifier)
                              .tryStartCore();
                        },
                        child: TooltipText(
                          text: Text(
                            appLocalizations.coreStart,
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
                        onTap: () {
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
