import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/emblem.dart';
import '../theme/tokens.dart';

export '../core/emblem.dart' show Emblem;

/// A drawn insignia. Monoline, no fills, so it sits equally well on bone paper
/// and on near-black.
class EmblemMark extends StatelessWidget {
  const EmblemMark({
    super.key,
    required this.emblem,
    this.size = 40,
    this.color,
    this.weight,
  });

  final Emblem emblem;
  final double size;
  final Color? color;
  final double? weight;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _EmblemPainter(
            emblem: emblem,
            color: color ?? context.tk.accent,
            weight: weight ?? math.max(1.0, size * 0.032),
          ),
        ),
      );
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter({required this.emblem, required this.color, required this.weight});

  final Emblem emblem;
  final Color color;
  final double weight;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = weight
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (emblem) {
      case Emblem.mark:
        canvas.drawCircle(c, r * 0.72, p);
        canvas.drawCircle(c, r * 0.16, Paint()..color = color);

      case Emblem.crest:
        canvas.drawCircle(c, r * 0.82, p);
        // A chevron rising through the ring — the "one rank up" gesture.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - r * 0.44, c.dy + r * 0.22)
            ..lineTo(c.dx, c.dy - r * 0.32)
            ..lineTo(c.dx + r * 0.44, c.dy + r * 0.22),
          p,
        );
        for (final dx in [-1.0, 1.0]) {
          canvas.drawLine(
            Offset(c.dx + dx * r * 0.82, c.dy),
            Offset(c.dx + dx * r * 0.52, c.dy),
            p,
          );
        }

      case Emblem.apex:
        canvas.drawCircle(c, r * 0.92, p);
        canvas.drawCircle(c, r * 0.60, p);
        // Eight spokes, alternating length, radiating from the inner ring.
        for (var i = 0; i < 8; i++) {
          final a = (i / 8) * 2 * math.pi - math.pi / 2;
          final inner = r * 0.60;
          final outer = i.isEven ? r * 0.92 : r * 0.76;
          canvas.drawLine(
            Offset(c.dx + math.cos(a) * inner, c.dy + math.sin(a) * inner),
            Offset(c.dx + math.cos(a) * outer, c.dy + math.sin(a) * outer),
            p,
          );
        }
        canvas.drawCircle(c, r * 0.18, Paint()..color = color);

      case Emblem.cipher:
        // A rotated square inside a ring: something granted by the system
        // rather than bought from the world.
        canvas.drawCircle(c, r * 0.86, p);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 0.86, height: r * 0.86),
          p,
        );
        canvas.restore();

      case Emblem.sealed_:
        // A ring closed by a bar across its opening — committed, uneditable.
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.80),
          -math.pi * 0.85,
          math.pi * 1.70,
          false,
          p,
        );
        canvas.drawLine(
          Offset(c.dx - r * 0.30, c.dy + r * 0.62),
          Offset(c.dx + r * 0.30, c.dy + r * 0.62),
          p,
        );
        canvas.drawCircle(c, r * 0.20, p);
    }
  }

  @override
  bool shouldRepaint(_EmblemPainter old) =>
      old.emblem != emblem || old.color != color || old.weight != weight;
}
