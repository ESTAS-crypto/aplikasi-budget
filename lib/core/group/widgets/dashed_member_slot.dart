import 'package:flutter/material.dart';
import '../../theme/putar_theme.dart';

/// Painter Garis Putus-putus Neo-Brutalist
class DashedRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  const DashedRRectPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(
          strokeWidth / 2,
          strokeWidth / 2,
          size.width - strokeWidth,
          size.height - strokeWidth,
        ),
        Radius.circular(radius),
      ));

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter oldDelegate) => false;
}

/// Slot Anggota Putus-putus ("Menunggu anggota...")
class DashedMemberSlot extends StatelessWidget {
  final String label;

  const DashedMemberSlot({
    super.key,
    this.label = 'Menunggu teman bergabung...',
  });

  @override
  Widget build(BuildContext context) {
    final t = context.putarTheme;
    return Container(
      width: double.infinity,
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CustomPaint(
        painter: DashedRRectPainter(
          color: t.ink,
          strokeWidth: 2.0,
          radius: 12.0,
        ),
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: t.ink.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+',
                    style: t.buttonSmall.copyWith(
                      color: t.ink.withValues(alpha: 0.5),
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall.copyWith(
                    color: t.textSecondary.withValues(alpha: 0.8),
                    fontWeight: t.weightSemiBold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

