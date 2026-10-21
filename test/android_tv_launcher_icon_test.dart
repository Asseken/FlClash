import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

String _androidAttribute(String source, String element, String attribute) {
  final elementTag = RegExp('<$element\\b[^>]*>').firstMatch(source)!.group(0)!;
  return RegExp(
    'android:$attribute="([^"]+)"',
  ).firstMatch(elementTag)!.group(1)!;
}

const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

const _res = 'android/app/src/main/res';

Future<ui.Image> _decode(File file) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// The box the opaque pixels of [image] cover, in pixels.
Future<({int left, int top, int right, int bottom})> _inkBounds(
  ui.Image image,
) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  var left = image.width;
  var top = image.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (bytes[(y * image.width + x) * 4 + 3] == 0) {
        continue;
      }
      if (x < left) left = x;
      if (y < top) top = y;
      if (x > right) right = x;
      if (y > bottom) bottom = y;
    }
  }
  return (left: left, top: top, right: right, bottom: bottom);
}

Future<({int width, int height})> _size(File file) async {
  final image = await _decode(file);
  final size = (width: image.width, height: image.height);
  image.dispose();
  return size;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TV launcher icons meet density-specific minimum sizes', () async {
    for (final MapEntry(key: density, value: scale) in _densities.entries) {
      final size = (80 * scale).round();
      final file = File('$_res/mipmap-television-$density/ic_launcher.webp');
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      expect(await _size(file), (width: size, height: size), reason: file.path);
    }
  });

  test('the launcher icons carry one artwork at every density', () async {
    for (final MapEntry(key: density, value: scale) in _densities.entries) {
      final legacy = (48 * scale).round();
      for (final name in ['ic_launcher.webp', 'ic_launcher_round.webp']) {
        final file = File('$_res/mipmap-$density/$name');
        expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
        expect(await _size(file), (
          width: legacy,
          height: legacy,
        ), reason: file.path);
      }
    }
  });

  test('the adaptive launcher keeps its art inside the safe zone', () async {
    for (final icon in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
      final source = File('$_res/mipmap-anydpi-v26/$icon').readAsStringSync();
      expect(
        _androidAttribute(source, 'foreground', 'drawable'),
        '@mipmap/ic_launcher_foreground',
        reason: icon,
      );
      expect(
        _androidAttribute(source, 'monochrome', 'drawable'),
        '@mipmap/ic_launcher_monochrome',
        reason: icon,
      );
      expect(
        _androidAttribute(source, 'background', 'drawable'),
        '@color/ic_launcher_background',
        reason: icon,
      );
    }

    for (final MapEntry(key: density, value: scale) in _densities.entries) {
      final canvas = (108 * scale).round();
      // Android masks the foreground to the middle 72dp of its 108dp canvas.
      final safe = 72 * scale;
      for (final name in [
        'ic_launcher_foreground.webp',
        'ic_launcher_monochrome.webp',
      ]) {
        final file = File('$_res/mipmap-$density/$name');
        expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
        final image = await _decode(file);
        expect(
          (image.width, image.height),
          (canvas, canvas),
          reason: file.path,
        );
        final ink = await _inkBounds(image);
        image.dispose();
        final width = (ink.right - ink.left + 1).toDouble();
        final height = (ink.bottom - ink.top + 1).toDouble();
        expect(width, lessThanOrEqualTo(safe), reason: file.path);
        expect(height, lessThanOrEqualTo(safe), reason: file.path);
        expect(
          (ink.left + ink.right + 1) / 2,
          closeTo(canvas / 2, 1),
          reason: '${file.path} is not centred',
        );
        expect(
          (ink.top + ink.bottom + 1) / 2,
          closeTo(canvas / 2, 1),
          reason: '${file.path} is not centred',
        );
      }
    }
  });

  test('the TV adaptive launcher keeps its art inside the safe zone', () async {
    final source = File(
      '$_res/mipmap-television-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(
      _androidAttribute(source, 'foreground', 'drawable'),
      '@mipmap/ic_launcher_foreground_tv',
    );
    expect(
      _androidAttribute(source, 'background', 'drawable'),
      '@color/ic_launcher_background',
    );

    for (final MapEntry(key: density, value: scale) in _densities.entries) {
      final canvas = (108 * scale).round();
      final safe = 72 * scale;
      final file = File(
        '$_res/mipmap-television-$density/ic_launcher_foreground_tv.webp',
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      final image = await _decode(file);
      expect((image.width, image.height), (canvas, canvas), reason: file.path);
      final ink = await _inkBounds(image);
      image.dispose();
      expect(
        (ink.right - ink.left + 1),
        lessThanOrEqualTo(safe),
        reason: file.path,
      );
      expect(
        (ink.bottom - ink.top + 1),
        lessThanOrEqualTo(safe),
        reason: file.path,
      );
    }
  });

  test('the splash icon is the launcher artwork, not a second drawing', () {
    for (final file in [
      '$_res/values-v27/styles.xml',
      '$_res/values-night-v27/styles.xml',
    ]) {
      final source = File(file).readAsStringSync();
      final icon = RegExp(
        r'windowSplashScreenAnimatedIcon"[^>]*>([^<]+)<',
      ).firstMatch(source)!.group(1)!;
      expect(icon, '@mipmap/ic_launcher_foreground', reason: file);
    }
  });

  test('the leanback banner keeps the size Android TV asks for', () async {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:banner="@mipmap/ic_banner"'));

    final file = File('$_res/mipmap-xhdpi/ic_banner.png');
    expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
    expect(await _size(file), (width: 320, height: 180), reason: file.path);
  });

  test('the Play Store icon is opaque at the listing size', () async {
    final file = File('android/app/src/main/ic_launcher-playstore.png');
    expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
    final image = await _decode(file);
    expect((image.width, image.height), (512, 512), reason: file.path);

    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    image.dispose();
    for (var index = 3; index < bytes.length; index += 4) {
      expect(
        bytes[index],
        255,
        reason: 'Play rejects a listing icon that is not opaque',
      );
    }
  });
}
