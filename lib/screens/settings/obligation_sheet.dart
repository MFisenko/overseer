import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/lexicon.dart';
import '../../models/upkeep.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

Future<void> showObligationSheet(BuildContext context, {Obligation? existing}) =>
    showOverseerSheet(context, child: _ObligationSheet(existing: existing));

/// Declaring what living costs.
///
/// This is the counterweight to the reward economy. Without it the game only
/// ever counts up, which is a lie — rent arrives whether or not you had a good
/// week, and the overseer is not going to pretend otherwise.
class _ObligationSheet extends StatefulWidget {
  const _ObligationSheet({this.existing});
  final Obligation? existing;

  @override
  State<_ObligationSheet> createState() => _ObligationSheetState();
}

class _ObligationSheetState extends State<_ObligationSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _amount = TextEditingController(
      text: widget.existing?.amountEuro.toStringAsFixed(2) ?? '');
  late ObligationCadence _cadence =
      widget.existing?.cadence ?? ObligationCadence.monthly;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _euros =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;

  double get _dailyCredits =>
      _euros / _cadence.days * 100;

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _euros <= 0) return;
    final game = context.read<GameState>();
    if (widget.existing != null) {
      await game.updateObligation(widget.existing!.copyWith(
        name: name,
        amountEuro: _euros,
        cadence: _cadence,
      ));
    } else {
      await game.addObligation(
          name: name, amountEuro: _euros, cadence: _cadence);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.existing == null
              ? 'Declare an ${Lex.obligation.toLowerCase()}'
              : 'Amend ${Lex.obligation.toLowerCase()}',
          style: Kind.display(context, size: 24),
        ),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _name,
          autofocus: true,
          style: Kind.title(context, size: 16),
          cursorColor: tk.accent,
          decoration: const InputDecoration(hintText: 'rent, food, transport'),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Kind.figure(context, size: 18),
          cursorColor: tk.accent,
          decoration: const InputDecoration(hintText: '0.00', prefixText: '€ '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.lg),
        const SectionHead('HOW OFTEN'),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            for (final c in ObligationCadence.values) ...[
              Expanded(
                child: SoftButton(
                  label: c.label,
                  expand: true,
                  primary: _cadence == c,
                  onTap: () => setState(() => _cadence = c),
                ),
              ),
              if (c != ObligationCadence.values.last) const SizedBox(width: Gap.sm),
            ],
          ],
        ),
        if (_euros > 0) ...[
          const SizedBox(height: Gap.lg),
          Panel(
            elevated: false,
            color: tk.surfaceAlt,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Lbl('ADDS TO DAILY BURN'),
                      const SizedBox(height: 6),
                      CreditAmount(-_dailyCredits,
                          size: 20, signed: true, color: tk.alert),
                    ],
                  ),
                ),
                Text('${euro(_euros / _cadence.days)}/day',
                    style: Kind.body(context, size: 12)),
              ],
            ),
          ),
        ],
        const SizedBox(height: Gap.xl),
        Row(
          children: [
            Expanded(
              child: SoftButton(
                label: widget.existing == null ? 'DECLARE' : 'SAVE',
                primary: true,
                expand: true,
                onTap: _submit,
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(width: Gap.sm),
              SoftButton(
                label: 'REMOVE',
                danger: true,
                onTap: () async {
                  await context
                      .read<GameState>()
                      .deleteObligation(widget.existing!.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}
