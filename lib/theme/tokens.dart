import 'package:flutter/material.dart';

/// Every colour in the app, in both modes, in one object.
///
/// The look is luxury editorial rather than science fiction: warm bone paper in
/// light, warm near-black in dark, brass and jade as the only two accents, and
/// imagery carrying the drama instead of the chrome. Widgets read these through
/// `context.tk` and never hardcode a colour, which is what makes the two modes
/// genuinely equal rather than one being a tinted afterthought.
@immutable
class Tokens extends ThemeExtension<Tokens> {
  // ------------------------------------------------------------- surfaces
  /// The page itself. Warm on both sides — a neutral grey would read as
  /// software, and this is meant to read as print.
  final Color canvas;

  /// Raised planes: cards, sheets, the store shelf.
  final Color surface;

  /// A recessed or alternate plane, for wells and inset rails.
  final Color surfaceAlt;

  /// Translucent fill behind blurred glass.
  final Color glass;

  /// The bright edge along the top of a glass pane.
  final Color glassEdge;

  // ------------------------------------------------------------------ ink
  final Color ink;
  final Color inkMid;
  final Color inkDim;

  /// Ink that sits on top of an accent fill.
  final Color onAccent;

  // ---------------------------------------------------------------- lines
  final Color hairline;
  final Color hairlineStrong;

  // --------------------------------------------------------------- accent
  /// Brass. Money, tiers, the credit mark, anything earned.
  final Color accent;
  final Color accentSoft;

  /// Jade. Progress, confirmation, anything alive.
  final Color cool;
  final Color coolSoft;

  /// Reserved for expiry pressure and genuine failure.
  final Color alert;
  final Color alertSoft;

  // --------------------------------------------------------------- depth
  final Color shadow;
  final bool isDark;

  const Tokens({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.glass,
    required this.glassEdge,
    required this.ink,
    required this.inkMid,
    required this.inkDim,
    required this.onAccent,
    required this.hairline,
    required this.hairlineStrong,
    required this.accent,
    required this.accentSoft,
    required this.cool,
    required this.coolSoft,
    required this.alert,
    required this.alertSoft,
    required this.shadow,
    required this.isDark,
  });

  /// Bone paper. The default: the app should feel like an open magazine before
  /// it feels like a terminal.
  static const light = Tokens(
    canvas: Color(0xFFF7F4EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFEAE1),
    glass: Color(0xCCFFFFFF),
    glassEdge: Color(0xE6FFFFFF),
    ink: Color(0xFF17140F),
    inkMid: Color(0xFF5E574C),
    inkDim: Color(0xFF9A9184),
    onAccent: Color(0xFF1A1408),
    hairline: Color(0xFFE4DCD0),
    hairlineStrong: Color(0xFFCFC4B4),
    accent: Color(0xFFA8762A),
    accentSoft: Color(0x1FA8762A),
    cool: Color(0xFF0C7F73),
    coolSoft: Color(0x1A0C7F73),
    alert: Color(0xFFB23A26),
    alertSoft: Color(0x1AB23A26),
    shadow: Color(0x14100C06),
    isDark: false,
  );

  /// Warm near-black. Not the old void — there is brown in it, so brass and
  /// photography sit on it without going cold.
  static const dark = Tokens(
    canvas: Color(0xFF0D0B08),
    surface: Color(0xFF17130E),
    surfaceAlt: Color(0xFF201A13),
    glass: Color(0x99201A13),
    glassEdge: Color(0x33FFFFFF),
    ink: Color(0xFFF6F1E7),
    inkMid: Color(0xFFAFA595),
    inkDim: Color(0xFF6F6656),
    onAccent: Color(0xFF17130E),
    hairline: Color(0xFF2B241B),
    hairlineStrong: Color(0xFF453A2C),
    accent: Color(0xFFDCA94F),
    accentSoft: Color(0x24DCA94F),
    cool: Color(0xFF37BFAC),
    coolSoft: Color(0x2437BFAC),
    alert: Color(0xFFDE6A52),
    alertSoft: Color(0x24DE6A52),
    shadow: Color(0x66000000),
    isDark: true,
  );

  @override
  Tokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? glass,
    Color? glassEdge,
    Color? ink,
    Color? inkMid,
    Color? inkDim,
    Color? onAccent,
    Color? hairline,
    Color? hairlineStrong,
    Color? accent,
    Color? accentSoft,
    Color? cool,
    Color? coolSoft,
    Color? alert,
    Color? alertSoft,
    Color? shadow,
    bool? isDark,
  }) =>
      Tokens(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        glass: glass ?? this.glass,
        glassEdge: glassEdge ?? this.glassEdge,
        ink: ink ?? this.ink,
        inkMid: inkMid ?? this.inkMid,
        inkDim: inkDim ?? this.inkDim,
        onAccent: onAccent ?? this.onAccent,
        hairline: hairline ?? this.hairline,
        hairlineStrong: hairlineStrong ?? this.hairlineStrong,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        cool: cool ?? this.cool,
        coolSoft: coolSoft ?? this.coolSoft,
        alert: alert ?? this.alert,
        alertSoft: alertSoft ?? this.alertSoft,
        shadow: shadow ?? this.shadow,
        isDark: isDark ?? this.isDark,
      );

  @override
  Tokens lerp(ThemeExtension<Tokens>? other, double t) {
    if (other is! Tokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return Tokens(
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      glass: c(glass, other.glass),
      glassEdge: c(glassEdge, other.glassEdge),
      ink: c(ink, other.ink),
      inkMid: c(inkMid, other.inkMid),
      inkDim: c(inkDim, other.inkDim),
      onAccent: c(onAccent, other.onAccent),
      hairline: c(hairline, other.hairline),
      hairlineStrong: c(hairlineStrong, other.hairlineStrong),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      cool: c(cool, other.cool),
      coolSoft: c(coolSoft, other.coolSoft),
      alert: c(alert, other.alert),
      alertSoft: c(alertSoft, other.alertSoft),
      shadow: c(shadow, other.shadow),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension TokensOf on BuildContext {
  /// Shorthand so widgets read `context.tk.accent` instead of a Theme lookup.
  Tokens get tk => Theme.of(this).extension<Tokens>() ?? Tokens.light;
}

/// Spacing. Generous — the editorial feel comes mostly from margins.
class Gap {
  const Gap._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 36.0;
  static const xxl = 56.0;
  static const huge = 88.0;
}

/// Corner radii. Soft, not brutalist — the whole interface is rounded now,
/// including the overseer.
class Radii {
  const Radii._();
  static const sm = Radius.circular(8);
  static const md = Radius.circular(14);
  static const lg = Radius.circular(20);
  static const xl = Radius.circular(28);

  static const brSm = BorderRadius.all(sm);
  static const brMd = BorderRadius.all(md);
  static const brLg = BorderRadius.all(lg);
  static const brXl = BorderRadius.all(xl);
}
