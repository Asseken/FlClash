import 'package:fl_clash/core/core_update.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/constant.dart';
import '../../../common/context.dart';
import '../../../common/text.dart';
import '../../../widgets/card.dart';
import '../../../widgets/text.dart';
import 'core_update_dialog.dart';

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

          // 监听 core 更新状态，判断是否需要显示红点
          final coreUpdateData = ref.watch(coreUpdateProvider);
          final hasUpdate = coreUpdateData.hasUpdate;

          return CommonCard(
            onPressed: () async {
              // 点击 → 触发检查，然后弹出版本选择对话框
              await ref.read(coreUpdateProvider.notifier).check();
              // 重新读取最新数据
              final updatedData = ref.read(coreUpdateProvider);
              if (!context.mounted) return;
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
                        // 版本号 + 红点徽标
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
                            if (hasUpdate)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
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
