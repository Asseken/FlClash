import 'package:fl_clash/ui/background_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:prism_ui/prism_ui.dart';

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<ImageInfo> _firstFrame(CoverImage provider) {
  final completer = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info);
      stream.removeListener(listener);
    },
    onError: (error, stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('background cover decoding buckets the display size', () {
    final size = BackgroundImage.decodeSize(
      source: const Size(4000, 3000),
      window: const Size(1000, 500),
    );

    expect(size.width, 1024);
    expect(size.height, 768);
  });

  test('background cover decoding caps the pixel budget', () {
    final size = BackgroundImage.decodeSize(
      source: const Size(10000, 100),
      window: const Size(1000, 1000),
      maxPixels: 100000,
    );

    expect(size.width * size.height, lessThanOrEqualTo(100000));
  });

  testWidgets('fills the screen with the given opacity', (tester) async {
    await tester.pumpWidget(
      const PrismApp(home: BackgroundImage(path: 'missing.png', opacity: 0.5)),
    );
    await tester.pump();

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
  });

  testWidgets('draws nothing when the file cannot be read', (tester) async {
    await tester.pumpWidget(
      const PrismApp(home: BackgroundImage(path: 'missing/missing.png')),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
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
}
