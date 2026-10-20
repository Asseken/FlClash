import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/traffic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<(BuildContext, BuildContext)> _pumpContexts(WidgetTester tester) async {
  late BuildContext plain;
  late BuildContext wallpapered;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          plain = context;
          return WallpaperScope(
            enabled: true,
            child: Builder(
              builder: (context) {
                wallpapered = context;
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    ),
  );
  return (plain, wallpapered);
}

void main() {
  testWidgets('a wallpaper drops the card shadow that reads as a black card', (
    tester,
  ) async {
    final (plain, wallpapered) = await _pumpContexts(tester);

    expect(DashboardShadows.e1(plain), isNotEmpty);
    expect(
      DashboardShadows.e1(wallpapered),
      isEmpty,
      reason:
          'the fill is transparent under the wallpaper, so the shadow '
          'meant to sit behind it showed through as a black block',
    );
    expect(DashboardShadows.e2(plain), isNotEmpty);
    expect(DashboardShadows.e2(wallpapered), isEmpty);
  });

  testWidgets('the two traffic lines take different hues', (tester) async {
    final (context, _) = await _pumpContexts(tester);
    final colorScheme = context.colorScheme;

    expect(
      TrafficDirection.upload.colorOf(context),
      isNot(TrafficDirection.download.colorOf(context)),
      reason: 'one hue lighter than the other read as the same line',
    );
    expect(TrafficDirection.download.colorOf(context), colorScheme.primary);
    expect(TrafficDirection.upload.colorOf(context), colorScheme.tertiary);
  });
}
