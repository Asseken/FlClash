import 'package:fl_clash/widgets/background_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      const MaterialApp(
        home: BackgroundImage(path: 'missing.png', opacity: 0.5),
      ),
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
}
