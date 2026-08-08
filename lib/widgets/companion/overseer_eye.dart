import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/appearance.dart';
import '../../models/companion.dart';
import 'shapes.dart';

/// The overseer: a shape of some material, with a single eye.
///
/// It blinks, it drifts, and it fixes on things. When something needs attention
/// the pupil narrows and the body pulses. None of this is decoration — the eye
/// is how the app conveys that progress is being *witnessed*, which is the
/// entire emotional premise of the product.
///
/// Shape, finish and paint are independent, so this one widget renders every
/// combination in the catalogue without knowing which it is drawing.
class OverseerEye extends StatefulWidget {
  const OverseerEye({
    super.key,
    required this.mood,
    required this.appearance,
    this.size = 66,

    /// Where the eye should look, −1..1 on each axis. Null lets it wander.
    this.lookAt,

    /// Suppresses the blur pass. Blur is expensive and pointless when the
    /// overseer is drawn over a flat panel rather than over the page.
    this.flat = false,

    /// Days of unbroken streak. Drives the aura — the overseer visibly
    /// intensifies the longer a habit holds, which is the whole point of
    /// putting it on screen at all times.
    this.streakDays = 0,
  });

  final CompanionMood mood;
  final Appearance appearance;
  final double size;
  final Offset? lookAt;
  final bool flat;
  final int streakDays;

  @override
  State<OverseerEye> createState() => _OverseerEyeState();
}

class _OverseerEyeState extends State<OverseerEye> with TickerProviderStateMixin {
  late final AnimationController _clock;
  late final AnimationController _blink;
  final _rng = math.Random();

