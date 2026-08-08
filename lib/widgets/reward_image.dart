import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'emblem.dart';

/// The hero image for a reward.
///
/// Sources are mixed by design — a real product photograph where grounded
/// search found one, a generated still where it did not, and nothing at all for
/// a wish typed thirty seconds ago. All three go through the same frame and the
/// same warm wash, which is what stops a manifest of catalogue shots and
/// generated art from looking like two different apps stapled together.
class RewardImage extends StatelessWidget {
  const RewardImage({
    super.key,
    required this.imageUrl,
    required this.emblem,
    required this.seed,
    this.height,
    this.radius = Radii.brLg,
    this.wash = true,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final Emblem emblem;

  /// Anything stable about the item — its id or name. Drives the generated
  /// plate's angle and hue so the same wish always looks the same.
  final String seed;

  final double? height;
  final BorderRadius radius;

  /// The editorial treatment. Turned off for thumbnails small enough that a
  /// vignette would just muddy them.
  final bool wash;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Image.network(
                imageUrl!,
                fit: fit,
                // A dead link must degrade to the plate, never to a broken icon.
                errorBuilder: (_, __, ___) =>
                    _Plate(seed: seed, emblem: emblem),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: tk.surfaceAlt,
                        child: Center(
                          child: EmblemMark(
                            emblem: emblem,
                            size: 34,
                            color: tk.inkDim.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
              )
            else
              _Plate(seed: seed, emblem: emblem),
            if (wash)
              // A warm gradient scrim, heavier at the foot, so overlaid type is
              // always legible and every source lands in the same register.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: tk.isDark ? 0.10 : 0.06),
                      Colors.transparent,
                      // Heavy enough that white type over a bright product
                      // photograph stays legible in light mode too.
                      Colors.black.withValues(alpha: tk.isDark ? 0.66 : 0.58),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The generated stand-in: a rich duotone field with the item's insignia
/// pressed into it, like a blind-embossed cover before the photography lands.
///
/// Deliberately dark in *both* themes. An item's name is set in white over the
/// bottom of this, and a pale plate in light mode left that text unreadable —
/// a duotone also happens to be exactly what a magazine reaches for when it has
/// no photograph yet.
class _Plate extends StatelessWidget {
  const _Plate({required this.seed, required this.emblem});
  final String seed;
  final Emblem emblem;

  /// The ink the duotone is built on. Warm, near-black, shared by both themes.
  static const _base = Color(0xFF241D14);

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    // Deterministic from the seed, so an item's plate never shifts between
    // builds or between the store and the detail page.
    final h = seed.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final angle = (h % 360) * math.pi / 180;
    final warm = h.isEven ? tk.accent : tk.cool;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(math.cos(angle), math.sin(angle)),
              end: Alignment(-math.cos(angle), -math.sin(angle)),
              colors: [
                Color.alphaBlend(warm.withValues(alpha: 0.55), _base),
                Color.alphaBlend(warm.withValues(alpha: 0.12), _base),
              ],
            ),
          ),
        ),
        Center(
          child: LayoutBuilder(
            builder: (_, c) => EmblemMark(
              emblem: emblem,
              size: math.min(c.maxWidth, c.maxHeight) * 0.40,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
        ),
      ],
    );
  }
}
