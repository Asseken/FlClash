import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Fills its parent with a wallpaper using [BoxFit.cover], decoded to the size
/// that fill shows instead of to the window's own box.
class BackgroundImage extends StatelessWidget {
  final String path;
  final double opacity;

  const BackgroundImage({super.key, required this.path, this.opacity = 1.0});

  static const _bucket = 256;
  static const _maxPixels = 12 * 1000 * 1000;

  /// The box cover needs for [source] in [window], raised to [_bucket] so a
  /// resize inside a bucket reuses the bitmap and capped per frame.
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
    return (width: width.round(), height: height.round());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final window = mediaQuery.size * mediaQuery.devicePixelRatio;
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

/// Reads the file header first, because cover's box depends on that size.
@immutable
class CoverImage extends ImageProvider<CoverImage> {
  final String path;
  final Size window;
  final int maxPixels;

  const CoverImage({
    required this.path,
    required this.window,
    this.maxPixels = BackgroundImage._maxPixels,
  });

  @override
  Future<CoverImage> obtainKey(ImageConfiguration configuration) {
    return Future<CoverImage>.value(this);
  }

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
  bool operator ==(Object other) {
    return other is CoverImage &&
        other.path == path &&
        other.window == window &&
        other.maxPixels == maxPixels;
  }

  @override
  int get hashCode => Object.hash(path, window, maxPixels);
}