  /// Held so it can be cancelled. A bare `Future.delayed` chain keeps a pending
  /// timer alive after the widget is gone, which leaks and — more visibly —
  /// makes every widget test that renders the overseer fail at teardown.
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat();
    _blink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _scheduleBlink();
  }

  /// Blinks are irregular on purpose. A metronome reads as a loading spinner;
  /// an uneven blink reads as something alive and watching.
  void _scheduleBlink() {
    final base = switch (widget.mood) {
      CompanionMood.alert => 5200,
      CompanionMood.ominous => 9000,
      CompanionMood.watching => 3600,
      _ => 2600,
    };
    _blinkTimer?.cancel();
    _blinkTimer =
        Timer(Duration(milliseconds: base + _rng.nextInt(2600)), () async {
      if (!mounted) return;
      await _blink.forward();
      if (!mounted) return;
      await _blink.reverse();
      if (mounted) _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _clock.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appearance;
    final s = widget.size;

    return AnimatedBuilder(
      animation: Listenable.merge([_clock, _blink]),
      builder: (_, __) {
        final t = _clock.value * 2 * math.pi;

        final (pupilScale, pulseRate, pulseDepth) = switch (widget.mood) {
          CompanionMood.alert => (0.55, 3.0, 0.05),
          CompanionMood.ominous => (1.25, 0.5, 0.02),
          CompanionMood.pleased => (0.85, 1.0, 0.035),
          CompanionMood.watching => (0.95, 0.8, 0.02),
          CompanionMood.idle => (1.0, 0.6, 0.015),
        };
        final pulse = 1 + math.sin(t * pulseRate) * pulseDepth;

        final gaze = widget.lookAt ??
            Offset(math.sin(t) * 0.5 + math.sin(t * 0.37) * 0.3,
                math.cos(t * 0.71) * 0.35);

        final body = _Body(
          appearance: a,
          sheenPhase: (math.sin(t * 0.4) + 1) / 2,
        );

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: s,
            height: s,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The aura sits behind everything and is the only part of the
                // overseer that reports progress rather than mood.
                if (widget.streakDays > 0)
                  CustomPaint(
                    painter: _AuraPainter(
                      appearance: a,
                      intensity: _auraIntensity(widget.streakDays),
                      rings: _auraRings(widget.streakDays),
                      motes: _auraMotes(widget.streakDays),
                      phase: _clock.value,
                    ),
                  ),
                CustomPaint(painter: _GlowPainter(a)),
                if (a.finish.blurs && !widget.flat)
                  ClipPath(
                    clipper: _ShapeClipper(a.shape),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                          sigmaX: a.finish.blurSigma, sigmaY: a.finish.blurSigma),
                      child: body,
                    ),
                  )
                else
                  ClipPath(clipper: _ShapeClipper(a.shape), child: body),
                CustomPaint(painter: _EdgePainter(a)),
                if (a.accessory != OverseerAccessory.none)
                  CustomPaint(painter: _AccessoryPainter(a, t)),
                CustomPaint(
                  painter: _EyePainter(
                    appearance: a,
                    blink: Curves.easeInOut.transform(_blink.value),
                    gaze: gaze,
                    pupilScale: pupilScale,
                    slit: widget.mood == CompanionMood.alert,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Streak → aura, in four visible steps. Deliberately coarse: the user should
/// be able to tell at a glance which band they are in, not squint at a gradient.
double _auraIntensity(int streak) {
  if (streak >= 100) return 1.0;
  if (streak >= 30) return 0.78;
  if (streak >= 14) return 0.58;
  if (streak >= 7) return 0.4;
  if (streak >= 3) return 0.24;
  return 0.12;
}

int _auraRings(int streak) {
  if (streak >= 60) return 3;
  if (streak >= 14) return 2;
  if (streak >= 3) return 1;
  return 0;
}

/// Orbiting motes appear only once a habit is genuinely established.
int _auraMotes(int streak) {
  if (streak >= 100) return 8;
  if (streak >= 30) return 5;
  if (streak >= 14) return 3;
  return 0;
}

/// The visible reward for an unbroken streak.
///
/// Nothing here is text. A user glancing at the corner of the screen should be
/// able to tell that something has been held for a month without reading a
/// number — and should feel the loss when it goes dark.
class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.appearance,
    required this.intensity,
    required this.rings,
    required this.motes,
    required this.phase,
  });

  final Appearance appearance;
  final double intensity;
  final int rings;
  final int motes;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final tint = appearance.paint.edge;
    final t = phase * 2 * math.pi;

    // A soft halo that breathes.
    final breathe = 1 + math.sin(t * 0.8) * 0.06;
    canvas.drawCircle(
      c,
      r * 1.15 * breathe,
      Paint()
        ..color = tint.withValues(alpha: 0.22 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
    );

    // Concentric rings, each drifting at its own rate so the whole thing never
    // reads as a single spinning object.
    for (var i = 0; i < rings; i++) {
      final spread = 1.16 + i * 0.13;
      final wobble = math.sin(t * (0.5 + i * 0.3)) * 0.02;
      canvas.drawCircle(
        c,
        r * (spread + wobble),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = tint.withValues(alpha: (0.30 - i * 0.07) * intensity),
      );
    }

    // Motes orbiting the outermost ring.
    if (motes > 0) {
      final orbit = r * (1.16 + (rings - 1).clamp(0, 3) * 0.13);
      for (var i = 0; i < motes; i++) {
        final a = t * 0.35 + i * 2 * math.pi / motes;
        final p = Offset(c.dx + math.cos(a) * orbit, c.dy + math.sin(a) * orbit);
        canvas.drawCircle(
          p,
          r * 0.045,
          Paint()
            ..color = tint.withValues(alpha: 0.85 * intensity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.phase != phase ||
      old.intensity != intensity ||
      old.rings != rings ||
      old.motes != motes ||
      old.appearance != appearance;
}

class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper(this.shape);
  final OverseerShape shape;

  @override
  Path getClip(Size size) => overseerPath(shape, size);

  @override
  bool shouldReclip(_ShapeClipper old) => old.shape != shape;
}

/// The fill and the specular streak, clipped to the silhouette by the caller.
class _Body extends StatelessWidget {
  const _Body({required this.appearance, required this.sheenPhase});
  final Appearance appearance;
  final double sheenPhase;

  @override
  Widget build(BuildContext context) {
    final paint = appearance.paint;
    final f = appearance.finish;
    final alpha = 1 - f.transparency;

    return CustomPaint(
      painter: _FillPainter(
        base: paint.body.withValues(alpha: alpha),
        highlight: paint.edge.withValues(alpha: alpha * f.sheen * 0.5),
        sheen: paint.edge.withValues(alpha: f.sheen * 0.45),
        sheenPhase: sheenPhase,
        brushed: f == OverseerFinish.brushed || f == OverseerFinish.carbon,
      ),
    );
  }
}

class _FillPainter extends CustomPainter {
  _FillPainter({
    required this.base,
    required this.highlight,
    required this.sheen,
    required this.sheenPhase,
    required this.brushed,
  });

  final Color base;
  final Color highlight;
  final Color sheen;
  final double sheenPhase;
  final bool brushed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [Color.alphaBlend(highlight, base), base],
        ),
    );

    // Brushed and carbon get fine directional lines, which is most of what
    // separates them from a flat matte at this size.
    if (brushed) {
      final line = Paint()
        ..color = highlight.withValues(alpha: highlight.a * 0.5)
        ..strokeWidth = 0.6;
      for (var y = 0.0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    }

    // A soft diagonal band drifting across the face, so the material looks lit
    // by something moving rather than painted on.
    final x = size.width * (sheenPhase * 1.4 - 0.2);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x - size.width * 0.35, 0),
          Offset(x + size.width * 0.35, size.height),
          [sheen.withValues(alpha: 0), sheen, sheen.withValues(alpha: 0)],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.sheenPhase != sheenPhase || old.base != base || old.sheen != sheen;
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.appearance);
  final Appearance appearance;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = appearance.paint.edge
        .withValues(alpha: 0.28 * appearance.finish.glowScale.clamp(0, 2));
    canvas.drawPath(
      overseerPath(appearance.shape, size),
      Paint()
        ..color = glow
        ..maskFilter = MaskFilter.blur(
            BlurStyle.outer, 20 * appearance.finish.glowScale),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.appearance != appearance;
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.appearance);
  final Appearance appearance;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = appearance.paint.edge;
    canvas.drawPath(
      overseerPath(appearance.shape, size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = appearance.finish.edgeWidth
        ..strokeJoin = StrokeJoin.round
        // Brighter along the top-left, where the light is.
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          [edge, edge.withValues(alpha: edge.a * 0.3)],
        ),
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.appearance != appearance;
}

/// Worn over the body. Drawn after the edge so it reads as *on* the overseer
/// rather than suspended inside it.
class _AccessoryPainter extends CustomPainter {
  _AccessoryPainter(this.appearance, this.phase);
  final Appearance appearance;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);
    final edge = appearance.paint.edge;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = edge;
    final fill = Paint()..color = edge;

    switch (appearance.accessory) {
      case OverseerAccessory.none:
        return;

      case OverseerAccessory.halo:
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx, h * 0.10), width: w * 0.52, height: h * 0.13),
          line,
        );

      case OverseerAccessory.crown:
        final base = h * 0.16;
        final p = Path()..moveTo(w * 0.30, base);
        for (var i = 0; i < 3; i++) {
          final x0 = w * (0.30 + i * 0.133);
          p.lineTo(x0 + w * 0.066, base - h * 0.10);
          p.lineTo(x0 + w * 0.133, base);
        }
        canvas.drawPath(p, line);

      case OverseerAccessory.antenna:
        canvas.drawLine(
            Offset(c.dx, h * 0.14), Offset(c.dx, h * 0.02), line);
        // Bobs gently, so it reads as attached to something alive.
        final bob = math.sin(phase * 2) * h * 0.012;
        canvas.drawCircle(Offset(c.dx, h * 0.02 + bob), w * 0.055, fill);

      case OverseerAccessory.visor:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, h * 0.55), width: w * 0.78, height: h * 0.13),
            Radius.circular(h * 0.065),
          ),
          Paint()..color = edge.withValues(alpha: 0.45),
        );

      case OverseerAccessory.wings:
        for (final dir in [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(c.dx + dir * w * 0.34, h * 0.48)
            ..quadraticBezierTo(c.dx + dir * w * 0.62, h * 0.30,
                c.dx + dir * w * 0.56, h * 0.62)
            ..quadraticBezierTo(c.dx + dir * w * 0.50, h * 0.58,
                c.dx + dir * w * 0.34, h * 0.62);
          canvas.drawPath(p, line);
        }

      case OverseerAccessory.shackle:
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(c.dx, h * 0.86), width: w * 0.44, height: h * 0.22),
          0,
          math.pi,
          false,
          line,
        );

      case OverseerAccessory.laurel:
        for (final dir in [-1.0, 1.0]) {
          for (var i = 0; i < 4; i++) {
            final t = 0.30 + i * 0.14;
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(c.dx + dir * w * 0.40, h * t),
                width: w * 0.16,
                height: h * 0.075,
              ),
              line..strokeWidth = w * 0.028,
            );
          }
        }

      case OverseerAccessory.spike:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - w * 0.07, h * 0.16)
            ..lineTo(c.dx, h * 0.0)
            ..lineTo(c.dx + w * 0.07, h * 0.16)
            ..close(),
          fill,
        );

      case OverseerAccessory.orbit:
        // A ring seen edge-on, rotating.
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(phase * 0.6);
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: w * 1.02, height: h * 0.30),
          line..strokeWidth = w * 0.03,
        );
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AccessoryPainter old) =>
      old.appearance != appearance || old.phase != phase;
}

