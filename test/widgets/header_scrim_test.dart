import 'package:fl_clash/manager/window_manager.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final _transparentScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF00FF00),
).withTransparentSurfaces;

final _opaqueScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00FF00));

/// What a blurred caption bar passes to `WindowHeaderBar` on desktop.
const _backdropOpacity = 0.5;

LinearGradient _scrimOf(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(FloatingHeader),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required ColorScheme colorScheme,
  required Color backgroundColor,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: colorScheme),
      home: Scaffold(
        body: FloatingHeader(
          backgroundColor: backgroundColor,
          child: const SizedBox(height: 56),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a wallpaper leaves the floating header with no veil', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      colorScheme: _transparentScheme,
      backgroundColor: _transparentScheme.surfaceContainer,
    );

    for (final color in _scrimOf(tester).colors) {
      expect(color.a, 0, reason: 'a scrim over the wallpaper would go black');
    }
  });

  testWidgets('a filled page keeps the scrim it draws now', (tester) async {
    await _pumpHeader(
      tester,
      colorScheme: _opaqueScheme,
      backgroundColor: _opaqueScheme.surfaceContainer,
    );

    final colors = _scrimOf(tester).colors;
    expect(colors.first.a, closeTo(0.9, 0.01));
    expect(colors.last.a, 0);
  });

  testWidgets('a translucent caption bar shows the wallpaper, not a veil', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: _transparentScheme),
        home: Scaffold(
          body: WindowHeaderBar(
            height: 48,
            backdropOpacity: _backdropOpacity,
            onDragStart: () {},
            onDoubleTap: () {},
          ),
        ),
      ),
    );

    final veil = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(WindowHeaderBar),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(veil.color.a, 0);
  });

  testWidgets('a translucent caption bar over a filled page keeps its tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: _opaqueScheme),
        home: Scaffold(
          body: WindowHeaderBar(
            height: 48,
            backdropOpacity: _backdropOpacity,
            onDragStart: () {},
            onDoubleTap: () {},
          ),
        ),
      ),
    );

    final veil = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(WindowHeaderBar),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(veil.color.a, closeTo(_backdropOpacity, 0.01));
    expect(
      veil.color.toARGB32() & 0xFFFFFF,
      _opaqueScheme.chromeSurface.toARGB32() & 0xFFFFFF,
    );
  });
}
