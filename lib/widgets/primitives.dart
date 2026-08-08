import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

final _int = NumberFormat('#,##0');
final _dec = NumberFormat('#,##0.0');

String fmt(num n) => _int.format(n);
String fmt1(num n) => _dec.format(n);

/// Euros appear in exactly one place: the reserve, where the figure genuinely
/// is real money. Everywhere else the currency is credits and wears the credit
/// mark instead.
String euro(num n) => '€${NumberFormat('#,##0.00').format(n)}';

/// A hairline rule.
class Rule extends StatelessWidget {
  const Rule({super.key, this.color, this.inset = 0});
  final Color? color;
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: Container(height: 1, color: color ?? context.tk.hairline),
      );
}

/// A wide-tracked caps label — the connective tissue of the whole interface.
class Lbl extends StatelessWidget {
  const Lbl(this.text, {super.key, this.color, this.size = 10, this.weight});
  final String text;
  final Color? color;
  final double size;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Kind.label(context,
            size: size, color: color, w: weight ?? FontWeight.w600),
      );
}

/// A section marker: a caps label with a rule running off to the right, lifted
/// straight from the way a magazine opens a department.
class SectionHead extends StatelessWidget {
  const SectionHead(this.text, {super.key, this.trailing, this.color});
  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      children: [
        Lbl(text, color: color ?? tk.inkDim),
        const SizedBox(width: Gap.md),
        Expanded(child: Container(height: 1, color: tk.hairline)),
        if (trailing != null) ...[const SizedBox(width: Gap.md), trailing!],
      ],
    );
  }
}

/// Something on the left, something on the right, and no way for either to
/// overflow.
///
/// The interface is full of these pairs — "139 XP TO TIER 53" against "53D LEFT
/// IN SEASON" — and wide-tracked caps make them just wide enough to burst a
/// 320pt screen. Both sides shrink, then scale, before anything overflows.
class SpreadRow extends StatelessWidget {
  const SpreadRow({
    super.key,
    required this.left,
    required this.right,
    this.gap = Gap.sm,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final Widget left;
  final Widget right;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: left,
            ),
          ),
          SizedBox(width: gap),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: right,
            ),
          ),
        ],
      );
}

/// A number that slides to its new value instead of snapping.
///
/// The whole product rests on the promise that something moves the moment
/// something real happens, so no figure in it is ever allowed to just cut.
class NumericFlow extends StatelessWidget {
  const NumericFlow(
    this.value, {
    super.key,
    required this.style,
    this.duration = const Duration(milliseconds: 750),
    this.formatter,
  });

  final num value;
  final TextStyle style;
  final Duration duration;
  final String Function(num)? formatter;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        // `begin` applies on first build only; afterwards the builder animates
        // from wherever it currently sits to the new `end`.
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text((formatter ?? fmt)(v), style: style),
      );
}

/// A soft progress bar. Rounded, accent-filled, with an optional track tint.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.color,
    this.trackColor,
    this.animate = true,
  });

  final double progress;
  final double height;
  final Color? color;
  final Color? trackColor;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final p = progress.clamp(0.0, 1.0);
    final fill = color ?? tk.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LayoutBuilder(
        builder: (_, c) => Stack(
          children: [
            Container(
              height: height,
              width: c.maxWidth,
              color: trackColor ?? tk.hairline,
            ),
            if (animate)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: p),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Container(
                  height: height,
                  width: c.maxWidth * v,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: LinearGradient(
                      colors: [fill.withValues(alpha: 0.75), fill],
                    ),
                  ),
                ),
              )
            else
              Container(
                height: height,
                width: c.maxWidth * p,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  color: fill,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A frosted pane. Used for the companion, floating chips and anything that
/// should sit visibly *over* the page rather than in it.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = Radii.brLg,
    this.padding = const EdgeInsets.all(Gap.md),
    this.blur = 18,
    this.tint,
    this.border = true,
  });

  final Widget child;
  final BorderRadius radius;
  final EdgeInsets padding;
  final double blur;
  final Color? tint;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? tk.glass,
            borderRadius: radius,
            border: border
                ? Border.all(color: tk.glassEdge.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A raised card. The store shelf, the ladder rung, the quest row.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.md),
    this.radius = Radii.brLg,
    this.onTap,
    this.color,
    this.borderColor,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius radius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? tk.surface,
          borderRadius: radius,
          border: Border.all(color: borderColor ?? tk.hairline),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: tk.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// The one button. Fills with the accent when it is the primary move.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.danger = false,
    this.dense = false,
    this.expand = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final bool dense;
  final bool expand;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final enabled = onTap != null;

    final fg = !enabled
        ? tk.inkDim
        : danger
            ? tk.alert
            : primary
                ? tk.onAccent
                : tk.ink;
    final bg = !enabled
        ? tk.surfaceAlt
        : primary
            ? tk.accent
            : danger
                ? tk.alertSoft
                : Colors.transparent;
    final border = !enabled
        ? tk.hairline
        : primary
            ? tk.accent
            : danger
                ? tk.alert.withValues(alpha: 0.4)
                : tk.hairlineStrong;

    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 12 : Gap.lg,
        vertical: dense ? 9 : 14,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(dense ? 10 : 14),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: Gap.sm)],
          // Labels are wide-tracked caps, so a three-across row of buttons
          // sits right on the edge of overflowing. Shrink rather than break —
          // an overflow stripe in a shipped build is unforgivable.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                style: Kind.label(context,
                    size: dense ? 9.5 : 10.5, color: fg, w: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

/// A small status pill: money tier, cadence, kind.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color, this.filled = false, this.leading});
  final String text;
  final Color? color;
  final bool filled;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = color ?? tk.inkDim;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: leading == null ? 9 : 7, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(color: c.withValues(alpha: filled ? 0.0 : 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          // Tags carry user-supplied and generated strings; none of them may
          // burst the row they sit in.
          Flexible(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  Kind.label(context, size: 9, color: c, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty state. Every list degrades to one of these rather than to a
/// spinner or a crash.
class VoidState extends StatelessWidget {
  const VoidState({super.key, required this.line, this.sub, this.action});
  final String line;
  final String? sub;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg, horizontal: Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line, style: Kind.serif(context, size: 20)),
            if (sub != null) ...[
              const SizedBox(height: Gap.sm),
              Text(sub!, style: Kind.body(context, size: 13.5)),
            ],
            if (action != null) ...[const SizedBox(height: Gap.lg), action!],
          ],
        ),
      );
}

/// Renders a duration the way a countdown should read: coarse when far away,
/// precise when it is about to matter.
String countdown(Duration d) {
  if (d.inSeconds <= 0) return 'EXPIRED';
  if (d.inDays >= 2) return '${d.inDays}D';
  if (d.inHours >= 1) return '${d.inHours}H ${d.inMinutes % 60}M';
  if (d.inMinutes >= 1) return '${d.inMinutes}M';
  return '${d.inSeconds}S';
}
