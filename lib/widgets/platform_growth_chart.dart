import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlatformGrowthChart extends StatelessWidget {
  const PlatformGrowthChart({
    super.key,
    required this.dataPoints,
    required this.labels,
    this.height = 180,
    this.lineColor = const Color(0xFF6366F1),
    this.gradientTopColor,
    this.gradientBottomColor,
  });

  final List<double> dataPoints;
  final List<String> labels;
  final double height;
  final Color lineColor;
  final Color? gradientTopColor;
  final Color? gradientBottomColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _GrowthChartPainter(
          dataPoints: dataPoints,
          labels: labels,
          lineColor: lineColor,
          gradientTopColor: gradientTopColor ?? lineColor.withValues(alpha: 0.3),
          gradientBottomColor: gradientBottomColor ?? lineColor.withValues(alpha: 0.0),
        ),
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  _GrowthChartPainter({
    required this.dataPoints,
    required this.labels,
    required this.lineColor,
    required this.gradientTopColor,
    required this.gradientBottomColor,
  });

  final List<double> dataPoints;
  final List<String> labels;
  final Color lineColor;
  final Color gradientTopColor;
  final Color gradientBottomColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    const double leftPadding = 32;
    const double bottomPadding = 28;
    const double topPadding = 12;
    const double rightPadding = 12;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - bottomPadding - topPadding;

    final maxVal = dataPoints.reduce(max);
    final minVal = 0.0;
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.5;

    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = topPadding + (chartHeight / gridLines) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );

      // Y-axis labels
      final value = maxVal - (range / gridLines) * i;
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toInt().toString(),
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // Compute point positions
    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = leftPadding + (chartWidth / (dataPoints.length - 1)) * i;
      final normalised = (dataPoints[i] - minVal) / range;
      final y = topPadding + chartHeight - (normalised * chartHeight);
      points.add(Offset(x, y));
    }

    // Build smooth path using cubic Bézier
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    // Draw gradient fill
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, topPadding + chartHeight);
    fillPath.lineTo(points.first.dx, topPadding + chartHeight);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [gradientTopColor, gradientBottomColor],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
      );

    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw data point dots
    for (final point in points) {
      canvas.drawCircle(
        point,
        3.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        point,
        2.5,
        Paint()..color = lineColor,
      );
    }

    // X-axis labels
    for (int i = 0; i < labels.length && i < points.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, size.height - bottomPadding + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints;
  }
}
