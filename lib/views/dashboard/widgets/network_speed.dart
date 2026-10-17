import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _minSpeedScale = 8 * 1024.0;

class NetworkSpeed extends StatelessWidget {
  const NetworkSpeed({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final color = context.colorScheme.onSurfaceVariant.opacity80;
    return SizedBox(
      height: DashboardWidgetMetrics.heightOf(context, 2),
      child: RepaintBoundary(
        child: CommonCard(
          radius: DashboardWidgetMetrics.radiusOf(context),
          onPressed: () {},
          child: Consumer(
            builder: (_, ref, _) {
              final traffics = ref.watch(trafficsProvider);
              final traffic = traffics.list.safeLast(const Traffic());
              final colorScheme = context.colorScheme;
              return Column(
                children: [
                  Padding(
                    padding: DashboardWidgetMetrics.paddingOf(
                      context,
                    ).copyWith(bottom: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: InfoHeader(
                            padding: EdgeInsets.zero,
                            info: Info(
                              label: appLocalizations.networkSpeed,
                              glyph: AppGlyphs.speed,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '↑ ${traffic.up.traffic.show}/s',
                                style: TextStyle(color: colorScheme.tertiary),
                              ),
                              TextSpan(
                                text: '   ↓ ${traffic.down.traffic.show}/s',
                                style: TextStyle(color: colorScheme.primary),
                              ),
                            ],
                          ),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16,
                      ).copyWith(bottom: 0, left: 0, right: 0),
                      child: LineChart(
                        values: [
                          for (final traffic in traffics.list)
                            traffic.down.toDouble(),
                        ],
                        secondaryValues: [
                          for (final traffic in traffics.list)
                            traffic.up.toDouble(),
                        ],
                        revision: traffics.revision,
                        capacity: traffics.maxLength,
                        minScale: _minSpeedScale,
                        color: colorScheme.primary,
                        secondaryColor: colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
