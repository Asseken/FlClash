import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/core_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _TestCoreAction extends CoreAction {
  int restartCount = 0;

  @override
  Future<void> restartCore() async {
    restartCount++;
  }
}

void main() {
  testWidgets('duplicate crash events disconnect the core only once', (
    tester,
  ) async {
    CoreEventManager.resetInstance();
    final coreInterface = _MockCoreHandlerInterface();
    when(() => coreInterface.stopLog()).thenAnswer((_) {});
    final controller = CoreController.test(coreInterface);
    final container = ProviderContainer(
      overrides: [coreActionProvider.overrideWith(_TestCoreAction.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CoreManager(controller: controller, child: const SizedBox()),
        ),
      ),
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    final transitions = <CoreStatus>[];
    final subscription = container.listen<CoreStatus>(
      coreStatusProvider,
      (_, next) => transitions.add(next),
    );
    addTearDown(subscription.close);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    const crash = CoreEvent(type: CoreEventType.crash, data: 'boom');
    coreEventManager.sendEvent(crash);
    coreEventManager.sendEvent(crash);
    await tester.pump();

    expect(container.read(coreStatusProvider), CoreStatus.disconnected);
    expect(transitions, [CoreStatus.disconnected]);
    verifyNever(() => coreInterface.stop());

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('an unexpected crash auto reconnects the core', (tester) async {
    CoreEventManager.resetInstance();
    final coreInterface = _MockCoreHandlerInterface();
    when(() => coreInterface.stopLog()).thenAnswer((_) {});
    final controller = CoreController.test(coreInterface);
    final container = ProviderContainer(
      overrides: [coreActionProvider.overrideWith(_TestCoreAction.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CoreManager(controller: controller, child: const SizedBox()),
        ),
      ),
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    final coreAction =
        container.read(coreActionProvider.notifier) as _TestCoreAction;

    coreEventManager.sendEvent(
      const CoreEvent(type: CoreEventType.crash, data: 'boom'),
    );
    await tester.pump();

    expect(container.read(coreStatusProvider), CoreStatus.disconnected);
    expect(coreAction.restartCount, 0);

    await tester.pump(const Duration(seconds: 2));
    expect(coreAction.restartCount, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'repeated crashes within the cooldown do not auto reconnect in a loop',
    (tester) async {
      CoreEventManager.resetInstance();
      final coreInterface = _MockCoreHandlerInterface();
      when(() => coreInterface.stopLog()).thenAnswer((_) {});
      final controller = CoreController.test(coreInterface);
      final container = ProviderContainer(
        overrides: [coreActionProvider.overrideWith(_TestCoreAction.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: CoreManager(controller: controller, child: const SizedBox()),
          ),
        ),
      );
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      final coreAction =
          container.read(coreActionProvider.notifier) as _TestCoreAction;

      coreEventManager.sendEvent(
        const CoreEvent(type: CoreEventType.crash, data: 'boom'),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(coreAction.restartCount, 1);

      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      coreEventManager.sendEvent(
        const CoreEvent(type: CoreEventType.crash, data: 'boom again'),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(coreAction.restartCount, 1);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
