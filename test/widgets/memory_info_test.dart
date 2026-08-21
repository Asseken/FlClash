import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widgets/memory_info.dart';
import 'package:fl_clash/widgets/inherited.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MemoryInfo refreshes only while the app is resumed', (
    tester,
  ) async {
    var readCount = 0;

    Future<num> readMemory() async {
      readCount++;
      return readCount;
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpWidget(
      _TestApp(
        container: container,
        child: MemoryInfo(memoryReader: readMemory),
      ),
    );
    await tester.pump();

    expect(readCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(readCount, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(readCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));

    expect(readCount, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(readCount, 3);

    await disposeApp(tester);
  });

  testWidgets('MemoryInfo ignores a request completed in the background', (
    tester,
  ) async {
    final requests = <Completer<num>>[];

    Future<num> readMemory() {
      final request = Completer<num>();
      requests.add(request);
      return request.future;
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      _TestApp(
        container: container,
        child: MemoryInfo(memoryReader: readMemory),
      ),
    );
    await tester.pump();

    expect(requests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    requests.first.complete(1);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(requests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(requests, hasLength(2));

    requests.last.complete(2);
    await tester.pump();
    await disposeApp(tester);
  });

  testWidgets('MemoryInfo keeps polling after a failed read', (tester) async {
    var readCount = 0;

    Future<num> readMemory() async {
      readCount++;
      if (readCount == 1) {
        throw StateError('core unavailable');
      }
      return readCount;
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      _TestApp(
        container: container,
        child: MemoryInfo(memoryReader: readMemory),
      ),
    );
    await tester.pump();

    expect(readCount, 1);
    expect(tester.takeException(), null);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(readCount, 2);
    expect(tester.takeException(), null);

    await disposeApp(tester);
  });

  testWidgets('MemoryInfo refreshes only while the page is active', (
    tester,
  ) async {
    var readCount = 0;

    Future<num> readMemory() async {
      readCount++;
      return readCount;
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    Widget buildApp({required bool isPageActive}) {
      return _TestApp(
        container: container,
        child: PageActivityScope(
          isActive: isPageActive,
          child: MemoryInfo(memoryReader: readMemory),
        ),
      );
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(buildApp(isPageActive: false));
    await tester.pump(const Duration(seconds: 4));

    expect(readCount, 0);

    await tester.pumpWidget(buildApp(isPageActive: true));
    await tester.pump();

    expect(readCount, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(readCount, 2);

    await tester.pumpWidget(buildApp(isPageActive: false));
    await tester.pump(const Duration(seconds: 4));

    expect(readCount, 2);

    await disposeApp(tester);
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;
  final ProviderContainer container;

  const _TestApp({required this.child, required this.container});

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: globalState.navigatorKey,
        localizationsDelegates: const [
          AppLocalizations.delegate,
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
        home: Scaffold(body: child),
      ),
    );
  }
}

/// 卸载组件树并冲掉遗留的定时器。
///
/// MemoryInfo 的加载态会渲染 CommonCircleLoading(无限变形动画),
/// 其 _runMorphLoop 的 Future.delayed 在组件销毁后仍会保留一个 pending 定时器,
/// 需要额外 pump 让它触发后自行退出。
Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}
