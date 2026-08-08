import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appearance.dart';
import '../../models/companion.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/companion/overseer_eye.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

Future<void> showAppearanceSheet(BuildContext context) =>
    showOverseerSheet(context, child: const _AppearanceSheet());

/// Four independent axes — shape, finish, paint, persona — which combine into
/// thousands of looks rather than a fixed list of skins.
///
/// Every change previews live at the top, because the whole point of the
/// overseer is that it is the thing you look at all day.
class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final a = game.companion.appearance;

    void set(Appearance next) => game.setAppearance(next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            OverseerEye(
              mood: game.companion.mood,
              appearance: a,
              size: 84,
              flat: true,
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customise', style: Kind.display(context, size: 26)),
                  const SizedBox(height: 6),
                  Text('${Appearance.lookCount} looks, before personality.',
                      style: Kind.body(context, size: 12.5)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: Gap.xl),
        const SectionHead('SHAPE'),
        const SizedBox(height: Gap.md),
        _Grid(
          children: [
            for (final s in OverseerShape.values)
              _Swatch(
                label: s.label,
                selected: a.shape == s,
                onTap: () => set(a.copyWith(shape: s)),
                preview: OverseerEye(
                  mood: CompanionMood.idle,
                  appearance: a.copyWith(shape: s),
                  size: 38,
                  flat: true,
                  lookAt: Offset.zero,
                ),
              ),
          ],
        ),

        const SizedBox(height: Gap.xl),
        const SectionHead('MATERIAL'),
        const SizedBox(height: Gap.md),
        _Grid(
          children: [
            for (final f in OverseerFinish.values)
              _Swatch(
                label: f.label,
                selected: a.finish == f,
                onTap: () => set(a.copyWith(finish: f)),
                preview: OverseerEye(
                  mood: CompanionMood.idle,
                  appearance: a.copyWith(finish: f),
                  size: 38,
                  flat: true,
                  lookAt: Offset.zero,
                ),
              ),
          ],
        ),

        const SizedBox(height: Gap.xl),
        const SectionHead('PAINT'),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final p in OverseerPaint.catalogue)
              GestureDetector(
                onTap: () => set(a.copyWith(paintId: p.id)),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.body,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: a.paintId == p.id ? tk.accent : p.edge,
                          width: a.paintId == p.id ? 3 : 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 52,
                      child: Text(
                        p.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Kind.label(context,
                            size: 8,
                            color: a.paintId == p.id ? tk.accent : tk.inkDim),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: Gap.xl),
        const SectionHead('PERSONALITY'),
        const SizedBox(height: Gap.sm),
        Text(
          'Changes how it talks, never what it wants. All of them are on your '
          'side underneath.',
          style: Kind.body(context, size: 12),
        ),
        const SizedBox(height: Gap.md),
        for (final p in OverseerPersona.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Panel(
              elevated: false,
              color: a.persona == p ? tk.accentSoft : tk.surfaceAlt,
              borderColor: a.persona == p ? tk.accent : tk.hairline,
              onTap: () => set(a.copyWith(persona: p)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.label,
                            style: Kind.label(context,
                                size: 10,
                                color: a.persona == p ? tk.accent : tk.ink)),
                        const SizedBox(height: 4),
                        Text(p.blurb, style: Kind.body(context, size: 12)),
                      ],
                    ),
                  ),
                  if (a.persona == p)
                    Icon(Icons.check_rounded, size: 18, color: tk.accent),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.sm,
        children: children,
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? tk.accentSoft : Colors.transparent,
          border: Border.all(color: selected ? tk.accent : tk.hairline),
          borderRadius: Radii.brMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 40, child: Center(child: preview)),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Kind.label(context,
                  size: 8, color: selected ? tk.accent : tk.inkDim),
            ),
          ],
        ),
      ),
    );
  }
}
