import 'dart:ui';

import 'package:fl_clash/common/color.dart';
import 'package:flutter/material.dart';

class LineSeries {
  final List<Point> points;
  final Color color;
  final bool gradient;

  const LineSeries({
    required this.points,
    required this.color,
    this.gradient = false,
  });
}

class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);
}

class LineChart extends StatefulWidget {
  final List<LineSeries> series;
  final Duration duration;

  const LineChart({
    super.key,
    required this.series,
    this.duration = Duration.zero,
  });

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<List<Point>> _points = [];

  List<List<Point>> _prevRenderPoints = [];
  List<List<Point>> _currentRenderPoints = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _points = widget.series.map((s) => s.points).toList();
    _currentRenderPoints = _getRenderPoints(_points);
    _prevRenderPoints = _currentRenderPoints;
  }

  @override
  void didUpdateWidget(LineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPoints = widget.series.map((s) => s.points).toList();
    if (!_listEquals2D(newPoints, _points)) {
      _points = newPoints;
      _prevRenderPoints = _currentRenderPoints;
      _currentRenderPoints = _getRenderPoints(_points);
      _controller.forward(from: 0);
    }
  }

  bool _listEquals2D(List<List<Point>> a, List<List<Point>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (var j = 0; j < a[i].length; j++) {
        if (a[i][j].x != b[i][j].x || a[i][j].y != b[i][j].y) return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<List<Point>> _getRenderPoints(List<List<Point>> allPoints) {
    final result = <List<Point>>[];
    if (allPoints.isEmpty) return result;

    // Compute shared y-range across all series.
    double maxY = double.negativeInfinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double minX = double.infinity;

    for (final points in allPoints) {
      for (final point in points) {
        if (point.x > maxX) maxX = point.x;
        if (point.x < minX) minX = point.x;
        if (point.y > maxY) maxY = point.y;
        if (point.y < minY) minY = point.y;
      }
    }

    final xRange = maxX - minX;
    final yRange = maxY - minY;

    for (final points in allPoints) {
      result.add(points.map((e) {
        final x = xRange == 0 ? 0.0 : (e.x - minX) / xRange;
        final y = yRange == 0 ? 0.0 : (e.y - minY) / yRange;
        return Point(x, y);
      }).toList());
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, container) {
        return AnimatedBuilder(
          animation: _controller.view,
          builder: (_, _) {
            return CustomPaint(
              painter: LineChartPainter(
                series: widget.series,
                prevRenderPoints: _prevRenderPoints,
                currentRenderPoints: _currentRenderPoints,
                progress: _controller.value,
              ),
              child: SizedBox(
                height: container.maxHeight,
                width: container.maxWidth,
              ),
            );
          },
        );
      },
    );
  }
}

class _SeriesRenderData {
  final List<Point> prevRenderPoints;
  final List<Point> currentRenderPoints;
  final Color color;
  final bool gradient;

  const _SeriesRenderData({
    required this.prevRenderPoints,
    required this.currentRenderPoints,
    required this.color,
    required this.gradient,
  });
}

class LineChartPainter extends CustomPainter {
  final List<LineSeries> series;
  final List<List<Point>> prevRenderPoints;
  final List<List<Point>> currentRenderPoints;
  final double progress;

  LineChartPainter({
    required this.series,
    required this.prevRenderPoints,
    required this.currentRenderPoints,
    required this.progress,
  });

  List<_SeriesRenderData> _buildSeriesData() {
    final result = <_SeriesRenderData>[];
    for (var i = 0; i < series.length; i++) {
      result.add(_SeriesRenderData(
        prevRenderPoints:
            i < prevRenderPoints.length ? prevRenderPoints[i] : [],
        currentRenderPoints:
            i < currentRenderPoints.length ? currentRenderPoints[i] : [],
        color: series[i].color,
        gradient: series[i].gradient,
      ));
    }
    return result;
  }

  Paint _createStrokePaint(Color color) {
    return Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
  }

  Paint _createFillPaint() {
    return Paint()..style = PaintingStyle.fill;
  }

  List<Point> _getInterpolatePoints(
      double t, List<Point> prev, List<Point> current) {
    if (current.isEmpty) return [];

    final length = current.length;
    final result = <Point>[];

    for (var i = 0; i < length; i++) {
      if (i > prev.length - 1) {
        result.add(current[i]);
      } else {
        final x = lerpDouble(
          prev[i].x,
          current[i].x,
          t,
        )!;
        final y = lerpDouble(
          prev[i].y,
          current[i].y,
          t,
        )!;
        result.add(Point(x, y));
      }
    }

    return result;
  }

  Path _getPath(List<Point> points, Size size) {
    if (points.isEmpty) return Path();

    final path = Path()
      ..moveTo(points[0].x * size.width, (1 - points[0].y) * size.height);

    for (var i = 1; i < points.length - 1; i++) {
      final nextPoint = points[i + 1];
      final currentPoint = points[i];
      final midX = (currentPoint.x + nextPoint.x) / 2;
      final midY = (currentPoint.y + nextPoint.y) / 2;

      path.quadraticBezierTo(
        currentPoint.x * size.width,
        (1 - currentPoint.y) * size.height,
        midX * size.width,
        (1 - midY) * size.height,
      );
    }

    path.lineTo(
        points.last.x * size.width, (1 - points.last.y) * size.height);
    return path;
  }

  Path _getAnimatedPath(Size size, List<Point> prev, List<Point> current) {
    final interpolatedPoints =
        _getInterpolatePoints(progress, prev, current);
    return _getPath(interpolatedPoints, size);
  }

  static final Map<int, Shader> _shaderCache = {};

  Shader _getShader(Size size, Color color) {
    final key = Object.hash(size.width, size.height, color.value);
    final cached = _shaderCache[key];
    if (cached != null) return cached;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.opacity38, color.opacity10],
    );

    const strokeWidth = 2.0;
    final shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height + strokeWidth * 2),
    );
    _shaderCache[key] = shader;
    return shader;
  }

  bool _seriesColorOrGradientChanged(LineChartPainter oldDelegate) {
    final oldSeries = oldDelegate.series;
    if (series.length != oldSeries.length) return true;
    for (var i = 0; i < series.length; i++) {
      if (series[i].color != oldSeries[i].color ||
          series[i].gradient != oldSeries[i].gradient) {
        return true;
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final seriesData = _buildSeriesData();
    if (seriesData.isEmpty) return;

    const strokeWidth = 2.0;
    final chartSize = Size(size.width, size.height * 0.7);

    // Draw fills for all series first, then strokes on top.
    for (final data in seriesData) {
      if (data.gradient && data.currentRenderPoints.isNotEmpty) {
        final path = _getAnimatedPath(
            chartSize, data.prevRenderPoints, data.currentRenderPoints);
        final fillPath = Path.from(path);
        fillPath.lineTo(size.width, size.height + strokeWidth * 2);
        fillPath.lineTo(0, size.height + strokeWidth * 2);
        fillPath.close();

        final fillPaint =
            _createFillPaint()..shader = _getShader(size, data.color);
        canvas.drawPath(fillPath, fillPaint);
      }
    }

    for (final data in seriesData) {
      if (data.currentRenderPoints.isNotEmpty) {
        final path = _getAnimatedPath(
            chartSize, data.prevRenderPoints, data.currentRenderPoints);
        canvas.drawPath(path, _createStrokePaint(data.color));
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.prevRenderPoints != prevRenderPoints ||
        oldDelegate.currentRenderPoints != currentRenderPoints ||
        _seriesColorOrGradientChanged(oldDelegate);
  }
}