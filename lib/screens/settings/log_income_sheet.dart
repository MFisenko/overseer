import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/economy.dart';
import '../../core/lexicon.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

Future<void> showLogIncomeSheet(BuildContext context) =>
    showOverseerSheet(context, child: const _LogIncomeSheet());

/// Where real money enters the system.
///
/// The reward share goes to the reserve, which is the only thing a real reward
/// can ever be claimed against. The rest credits upkeep, because that is what
/// actually pays rent. XP is granted for the work behind it, so a paid win
/// moves the bar like anything else does.
class _LogIncomeSheet extends StatefulWidget {
  const _LogIncomeSheet();

  @override
  State<_LogIncomeSheet> createState() => _LogIncomeSheetState();
}

class _LogIncomeSheetState extends State<_LogIncomeSheet> {
  final _amount = TextEditingController();
  final _source = TextEditingController();
  int _xp = Economy.xpBigWin;

  @override
  void dispose() {
    _amount.dispose();
    _source.dispose();
    super.dispose();
  }

  double get _euros =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _submit() async {
    if (_euros <= 0) return;
    await context.read<GameState>().logIncome(
          amountEuro: _euros,
          source: _source.text.trim(),
          xp: _xp,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final toFund = _euros * (game.fund.percent / 100);
    final toUpkeep = _euros - toFund;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Log income', style: Kind.display(context, size: 26)),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Kind.figure(context, size: 22),
          cursorColor: tk.accent,
          decoration: const InputDecoration(hintText: '0.00', prefixText: '€ '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _source,
          style: Kind.title(context, size: 15),
          cursorColor: tk.accent,
          decoration: const InputDecoration(hintText: 'what it was for'),
        ),
        const SizedBox(height: Gap.lg),
        const SectionHead('XP FOR THE WORK BEHIND IT'),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          children: [
            for (final (label, xp) in const [
              ('SMALL', Economy.xpSmall),
              ('SESSION', Economy.xpSession),
              ('MAJOR', Economy.xpBigWin),
            ])
              GestureDetector(
                onTap: () => setState(() => _xp = xp),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _xp == xp ? tk.accent : tk.hairlineStrong),
                    color: _xp == xp ? tk.accentSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$label · $xp XP',
                      style: Kind.label(context,
                          size: 9.5, color: _xp == xp ? tk.accent : tk.inkMid)),
                ),
              ),
          ],
        ),
        if (_euros > 0) ...[
          const SizedBox(height: Gap.lg),
          const SectionHead('WHERE IT GOES'),
          const SizedBox(height: Gap.md),
          _Split(
            label: '${Lex.fund} (${game.fund.percent.toStringAsFixed(0)}%)',
            value: euro(toFund),
            detail: 'Buys rewards. Nothing else can.',
            color: tk.accent,
          ),
          _Split(
            label: Lex.upkeep,
            value: euro(toUpkeep),
            detail: 'Pays what living costs.',
            color: tk.cool,
          ),
        ],
        const SizedBox(height: Gap.xl),
        SoftButton(
          label: 'LOG IT',
          primary: true,
          expand: true,
          onTap: _euros > 0 ? _submit : null,
        ),
      ],
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Row(
          children: [
            Container(width: 3, height: 32, color: color),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Lbl(label, color: color),
                  const SizedBox(height: 3),
                  Text(detail, style: Kind.body(context, size: 11.5)),
                ],
              ),
            ),
            Text(value, style: Kind.figure(context, size: 15)),
          ],
        ),
      );
}
