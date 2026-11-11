import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/ui/background_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// A 1x1 transparent PNG, enough for the provider to decode a real file.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<ImageInfo> _firstFrame(CoverImage provider) {
  final completer = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) {
        completer.complete(info);
      }
      stream.removeListener(listener);
    },
    onError: (error, stack) {
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeSize', () {
    const window = Size(1920, 1080);

    test('matches the window for an image of the window shape', () {
      expect(
        BackgroundImage.decodeSize(
          source: const Size(1920, 1080),
          window: window,
        ),
        (width: 2276, height: 1280),
      );
    });

    test('scales a portrait image by the height cover will use', () {
      expect(
        BackgroundImage.decodeSize(
          source: const Size(4000, 6000),
          window: window,
        ),
        (width: 2048, height: 3072),
      );
    });

    test('scales a panorama by the width cover will use', () {
      expect(
        BackgroundImage.decodeSize(
          source: const Size(4000, 1000),
          window: window,
        ),
        (width: 5120, height: 1280),
      );
    });

    test('buckets the window so a resize reuses the decoded image', () {
      expect(
        BackgroundImage.decodeSize(
          source: const Size(1920, 1080),
          window: const Size(1400, 900),
        ),
        (width: 1820, height: 1024),
      );
    });

    test('caps the decoded area and keeps the aspect ratio', () {
      const ratio = 4000 / 6000;
      final size = BackgroundImage.decodeSize(
        source: const Size(4000, 6000),
        window: const Size(3840, 2160),
      );

      expect(size.width * size.height, lessThanOrEqualTo(12 * 1000 * 1000));
      expect(size.width / size.height, closeTo(ratio, 0.001));
      expect(size.width, greaterThanOrEqualTo(3840 * 0.5));
    });
  });

  testWidgets('covers its parent with an image decoded for the window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const PrismApp(home: BackgroundImage(path: 'missing.png', opacity: 0.5)),
    );

    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as CoverImage;

    expect(opacity.opacity, 0.5);
    expect(image.fit, BoxFit.cover);
    expect(image.gaplessPlayback, isTrue);
    expect(provider.path, 'missing.png');
    expect(provider.window, const Size(800, 600));
  });

  testWidgets('fills the screen when given no opacity', (tester) async {
    await tester.pumpWidget(
      const PrismApp(home: BackgroundImage(path: 'missing.png')),
    );

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('draws nothing when the file cannot be read', (tester) async {
    await tester.pumpWidget(
      const PrismApp(home: BackgroundImage(path: 'missing/missing.png')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.widget<Image>(find.byType(Image)).errorBuilder, isNotNull);
  });

  test('decodes the file to the box cover needs', () async {
    final directory = await Directory.systemTemp.createTemp('cover_image');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/wallpaper.png');
    await file.writeAsBytes(_onePixelPng);

    const window = Size(800, 600);
    final provider = CoverImage(path: file.path, window: window);
    final info = await _firstFrame(provider);
    final size = BackgroundImage.decodeSize(
      source: const Size(1, 1),
      window: window,
    );

    expect(info.image.width, size.width);
    expect(info.image.height, size.height);
    info.dispose();
  });

  test('keys on the file, the window and the cap', () {
    const key = CoverImage(path: 'a.png', window: Size(800, 600));

    expect(key, const CoverImage(path: 'a.png', window: Size(800, 600)));
    expect(
      key.hashCode,
      const CoverImage(path: 'a.png', window: Size(800, 600)).hashCode,
    );
    expect(key, isNot(const CoverImage(path: 'b.png', window: Size(800, 600))));
    expect(
      key,
      isNot(const CoverImage(path: 'a.png', window: Size(1024, 600))),
    );
    expect(
      key,
      isNot(
        const CoverImage(path: 'a.png', window: Size(800, 600), maxPixels: 4),
      ),
    );
  });
}
