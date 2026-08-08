import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's one modal shape: a rounded slab that rises from the bottom over a
/// dimmed page, with a grabber and a soft top edge.
Future<T?> showOverseerSheet<T>(BuildContext context, {required Widget child}) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final tk = ctx.tk;
        return Padding(
          // Keep the sheet clear of the keyboard when a field is focused.
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
            ),
            decoration: BoxDecoration(
              color: tk.surface,
              borderRadius: const BorderRadius.vertical(top: Radii.xl),
              border: Border.all(color: tk.hairline),
              boxShadow: [
                BoxShadow(color: tk.shadow, blurRadius: 40, offset: const Offset(0, -8)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 2),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tk.hairlineStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
