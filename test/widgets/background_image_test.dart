import 'package:fl_clash/ui/background_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
