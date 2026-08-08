import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

/// The shard mark.
///
/// Deliberately unlike the credit mark: angular where that one is round, so the
/// two currencies are never confused at a glance. A credit is real money; a
/// shard is time. They should not look related.
class ShardMark extends StatelessWidget {
  const ShardMark({super.key, this.size = 14, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ShardPainter(color ?? context.tk.cool),
        ),
      );
}

class _ShardPainter extends CustomPainter {
  _ShardPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.46;

    // A cut gem: a tall hexagon with an inner facet line.
    final outer = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = Offset(c.dx + math.cos(a) * r * 0.72, c.dy + math.sin(a) * r);
      i == 0 ? outer.moveTo(p.dx, p.dy) : outer.lineTo(p.dx, p.dy);
    }
    outer.close();

    canvas.drawPath(outer, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.width * 0.09)
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    // The facet, which is what stops it reading as a plain hexagon.
    canvas.drawLine(
      Offset(c.dx - r * 0.72, c.dy - r * 0.5),
      Offset(c.dx + r * 0.72, c.dy - r * 0.5),
      Paint()
        ..strokeWidth = math.max(0.8, size.width * 0.07)
        ..color = color.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_ShardPainter old) => old.color != color;
}

/// A shard figure with its mark.
class ShardAmount extends StatelessWidget {
  const ShardAmount(this.amount, {super.key, this.size = 15, this.color});

  final int amount;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tk.cool;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShardMark(size: size, color: c),
        const SizedBox(width: 5),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$amount',
                maxLines: 1,
                style: Kind.figure(context,
                    size: size, color: c, w: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
