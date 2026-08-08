import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/economy.dart';
import '../../core/lexicon.dart';
import '../../models/quest.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

Future<void> showAddQuestSheet(BuildContext context, {Quest? existing}) =>
    showOverseerSheet(context, child: _AddQuestSheet(existing: existing));

/// Issuing a directive has to be nearly frictionless, so the defaults are
/// pre-chosen and the only required field is the text.
class _AddQuestSheet extends StatefulWidget {
  const _AddQuestSheet({this.existing});
  final Quest? existing;

  @override
  State<_AddQuestSheet> createState() => _AddQuestSheetState();
}

class _AddQuestSheetState extends State<_AddQuestSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late Cadence _cadence = widget.existing?.cadence ?? Cadence.daily;
  late int _xp = widget.existing?.xpValue ?? Economy.xpSmall;
  late int _coins = widget.existing?.coinValue ?? 0;
  late int _target = widget.existing?.targetCount ?? 1;
  late bool _earns = widget.existing?.earnsIncome ?? false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// The four starting weights, all editable afterwards. The trivial one is
  /// deliberately worth real XP — "no feedback for small things" is the exact
  /// failure this app exists to fix.
  static const _weights = <(String, String, int, int)>[
    ('TRIVIAL', 'dishes, a walk', Economy.xpTrivial, 2),
    ('SMALL', 'an errand, a tidy-up', Economy.xpSmall, 4),
    ('SESSION', 'unpaid focus', Economy.xpSession, 8),
    ('PAID', 'work that earns', Economy.xpPaidSession, 20),
    ('MAJOR', 'a real paid win', Economy.xpBigWin, 60),
  ];

  Future<void> _submit() async {
    final text = _title.text.trim();
    if (text.isEmpty) return;
    final game = context.read<GameState>();
    if (widget.existing != null) {
      await game.updateQuest(widget.existing!.copyWith(
        title: text,
        xpValue: _xp,
        coinValue: _coins,
        cadence: _cadence,
        targetCount: _target,
        earnsIncome: _earns,
        expiresAt: GameState.expiryFor(_cadence),
      ));
    } else {
      await game.addQuest(
        title: text,
        xpValue: _xp,
        coinValue: _coins,
        cadence: _cadence,
        targetCount: _target,
        earnsIncome: _earns,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.existing == null ? 'New directive' : 'Amend directive',
            style: Kind.display(context, size: 26)),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _title,
          autofocus: true,
          style: Kind.title(context, size: 16),
          cursorColor: tk.accent,
          decoration: const InputDecoration(hintText: 'what needs doing'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Gap.lg),
        const SectionHead('WEIGHT'),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final (label, hint, xp, coins) in _weights)
              _Chip(
                label: label,
                sub: '$xp XP · $hint',
                selected: _xp == xp,
                onTap: () => setState(() {
                  _xp = xp;
                  _coins = coins;
                }),
              ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        const SectionHead('CADENCE'),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final c in Cadence.values)
              _Chip(
                label: c.label,
                selected: _cadence == c,
                onTap: () => setState(() => _cadence = c),
              ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Lbl('REPEAT TARGET'),
                const SizedBox(height: 4),
                Text('"do the dishes twice"',
                    style: Kind.body(context, size: 11.5)),
              ],
            ),
            const Spacer(),
            _Stepper(value: _target, onChanged: (v) => setState(() => _target = v)),
          ],
        ),
        const SizedBox(height: Gap.md),
        GestureDetector(
          onTap: () => setState(() => _earns = !_earns),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  border: Border.all(color: _earns ? tk.cool : tk.hairlineStrong),
                  color: _earns ? tk.cool : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: _earns
                    ? Icon(Icons.check_rounded, size: 13, color: tk.canvas)
                    : null,
              ),
              const SizedBox(width: Gap.sm),
              Text('Earns real income', style: Kind.body(context, size: 13.5)),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
        SoftButton(
          label: widget.existing == null ? 'ISSUE' : 'SAVE',
          primary: true,
          expand: true,
          onTap: _submit,
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'Finishing this grants XP immediately. ${Lex.currency.toLowerCase()} '
          'arrive when the XP crosses a tier.',
          style: Kind.body(context, size: 11.5, color: tk.inkDim),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
  });
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? tk.accent : tk.hairlineStrong),
          color: selected ? tk.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: Kind.label(context,
                    size: 9.5, color: selected ? tk.accent : tk.inkMid)),
            if (sub != null) ...[
              const SizedBox(height: 3),
              Text(sub!, style: Kind.body(context, size: 10.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SoftButton(
            label: '−',
            dense: true,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text('$value', style: Kind.figure(context, size: 16)),
          ),
          SoftButton(
            label: '+',
            dense: true,
            onTap: value < 20 ? () => onChanged(value + 1) : null,
          ),
        ],
      );
}
