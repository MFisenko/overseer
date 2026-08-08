import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

/// The currency mark.
///
/// Credits are not euros and must never wear a euro sign — the peg to real
/// money lives in the reserve readout, and everywhere else the number is a
/// game currency with its own identity. This is a monoline geometric glyph: a
/// three-quarter ring struck through by a bar, drawn rather than typeset so it
/// stays crisp at any size and always matches the surrounding weight.
class CreditMark extends StatelessWidget {
  const CreditMark({super.key, this.size = 14, this.color, this.weight});

  final double size;
  final Color? color;

  /// Stroke width. Defaults to a proportion of [size] so the mark optically
  /// matches whatever figure it sits beside.
  final double? weight;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CreditMarkPainter(
            color: color ?? context.tk.accent,
            weight: weight ?? size * 0.095,
          ),
        ),
      );
}

class _CreditMarkPainter extends CustomPainter {
  _CreditMarkPainter({required this.color, required this.weight});
  final Color color;
  final double weight;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = weight
      ..strokeCap = StrokeCap.round;

    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.34;

    // A C, open to the right. The opening is what stops it reading as a plain
    // circle struck through — which is what the first version looked like, and
    // which is already the symbol for several other things.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi * 0.28,
      math.pi * 1.56,
      false,
      p,
    );

    // Two short bars, the way most non-dollar currency marks are built. Kept
    // inside the C's width so the glyph stays compact beside a figure.
    final barHalf = r * 0.92;
    for (final dy in [-r * 0.34, r * 0.34]) {
      canvas.drawLine(
        Offset(c.dx - barHalf, c.dy + dy),
        Offset(c.dx + barHalf * 0.45, c.dy + dy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_CreditMarkPainter old) =>
      old.color != color || old.weight != weight;
}

/// A credit figure with its mark, sized and coloured as one unit.
class CreditAmount extends StatelessWidget {
  const CreditAmount(
    this.amount, {
    super.key,
    this.size = 15,
    this.color,
    this.weight = FontWeight.w500,
    this.signed = false,
    this.markGap = 5,
  });

  final num amount;
  final double size;
  final Color? color;
  final FontWeight weight;

  /// Prefixes an explicit + or −, for deltas.
  final bool signed;

  final double markGap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tk.ink;
    final magnitude = amount.abs();
    final sign = !signed ? '' : (amount < 0 ? '−' : '+');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CreditMark(size: size * 0.92, color: c),
        SizedBox(width: markGap),
        // Six-figure balances in a narrow column would otherwise overflow.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$sign${_group(magnitude)}',
              maxLines: 1,
              style: Kind.figure(context, size: size, color: c, w: weight),
            ),
          ),
        ),
      ],
    );
  }

  static String _group(num n) {
    final s = n.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}
