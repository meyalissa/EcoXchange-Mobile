import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// EcoXchange Mobile — a minimal line-chart widget for the Community
/// Impact monthly trend, drawn with [CustomPainter] rather than a new
/// pub.dev chart dependency. No chart package exists anywhere else in this
/// app (confirmed via `pubspec.yaml`), and six points is too small a case
/// to justify adding one — this mirrors the web app's own trend chart
/// (Chart.js, green line + soft fill) closely enough without the weight.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.labels,
    required this.values,
    this.height = 148,
    this.valueSuffix = '',
  });

  final List<String> labels;
  final List<double> values;
  final double height;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || values.every((v) => v == 0)) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No recycling activity yet for this range.', style: TextStyle(color: AppColors.n400, fontSize: 12)),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CustomPaint(
              painter: _TrendPainter(values: values),
              child: Container(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: labels
                .map((l) => Expanded(
                      child: Text(
                        l,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: const TextStyle(fontSize: 9.5, color: AppColors.n400),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(values.length > 1 ? i * stepX : size.width / 2, size.height - (values[i] / safeMax) * size.height * 0.9 - 4),
    ];

    // Soft fill beneath the line.
    final fillPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = AppColors.green500.withValues(alpha: 0.12));

    // Line.
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.green600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Points.
    final pointPaint = Paint()..color = AppColors.green700;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.values != values;
}
