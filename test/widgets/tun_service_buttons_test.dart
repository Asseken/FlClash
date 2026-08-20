import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widgets/quick_options.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpTunButton(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1000, 800));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: fluent.FluentTheme(
          data: fluent.FluentThemeData(brightness: Brightness.light),
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              fluent.FluentLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            builder: (context, child) {
              globalState.measure = Measure.of(context, 1);
              globalState.theme = CommonTheme.of(context, 1);
              return child!;
            },
            home: Scaffold(body: TUNButton()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'TUN enable gates service buttons and prompts install',
    skip: !system.isWindows,
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpTunButton(tester, container);

      IconButton installButton() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, fluent.WindowsIcons.settings),
      );
      IconButton uninstallButton() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, fluent.WindowsIcons.delete),
      );

      expect(installButton().onPressed, isNotNull);

      // Toggling TUN on without the service prompts the install; cancelling
      // keeps the switch off.
      await tester.tap(find.byType(fluent.ToggleSwitch));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Install Service'), findsOneWidget);
      expect(container.read(patchClashConfigProvider).tun.enable, isFalse);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(patchClashConfigProvider).tun.enable, isFalse);
      expect(installButton().onPressed, isNotNull);

      // TUN on disables both service buttons.
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith.tun(enable: true));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(installButton().onPressed, isNull);
      expect(uninstallButton().onPressed, isNull);

      // TUN off re-enables the install button.
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith.tun(enable: false));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(installButton().onPressed, isNotNull);

      await tester.pump(const Duration(seconds: 5));
    },
  );
}
