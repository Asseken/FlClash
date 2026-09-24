import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart'
    show FluentIcons, ToggleSwitch, WindowsIcons;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

/// A 1x1 PNG, so the tiles decode instead of falling into their error builder.
final _imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842'
  'iQAAAABJRU5ErkJggg==',
);

// The background section copies and removes files through `appPath`, which no
// plugin answers for in a widget test.
class _FakePathProvider extends PathProviderPlatform {
  final String root;

  _FakePathProvider(this.root);

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late Directory appPathDir;

  setUpAll(() {
    appPathDir = Directory.systemTemp.createTempSync('theme_view_app');
    PathProviderPlatform.instance = _FakePathProvider(appPathDir.path);
  });

  tearDownAll(() {
    if (appPathDir.existsSync()) {
      appPathDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1400, 1400);
  });

  tearDown(() => container.dispose());

  Future<void> pumpThemeView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ThemeView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ThemeProps readTheme() => container.read(themeSettingProvider);

  /// The settings rows carry a leading icon each, so the switch is addressed
  /// through its row rather than by position.
  Finder toggleIn(IconData iconData) {
    return find.descendant(
      of: find.ancestor(
        of: find.byIcon(iconData),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(ToggleSwitch),
    );
  }

  group('theme mode', () {
    testWidgets('defaults to the light theme', (tester) async {
      await pumpThemeView(tester);

      expect(readTheme().themeMode, ThemeMode.light);
    });

    testWidgets('switches to light and back to dark', (tester) async {
      await pumpThemeView(tester);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.light);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.dark);

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.system);
    });
  });

  group('pure black', () {
    testWidgets('toggles both ways', (tester) async {
      await pumpThemeView(tester);
      final toggle = find.byType(ToggleSwitch).first;

      expect(readTheme().pureBlack, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(readTheme().pureBlack, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(readTheme().pureBlack, isFalse);
    });
  });

  group('text scale', () {
    testWidgets('is disabled until its toggle is enabled', (tester) async {
      await pumpThemeView(tester);

      expect(readTheme().textScale.enable, isFalse);

      await tester.tap(toggleIn(FluentIcons.text_field));
      await tester.pumpAndSettle();

      expect(readTheme().textScale.enable, isTrue);
    });

    testWidgets('the slider writes a new scale once enabled', (tester) async {
      await pumpThemeView(tester);
      await tester.tap(toggleIn(FluentIcons.text_field));
      await tester.pumpAndSettle();
      final before = readTheme().textScale.scale;

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      await tester.drag(slider, const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(readTheme().textScale.scale, isNot(before));
    });

    testWidgets('renders the scale as a rounded percentage', (tester) async {
      container
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith.textScale(enable: true, scale: 1.2),
          );

      await pumpThemeView(tester);

      expect(find.text('120%'), findsOneWidget);
    });
  });

  group('background image', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('theme_background_test');
    });

    tearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    File imageFile(String name) {
      final file = File('${dir.path}/$name.png');
      file.writeAsBytesSync(_imageBytes);
      return file;
    }

    testWidgets('lists no thumbnails before one is picked', (tester) async {
      await pumpThemeView(tester);

      expect(
        find.text(AppLocalizations.current.noBackgroundImage),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('the toggle writes backgroundImageEnabled', (tester) async {
      await pumpThemeView(tester);

      expect(readTheme().backgroundImageEnabled, isTrue);

      await tester.tap(toggleIn(WindowsIcons.picture));
      await tester.pumpAndSettle();

      expect(readTheme().backgroundImageEnabled, isFalse);
    });

    testWidgets('the opacity slider writes a new opacity', (tester) async {
      final first = imageFile('first');
      container
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith(
              backgroundImages: [first.path],
              backgroundImage: first.path,
            ),
          );

      await pumpThemeView(tester);

      final label = find.text(AppLocalizations.current.backgroundOpacity);
      expect(label, findsOneWidget);

      final slider = find.byType(Slider).last;
      expect(
        tester.getBottomLeft(label).dy,
        lessThan(tester.getTopLeft(slider).dy),
        reason: 'the label belongs on its own line above the slider',
      );

      final sliderWidget = tester.widget<Slider>(slider);
      expect(sliderWidget.min, 0.0);
      expect(sliderWidget.max, 1.0);

      await tester.drag(slider, const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(readTheme().backgroundOpacity, isNot(1.0));
      expect(readTheme().backgroundOpacity, inInclusiveRange(0.0, 1.0));
    });

    testWidgets('selecting a stored image makes it the active background', (
      tester,
    ) async {
      final first = imageFile('first');
      final second = imageFile('second');
      container
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith(
              backgroundImages: [first.path, second.path],
              backgroundImage: first.path,
            ),
          );

      await pumpThemeView(tester);

      expect(find.byType(Image), findsNWidgets(2));
      expect(readTheme().backgroundImage, first.path);

      await tester.tap(find.byType(Image).last);
      await tester.pumpAndSettle();

      expect(readTheme().backgroundImage, second.path);

      final thumbnail = tester.getSize(find.byType(Image).last);
      final badge = tester.getSize(find.byType(SelectIcon).first);
      expect(
        badge.width,
        lessThan(thumbnail.width / 2),
        reason: 'the check badge must not cover the thumbnail',
      );
    });

    testWidgets('deleting the active image falls back to the next one', (
      tester,
    ) async {
      final first = imageFile('first');
      final second = imageFile('second');
      container
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith(
              backgroundImages: [first.path, second.path],
              backgroundImage: first.path,
            ),
          );

      await pumpThemeView(tester);
      await tester.longPress(find.byType(Image).first);
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithIcon(IconButton, WindowsIcons.delete).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizations.current.confirm).last);
      await tester.pumpAndSettle();

      expect(readTheme().backgroundImages, [second.path]);
      expect(readTheme().backgroundImage, second.path);
    });
  });
}
