import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.values,
    this.secondaryValues = const [],
    required this.revision,
    required this.capacity,
    required this.minScale,
    required this.color,
    this.secondaryColor,
  }) : assert(capacity > 1),
       assert(minScale > 0);

  final List<double> values;

  /// A second series, such as upload beside download, drawn on the same scale
  /// so the two lines stay comparable.
  final List<double> secondaryValues;

  /// Advances by one for each sample appended to [values] and
  /// [secondaryValues]. Any other change, such as a clear, starts the chart
  /// over.
  final int revision;

  final int capacity;

  /// The least value the top stands for, so idle noise stays near the baseline.
  final double minScale;

  final Color color;

  final Color? secondaryColor;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  late _Series _series;
  late _Series _secondarySeries;

  int get _seriesLength => widget.capacity + _Series.radius + 1;

  @override
  void initState() {
    super.initState();
    _series = _Series.of(widget.values, _seriesLength);
    _secondarySeries = _Series.of(widget.secondaryValues, _seriesLength);
  }

  @override
  void didUpdateWidget(LineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _series = _advance(
      previous: _series,
      values: widget.values,
      revision: widget.revision,
      oldRevision: oldWidget.revision,
      oldCapacity: oldWidget.capacity,
    );
    _secondarySeries = _advance(
      previous: _secondarySeries,
      values: widget.secondaryValues,
      revision: widget.revision,
      oldRevision: oldWidget.revision,
      oldCapacity: oldWidget.capacity,
    );
  }

  _Series _advance({
    required _Series previous,
    required List<double> values,
    required int revision,
    required int oldRevision,
    required int oldCapacity,
  }) {
    final appended = revision - oldRevision;
    if (widget.capacity != oldCapacity ||
        appended < 0 ||
        appended > values.length) {
      return _Series.of(values, _seriesLength);
    }
    if (appended == 0) {
      return previous;
    }
    return previous.append(values.sublist(values.length - appended));
  }

  @override
  Widget build(BuildContext context) {
    final secondaryColor = widget.secondaryColor;
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _LineChartPainter(
            series: _series,
            secondarySeries: secondaryColor == null ? null : _secondarySeries,
            capacity: widget.capacity,
            minScale: widget.minScale,
            color: widget.color,
            secondaryColor: secondaryColor,
          ),
        ),
      ),
    );
  }
}

@immutable
class _Series {
  _Series._(this.values) : heights = _blur(values);

  factory _Series.of(List<double> window, int length) {
    final count = math.min(window.length, length);
    return _Series._(
      List.filled(length, 0.0)
        ..setAll(length - count, window.sublist(window.length - count)),
    );
  }

  static const _sigma = 1.5;
  static final radius = (_sigma * 2.5).ceil();
  static final _kernel = [
    for (var d = 0; d <= radius; d++) math.exp(-d * d / (2 * _sigma * _sigma)),
  ];

  final List<double> values;

  final List<double> heights;

  _Series append(List<double> samples) {
    final next = [...values, ...samples];
    return _Series._(next.sublist(next.length - values.length));
  }

  static List<double> _blur(List<double> values) {
    return [for (var i = 0; i < values.length; i++) _blurAt(values, i)];
  }

  static double _blurAt(List<double> values, int i) {
    var sum = 0.0;
    var weight = 0.0;
    final from = math.max(i - radius, 0);
    final to = math.min(i + radius, values.length - 1);
    for (var j = from; j <= to; j++) {
      final w = _kernel[(j - i).abs()];
      sum += w * values[j];
      weight += w;
    }
    return sum / weight;
  }

  /// Catmull-Rom slopes, clamped so no control point and no curve dips below 0.
  static List<double> slopesOf(List<double> values) {
    final last = values.length - 1;
    return [
      for (var i = 0; i <= last; i++)
        i == 0 || i == last
            ? 0.0
            : ((values[i + 1] - values[i - 1]) / 2).clamp(
                -3 * values[i],
                3 * values[i],
              ),
    ];
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.series,
    required this.secondarySeries,
    required this.capacity,
    required this.minScale,
    required this.color,
    required this.secondaryColor,
  }) : _strokePaint = _strokePaintOf(color),
       _secondaryStrokePaint = switch (secondaryColor) {
         final color? => _strokePaintOf(color),
         _ => null,
       };

  static const _strokeWidth = 2.0;

  /// Keeps the zero line clear of the card's rounded bottom corners.
  static const _baselineRatio = 0.7;

  final _Series series;
  final _Series? secondarySeries;
  final int capacity;
  final double minScale;
  final Color color;
  final Color? secondaryColor;

  final Paint _strokePaint;
  final Paint? _secondaryStrokePaint;

  static Paint _strokePaintOf(Color color) => Paint()
    ..color = color
    ..strokeWidth = _strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  static Path _curveOf(List<double> heights, double step, double firstX) {
    final slopes = _Series.slopesOf(heights);
    var x = firstX;
    var y = -heights[0];
    final curve = Path()..moveTo(x, y);
    for (var i = 1; i < heights.length; i++) {
      final nextX = x + step;
      final nextY = -heights[i];
      curve.cubicTo(
        x + step / 3,
        y - slopes[i - 1] / 3,
        nextX - step / 3,
        nextY + slopes[i] / 3,
        nextX,
        nextY,
      );
      x = nextX;
      y = nextY;
    }
    return curve;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / (capacity - 1);
    final baseline = size.height * _baselineRatio;
    final firstX = size.width - (series.heights.length - 1) * step;
    final curve = _curveOf(series.heights, step, firstX);
    final secondary = switch (secondarySeries) {
      final series? => _curveOf(series.heights, step, firstX),
      _ => null,
    };
    var top = math.max(minScale, -curve.getBounds().top);
    if (secondary != null) {
      top = math.max(top, -secondary.getBounds().top);
    }
    final yScale = (baseline - _strokeWidth) / top;
    final matrix =
        (Matrix4.identity()
              ..translateByDouble(0, baseline, 0, 1)
              ..scaleByDouble(1, yScale, 1, 1))
            .storage;

    void draw(Path path, Color fillColor, Paint stroke) {
      final line = path.transform(matrix);
      final bounds = line.getBounds();
      final area = Path.from(line)
        ..lineTo(bounds.right, size.height)
        ..lineTo(bounds.left, size.height)
        ..close();
      canvas
        ..drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fillColor.opacity38, fillColor.opacity10],
            ).createShader(Offset.zero & size),
        )
        ..drawPath(line, stroke);
    }

    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    // The second line sits underneath, so the first reads as the main one.
    final secondaryStrokePaint = _secondaryStrokePaint;
    if (secondary != null && secondaryStrokePaint != null) {
      draw(secondary, secondaryColor!, secondaryStrokePaint);
    }
    draw(curve, color, _strokePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.secondarySeries != secondarySeries ||
        oldDelegate.capacity != capacity ||
        oldDelegate.minScale != minScale ||
        oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
