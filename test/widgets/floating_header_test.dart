import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _scrim() => find.descendant(
  of: find.byType(FloatingHeader),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).gradient != null,
  ),
);

Widget _host(Color backgroundColor) {
  return MaterialApp(
    home: Scaffold(
      body: FloatingHeader(
        backgroundColor: backgroundColor,
        child: const SizedBox(height: 64),
      ),
    ),
  );
}

void main() {
  testWidgets('an opaque fill fades out below the header', (tester) async {
    const fill = Color(0xFF00FF00);
    await tester.pumpWidget(_host(fill));

    expect(_scrim(), findsOneWidget);
    final decoration =
        tester.widget<DecoratedBox>(_scrim()).decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;

    expect(gradient.colors.first.a, closeTo(0.9, 0.01));
    expect(gradient.colors.first.withValues(alpha: 1), fill);
    expect(
      gradient.colors.last.a,
      0,
      reason: 'the scrim must reach full transparency at its bottom edge',
    );
  });

  testWidgets('a transparent fill paints no scrim', (tester) async {
    await tester.pumpWidget(_host(Colors.transparent));

    expect(
      _scrim(),
      findsNothing,
      reason:
          'raising the alpha of a transparent fill would paint black over the '
          'wallpaper instead of fading the surface out',
    );
  });
}
