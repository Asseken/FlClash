import 'package:fl_clash/common/color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opacity extensions use their named alpha values', () {
    const color = Colors.blue;
    const tolerance = 0.0001;

    expect(color.opacity80.a, closeTo(0.8, tolerance));
    expect(color.opacity50.a, closeTo(0.5, tolerance));
    expect(color.opacity10.a, closeTo(0.1, tolerance));
    expect(color.opacity3.a, closeTo(0.03, tolerance));
    expect(color.opacity0.a, 0);
  });

  test('scaledAlpha follows the alpha it starts from', () {
    const tolerance = 0.0001;
    const blue = Color(0xFF2196F3);

    expect(blue.scaledAlpha(0.5).a, closeTo(0.5, tolerance));
    expect(blue.scaledAlpha(0.5).withValues(alpha: 1), blue);
    expect(blue.opacity50.scaledAlpha(0.5).a, closeTo(0.25, tolerance));
    expect(
      Colors.transparent.scaledAlpha(0.5).a,
      0,
      reason:
          'a wallpaper makes the surfaces transparent, and a veil raised to '
          'half alpha would be black instead of invisible',
    );
  });
}
