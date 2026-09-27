import 'package:dio/dio.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core_update.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/core_update_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

const _releases = [
  CoreRelease(tagName: 'v1.19.30'),
  CoreRelease(tagName: 'v1.9.28'),
];

const _data = CoreUpdateData(
  releases: _releases,
  newerReleases: [CoreRelease(tagName: 'v1.19.30')],
  currentVersion: '1.9.28',
  hasUpdate: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1000, 800);
  });

  tearDown(() => container.dispose());

  Future<void> pumpHost(
    WidgetTester tester,
    Future<void> Function(BuildContext context) onPressed,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => onPressed(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the version picker resolves with the chosen tag', (
    tester,
  ) async {
    String? selected;
    await pumpHost(tester, (context) async {
      selected = await showCoreUpdateDialog(context, _data);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('v1.19.30'), findsOneWidget);
    expect(
      find.text('v1.9.28 (${AppLocalizations.current.coreVersion})'),
      findsOneWidget,
    );

    await tester.tap(
      find.text('v1.9.28 (${AppLocalizations.current.coreVersion})'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.goDownload));
    await tester.pumpAndSettle();

    expect(selected, 'v1.9.28');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the picker resolves with nothing', (tester) async {
    String? selected = 'unset';
    await pumpHost(tester, (context) async {
      selected = await showCoreUpdateDialog(context, _data);
    });

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.cancel));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the download dialog reports the downloaded path', (
    tester,
  ) async {
    String? downloaded;
    await pumpHost(tester, (context) async {
      downloaded = await showCoreDownloadProgress(
        onDownload: (progress, cancelToken) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          progress.value = 1;
          return '/tmp/libclashn011930.so';
        },
      );
    });

    await tester.tap(find.text('open'));
    await tester.pump();
    expect(
      find.text(AppLocalizations.current.coreUpdateDownloading),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(downloaded, '/tmp/libclashn011930.so');
    expect(
      find.text(AppLocalizations.current.coreUpdateDownloading),
      findsNothing,
    );
  });

  testWidgets('cancelling the download resolves with nothing', (tester) async {
    String? downloaded = 'unset';
    await pumpHost(tester, (context) async {
      downloaded = await showCoreDownloadProgress(
        onDownload: (progress, cancelToken) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (cancelToken.isCancelled) {
            throw DioException(
              requestOptions: RequestOptions(path: 'core'),
              type: DioExceptionType.cancel,
            );
          }
          return 'core';
        },
      );
    });

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.tap(find.text(AppLocalizations.current.cancel));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(downloaded, isNull);
    expect(tester.takeException(), isNull);
  });
}