class _EyePainter extends CustomPainter {
  _EyePainter({
    required this.appearance,
    required this.blink,
    required this.gaze,
    required this.pupilScale,
    required this.slit,
  });

  final Appearance appearance;
  final double blink;
  final Offset gaze;
  final double pupilScale;
  final bool slit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = appearance.paint;
    final w = size.width;

    // Triangular shapes carry their visual mass low; radial ones are centred.
    final lowSlung = switch (appearance.shape) {
      OverseerShape.triangle || OverseerShape.shield || OverseerShape.teardrop => true,
      _ => false,
    };
    final eye = Offset(w / 2, size.height * (lowSlung ? 0.64 : 0.5));
    final irisR = w * 0.135;

    final open = 1 - blink;
    if (open <= 0.02) {
      // Shut: a single hairline, which is more unsettling than a closed lid.
      canvas.drawLine(
        Offset(eye.dx - irisR, eye.dy),
        Offset(eye.dx + irisR, eye.dy),
        Paint()
          ..color = paint.iris
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    canvas.save();
    canvas.clipRect(Rect.fromCenter(
      center: eye,
      width: irisR * 3,
      height: irisR * 2.3 * open,
    ));

    canvas.drawCircle(
      eye,
      irisR * 1.9,
      Paint()
        ..color = paint.iris.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(eye, irisR, Paint()..color = paint.iris);

    final pupilR = irisR * 0.46 * pupilScale;
    final travel = irisR - pupilR - 1;
    final look = eye + Offset(gaze.dx * travel, gaze.dy * travel);

    final ink = Paint()..color = paint.pupil;

    // `slit` is the alert *mood* overriding the chosen eye — scrutiny reads the
    // same whatever the overseer normally looks like.
    if (slit) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: look, width: pupilR * 0.8, height: pupilR * 2.4),
          Radius.circular(pupilR * 0.4),
        ),
        ink,
      );
    } else {
      switch (appearance.eye) {
        case OverseerEyeKind.round:
          canvas.drawCircle(look, pupilR, ink);

        case OverseerEyeKind.slit:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: look, width: pupilR * 0.7, height: pupilR * 2.2),
              Radius.circular(pupilR * 0.35),
            ),
            ink,
          );

        case OverseerEyeKind.compound:
          // A cluster of small cells, insect-like.
          for (var i = 0; i < 7; i++) {
            final ang = i * 2 * math.pi / 6;
            final off = i == 6
                ? Offset.zero
                : Offset(math.cos(ang), math.sin(ang)) * pupilR * 0.62;
            canvas.drawCircle(look + off, pupilR * 0.34, ink);
          }

        case OverseerEyeKind.cross:
          final bar = Paint()
            ..color = paint.pupil
            ..strokeWidth = pupilR * 0.55
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(look - Offset(pupilR, 0), look + Offset(pupilR, 0), bar);
          canvas.drawLine(look - Offset(0, pupilR), look + Offset(0, pupilR), bar);

        case OverseerEyeKind.ring:
          canvas.drawCircle(
            look,
            pupilR * 0.85,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = pupilR * 0.5
              ..color = paint.pupil,
          );

        case OverseerEyeKind.triad:
          for (var i = 0; i < 3; i++) {
            final ang = -math.pi / 2 + i * 2 * math.pi / 3;
            canvas.drawCircle(
                look + Offset(math.cos(ang), math.sin(ang)) * pupilR * 0.55,
                pupilR * 0.4,
                ink);
          }

        case OverseerEyeKind.void_:
          // No pupil at all — the iris is a hole. Deeply unsettling, which is
          // the point of it being a late unlock.
          canvas.drawCircle(eye, irisR * 0.82,
              Paint()..color = paint.pupil);

        case OverseerEyeKind.scanner:
          // A horizontal bar that tracks left and right rather than a pupil.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(look.dx, eye.dy),
                  width: irisR * 1.5,
                  height: pupilR * 0.75),
              Radius.circular(pupilR * 0.35),
            ),
            ink,
          );
      }
    }

    // A catchlight, offset from the gaze, so the eye reads as wet.
    canvas.drawCircle(
      eye + Offset(-irisR * 0.34, -irisR * 0.38),
      irisR * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_EyePainter old) =>
      old.blink != blink ||
      old.gaze != gaze ||
      old.pupilScale != pupilScale ||
      old.slit != slit ||
      old.appearance != appearance;
}
