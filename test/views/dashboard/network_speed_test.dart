import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/dashboard/widgets/network_speed.dart';
import 'package:fl_clash/widgets/line_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

FixedList<Traffic> _traffics(List<Traffic> samples) {
  final traffics = FixedList<Traffic>(trafficSampleLength);
  for (final sample in samples) {
    traffics.add(sample);
  }
  return traffics;
}

void main() {
  Future<void> pumpCard(WidgetTester tester, List<Traffic> samples) async {
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        overrides: [
          trafficsProvider.overrideWithBuild((_, _) => _traffics(samples)),
        ],
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 520,
              child: DashboardWidgetMetrics(
                unitHeight: 120,
                child: const NetworkSpeed(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('upload and download each get their own line', (tester) async {
    await pumpCard(tester, const [
      Traffic(up: 1024, down: 4096),
      Traffic(up: 2048, down: 8192),
      Traffic(up: 1024, down: 16384),
    ]);

    final colorScheme = Theme.of(
      tester.element(find.byType(NetworkSpeed)),
    ).colorScheme;
    final canvas = find.descendant(
      of: find.byType(LineChart),
      matching: find.byType(CustomPaint),
    );

    expect(
      tester.renderObject(canvas),
      paints
        ..path(style: PaintingStyle.fill)
        ..path(color: colorScheme.tertiary, style: PaintingStyle.stroke)
        ..path(style: PaintingStyle.fill)
        ..path(color: colorScheme.primary, style: PaintingStyle.stroke),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header names both speeds', (tester) async {
    await pumpCard(tester, const [Traffic(up: 1024, down: 4096)]);

    expect(find.textContaining('↑', findRichText: true), findsOneWidget);
    expect(find.textContaining('↓', findRichText: true), findsOneWidget);
  });
}
