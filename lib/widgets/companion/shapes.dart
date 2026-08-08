import 'dart:math' as math;
import 'dart:ui';

import '../../models/appearance.dart';

/// Builds the overseer's silhouette.
///
/// Every shape is a rounded polygon or a hand-shaped path, so the same eye,
/// sheen and edge treatment can be laid over any of them without the painter
/// knowing which one it drew.
Path overseerPath(OverseerShape shape, Size size) {
  final r = size.width * shape.cornerFactor;
  final w = size.width;
  final h = size.height;
  final c = Offset(w / 2, h / 2);

  List<Offset> polygon(int sides, {double rotation = -math.pi / 2, double squash = 1}) {
    final rx = w / 2 * 0.96;
    final ry = h / 2 * 0.96 * squash;
    return [
      for (var i = 0; i < sides; i++)
        Offset(
          c.dx + math.cos(rotation + i * 2 * math.pi / sides) * rx,
          c.dy + math.sin(rotation + i * 2 * math.pi / sides) * ry,
        ),
    ];
  }

  /// A star with [points] tips, alternating between two radii.
  List<Offset> star(int points, double innerRatio) {
    final rx = w / 2 * 0.98;
    final ry = h / 2 * 0.98;
    final verts = <Offset>[];
    for (var i = 0; i < points * 2; i++) {
      final f = i.isEven ? 1.0 : innerRatio;
      final a = -math.pi / 2 + i * math.pi / points;
      verts.add(Offset(c.dx + math.cos(a) * rx * f, c.dy + math.sin(a) * ry * f));
    }
    return verts;
  }

  return switch (shape) {
    OverseerShape.triangle => _rounded(polygon(3), r),
    OverseerShape.invertedTriangle =>
      _rounded(polygon(3, rotation: math.pi / 2), r),
    OverseerShape.diamond => _rounded(polygon(4), r),
    OverseerShape.square => _rounded(polygon(4, rotation: -math.pi / 4), r),
    OverseerShape.pentagon => _rounded(polygon(5), r),
    OverseerShape.hexagon => _rounded(polygon(6), r),
    OverseerShape.heptagon => _rounded(polygon(7), r),
    OverseerShape.octagon => _rounded(polygon(8), r),
    OverseerShape.starFour => _rounded(star(4, 0.42), r * 0.6),
    OverseerShape.starSix => _rounded(star(6, 0.52), r * 0.6),
    OverseerShape.blade => _rounded(
        [
          Offset(c.dx, h * 0.02),
          Offset(w * 0.86, c.dy),
          Offset(c.dx, h * 0.98),
          Offset(w * 0.14, c.dy),
        ],
        r * 0.7),

    // ------------------------------------------------- hand-shaped outliers
    OverseerShape.orb => Path()
      ..addOval(Rect.fromCircle(center: c, radius: w / 2 * 0.96)),

    OverseerShape.monolith => Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: w * 0.62, height: h * 0.96),
        Radius.circular(r),
      )),

    OverseerShape.chevron => _rounded(
        [
          Offset(c.dx, h * 0.06),
          Offset(w * 0.96, h * 0.62),
          Offset(w * 0.96, h * 0.94),
          Offset(c.dx, h * 0.42),
          Offset(w * 0.04, h * 0.94),
          Offset(w * 0.04, h * 0.62),
        ],
        r * 0.5),

    // A shield: square shoulders, a curved point. Built by hand because the
    // bottom is an arc rather than a corner.
    OverseerShape.shield => Path()
      ..moveTo(w * 0.08, h * 0.12)
      ..lineTo(w * 0.92, h * 0.12)
      ..lineTo(w * 0.92, h * 0.52)
      ..quadraticBezierTo(w * 0.92, h * 0.92, c.dx, h * 0.98)
      ..quadraticBezierTo(w * 0.08, h * 0.92, w * 0.08, h * 0.52)
      ..close(),

    // A teardrop: a circle drawn up into a point.
    OverseerShape.teardrop => Path()
      ..moveTo(c.dx, h * 0.02)
      ..quadraticBezierTo(w * 0.98, h * 0.55, c.dx, h * 0.98)
      ..quadraticBezierTo(w * 0.02, h * 0.55, c.dx, h * 0.02)
      ..close(),
  };
}

/// Rounds the corners of an arbitrary polygon.
///
/// Backs off along both edges of each vertex by an amount scaled to how acute
/// the corner is, then joins the two points with an arc — which is what stops a
/// sharp star tip from eating its own neighbours.
Path _rounded(List<Offset> vertices, double radius) {
  if (radius <= 0.5 || vertices.length < 3) {
    final p = Path()..moveTo(vertices.first.dx, vertices.first.dy);
    for (final v in vertices.skip(1)) {
      p.lineTo(v.dx, v.dy);
    }
    return p..close();
  }

  final path = Path();
  for (var i = 0; i < vertices.length; i++) {
    final prev = vertices[(i - 1 + vertices.length) % vertices.length];
    final curr = vertices[i];
    final next = vertices[(i + 1) % vertices.length];

    final toPrev = _unit(prev - curr);
    final toNext = _unit(next - curr);

    final dot = (toPrev.dx * toNext.dx + toPrev.dy * toNext.dy).clamp(-1.0, 1.0);
    final angle = math.acos(dot);
    if (angle < 0.01 || angle > math.pi - 0.01) {
      path.lineTo(curr.dx, curr.dy);
      continue;
    }

    // Never back off further than half the shorter adjoining edge, or opposite
    // corners of a small shape would overlap and invert the path.
    final maxBackoff =
        math.min((prev - curr).distance, (next - curr).distance) / 2;
    final backoff = math.min(radius / math.tan(angle / 2), maxBackoff);

    final start = curr + toPrev * backoff;
    final end = curr + toNext * backoff;

    if (i == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    // Cross product sign tells us which way the corner turns, so concave
    // vertices (star inner points) arc the correct way.
    final cross = toPrev.dx * toNext.dy - toPrev.dy * toNext.dx;
    path.arcToPoint(end,
        radius: Radius.circular(backoff), clockwise: cross < 0);
  }
  return path..close();
}

Offset _unit(Offset v) {
  final len = v.distance;
  return len == 0 ? Offset.zero : v / len;
}
