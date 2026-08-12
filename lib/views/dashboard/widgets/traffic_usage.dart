import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../enum/enum.dart';
import '../../../providers/config.dart';

class TrafficUsage extends StatelessWidget {
  const TrafficUsage({super.key});

  Widget _buildTrafficDataItem(
    BuildContext context,
    Icon icon,
    num trafficValue,
    view,
  ) {
    return view == ViewMode.desktop
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: 2),
                    Flexible(
                      flex: 1,
                      child: Text(
                        trafficValue.traffic.value,
                        style: context.textTheme.bodyMedium,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trafficValue.traffic.unit,
                style: context.textTheme.bodyMedium,
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    icon,
                    // const SizedBox(width: 4),
                    Flexible(
                      flex: 1,
                      child: Text(
                        trafficValue.traffic.value,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontSize:
                              (context.textTheme.bodySmall?.fontSize ?? 12) -
                              2.2,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trafficValue.traffic.unit,
                style: context.textTheme.bodySmall?.copyWith(
                  fontSize: (context.textTheme.bodySmall?.fontSize ?? 12) - 2.2,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final primaryColor = globalState.theme.darken3PrimaryContainer;
    final secondaryColor = globalState.theme.darken2SecondaryContainer;
    return SizedBox(
      height: getWidgetHeight(2),
      child: RepaintBoundary(
        child: CommonCard(
          info: Info(
            label: appLocalizations.trafficUsage,
            iconData: FluentIcons.donut_chart,
          ),
          onPressed: () {},
          child: Consumer(
            builder: (_, ref, _) {
              final totalTraffic = ref.watch(totalTrafficProvider);
              final upTotalTrafficValue = totalTraffic.up;
              final downTotalTrafficValue = totalTraffic.down;
              final totalDirectTraffic = ref.watch(
                totalDirectTrafficProviderProvider,
              );
              final upTotalDirectTrafficValue = totalDirectTraffic.up;
              final downTotalDirectTrafficValue = totalDirectTraffic.down;
              final appSetting = ref.watch(appSettingProvider);
              final bool isOnlyStatProxy = appSetting.onlyStatisticsProxy;
              final view = ref.watch(viewModeProvider);
              // 第二行：isOnlyStatProxy=false 时显示 Proxy 流量（Total - Direct），true 时显示 Direct 流量
              final secondUp = isOnlyStatProxy
                  ? upTotalDirectTrafficValue
                  : upTotalTrafficValue - upTotalDirectTrafficValue;
              final secondDown = isOnlyStatProxy
                  ? downTotalDirectTrafficValue
                  : downTotalTrafficValue - downTotalDirectTrafficValue;
              return Padding(
                padding: baseInfoEdgeInsets.copyWith(top: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Container(
                        padding: view == ViewMode.desktop
                            ? const EdgeInsets.symmetric(vertical: 6)
                            : const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: DonutChart(
                                data: [
                                  DonutChartData(
                                    value: upTotalTrafficValue.toDouble(),
                                    color: primaryColor,
                                  ),
                                  DonutChartData(
                                    value: downTotalTrafficValue.toDouble(),
                                    color: secondaryColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: LayoutBuilder(
                                builder: (_, container) {
                                  final uploadText = Text(
                                    maxLines: 1,
                                    appLocalizations.upload,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.bodySmall,
                                  );
                                  final downloadText = Text(
                                    maxLines: 1,
                                    appLocalizations.download,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.bodySmall,
                                  );
                                  final uploadTextSize = globalState.measure
                                      .computeTextSize(uploadText);
                                  final downloadTextSize = globalState.measure
                                      .computeTextSize(downloadText);
                                  final maxTextWidth = max(
                                    uploadTextSize.width,
                                    downloadTextSize.width,
                                  );
                                  if (maxTextWidth + 24 > container.maxWidth) {
                                    return Container();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 8,
                                            decoration: ShapeDecoration(
                                              color: primaryColor,
                                              shape: RoundedSuperellipseBorder(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            maxLines: 1,
                                            appLocalizations.upload,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 8,
                                            decoration: ShapeDecoration(
                                              color: secondaryColor,
                                              shape: RoundedSuperellipseBorder(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            maxLines: 1,
                                            appLocalizations.download,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    view == ViewMode.desktop
                        ? Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  isOnlyStatProxy
                                      ? Text(
                                          'Proxy:',
                                          style: context.textTheme.bodyMedium,
                                        )
                                      : Text(
                                          'Total:',
                                          style: context.textTheme.bodyMedium,
                                        ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: _buildTrafficDataItem(
                                      context,
                                      Icon(
                                        Icons.arrow_upward,
                                        color: primaryColor,
                                        size: 14,
                                      ),
                                      upTotalTrafficValue,
                                      view,
                                    ),
                                  ),
                                  Flexible(
                                    child: _buildTrafficDataItem(
                                      context,
                                      Icon(
                                        Icons.arrow_downward,
                                        color: secondaryColor,
                                        size: 14,
                                      ),
                                      downTotalTrafficValue,
                                      view,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    isOnlyStatProxy ? 'Direct:' : 'Proxy:',
                                    style: context.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(width: 1),
                                  Flexible(
                                    child: _buildTrafficDataItem(
                                      context,
                                      Icon(
                                        Icons.arrow_upward,
                                        color: primaryColor,
                                        size: 14,
                                      ),
                                      secondUp,
                                      view,
                                    ),
                                  ),
                                  Flexible(
                                    child: _buildTrafficDataItem(
                                      context,
                                      Icon(
                                        Icons.arrow_downward,
                                        color: secondaryColor,
                                        size: 14,
                                      ),
                                      secondDown,
                                      view,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  isOnlyStatProxy
                                      ? Text(
                                          'P',
                                          style: context.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: 'monospace',
                                                fontSize:
                                                    (context
                                                            .textTheme
                                                            .bodySmall
                                                            ?.fontSize ??
                                                        12) -
                                                    2.2,
                                              ),
                                        )
                                      : Text(
                                          'T',
                                          style: context.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: 'monospace',
                                                fontSize:
                                                    (context
                                                            .textTheme
                                                            .bodySmall
                                                            ?.fontSize ??
                                                        12) -
                                                    2.2,
                                              ),
                                        ),
                                  Flexible(
                                    child: _buildTrafficDataItem(
                                      context,
                                      Icon(
                                        Icons.arrow_upward,
                                        color: primaryColor,
                                        size: 13,
                                      ),
                                      upTotalTrafficValue,
                                      view,
                                    ),
                                  ),
                                  Flexible(
                                    child: _buildTrafficDataItem(
                                      context,
                                      Icon(
                                        Icons.arrow_downward,
                                        color: secondaryColor,
                                        size: 13,
                                      ),
                                      downTotalTrafficValue,
                                      view,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    isOnlyStatProxy ? 'D' : 'P',
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(
                                          fontFamily: 'monospace',
                                          fontSize:
                                              (context
                                                      .textTheme
                                                      .bodySmall
                                                      ?.fontSize ??
                                                  12) -
                                              2.2,
                                        ),
                                  ),
                                  Flexible(
                                    child: _buildTrafficDataItem(
                                      context,
                                      Icon(
                                        Icons.arrow_upward,
                                        color: primaryColor,
                                        size: 13,
                                      ),
                                      secondUp,
                                      view,
                                    ),
                                  ),
                                  Flexible(
                                    child: _buildTrafficDataItem(
                                      context,
                                      Icon(
                                        Icons.arrow_downward,
                                        color: secondaryColor,
                                        size: 13,
                                      ),
                                      secondDown,
                                      view,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
