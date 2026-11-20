import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

class BackgroundImage extends StatelessWidget {
  const BackgroundImage({super.key, required this.path, this.opacity = 1.0});

  final String path;
  final double opacity;

  static const _bucket = 256;
  static const _maxPixels = 12 * 1000 * 1000;

  @visibleForTesting
  static ({int width, int height}) decodeSize({
    required Size source,
    required Size window,
    int maxPixels = _maxPixels,
  }) {
    final bucketed = Size(
      (window.width / _bucket).ceil() * _bucket.toDouble(),
      (window.height / _bucket).ceil() * _bucket.toDouble(),
    );
    final ratio = source.width / source.height;
    var width = math.max(bucketed.width, bucketed.height * ratio);
    var height = math.max(bucketed.height, bucketed.width / ratio);
    if (width * height > maxPixels) {
      final scale = math.sqrt(maxPixels / (width * height));
      width *= scale;
      height *= scale;
    }
    var roundedWidth = width.round();
    var roundedHeight = height.round();
    if (roundedWidth * roundedHeight > maxPixels) {
      final scale = math.sqrt(maxPixels / (roundedWidth * roundedHeight));
      roundedWidth = (roundedWidth * scale).floor();
      roundedHeight = (roundedHeight * scale).floor();
    }
    return (width: roundedWidth, height: roundedHeight);
  }

  @override
  Widget build(BuildContext context) {
    final window =
        MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
    return Opacity(
      opacity: opacity,
      child: Image(
        image: CoverImage(path: path, window: window),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

@immutable
class CoverImage extends ImageProvider<CoverImage> {
  const CoverImage({
    required this.path,
    required this.window,
    this.maxPixels = BackgroundImage._maxPixels,
  });

  final String path;
  final Size window;
  final int maxPixels;

  @override
  Future<CoverImage> obtainKey(ImageConfiguration configuration) =>
      Future<CoverImage>.value(this);

  @override
  ImageStreamCompleter loadImage(CoverImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: 1,
      debugLabel: key.path,
    );
  }

  Future<ui.Codec> _loadAsync(CoverImage key) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(key.path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = BackgroundImage.decodeSize(
        source: Size(descriptor.width.toDouble(), descriptor.height.toDouble()),
        window: key.window,
        maxPixels: key.maxPixels,
      );
      return await descriptor.instantiateCodec(
        targetWidth: size.width,
        targetHeight: size.height,
      );
    } finally {
      buffer.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CoverImage &&
      other.path == path &&
      other.window == window &&
      other.maxPixels == maxPixels;

  @override
  int get hashCode => Object.hash(path, window, maxPixels);
}
