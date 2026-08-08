import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Three typefaces, each with one job.
///
/// A high-contrast serif carries the editorial voice — reward names, hero
/// moments, the things a magazine would set large. A neutral grotesk handles
/// interface text. A mono carries every number, because figures that shift
/// width as they animate look broken, and the credit balance animates
/// constantly.
class Kind {
  const Kind._();

  /// Editorial display. Fraunces has real optical contrast at large sizes,
  /// which is what makes a reward name read as a magazine headline rather than
  /// as a label.
  static TextStyle display(BuildContext c, {double size = 34, Color? color, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: w,
        color: color ?? c.tk.ink,
        height: 1.06,
        letterSpacing: -0.4,
      );

  static TextStyle serif(BuildContext c, {double size = 18, Color? color, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: w,
        color: color ?? c.tk.ink,
        height: 1.24,
      );

  // ------------------------------------------------------------ interface
  static TextStyle title(BuildContext c, {double size = 16, Color? color, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        color: color ?? c.tk.ink,
        height: 1.25,
        letterSpacing: -0.1,
      );

  static TextStyle body(BuildContext c, {double size = 14, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? c.tk.inkMid,
        height: 1.55,
      );

  /// Wide-tracked caps. The connective tissue borrowed from the reference —
  /// section markers, tier numbers, metadata rails.
  static TextStyle label(BuildContext c, {double size = 10, Color? color, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        color: color ?? c.tk.inkDim,
        letterSpacing: 1.9,
        height: 1.2,
      );

  // --------------------------------------------------------------- figures
  /// The credit balance. The single largest element in the product.
  static TextStyle numeral(BuildContext c, {double size = 60, Color? color, FontWeight w = FontWeight.w300}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: w,
        color: color ?? c.tk.ink,
        height: 1.0,
        letterSpacing: -1.6,
      );

  static TextStyle figure(BuildContext c, {double size = 15, Color? color, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: w,
        color: color ?? c.tk.ink,
        height: 1.1,
      );

  /// The overseer's voice. Mono, because it is a machine talking.
  static TextStyle machine(BuildContext c, {double size = 12.5, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? c.tk.ink,
        height: 1.5,
      );
}
