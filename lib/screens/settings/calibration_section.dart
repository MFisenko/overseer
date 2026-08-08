import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/calibration.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

/// Where the user tells the app what they actually earn.
///
/// This is the most consequential setting in the product. Everything the ladder
/// pays is derived from it, which is what keeps credits and euros from drifting
/// apart — a pass calibrated to someone's real income cannot mint money they
/// will never have.
class CalibrationSection extends StatelessWidget {
  const CalibrationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final cal = game.calibration;
    final unbacked = game.unbackedCredits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHead('THE LADDER'),
        const SizedBox(height: Gap.md),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Lbl(cal.isCalibrated
                            ? 'EXPECTED MONTHLY INCOME'
                            : 'INCOME NOT SET'),
                        const SizedBox(height: 6),
                        Text(
                          euro(cal.monthlyIncome),
                          style: Kind.numeral(context, size: 28),
                        ),
                      ],
                    ),
                  ),
                  SoftButton(
                    label: cal.isCalibrated ? 'CHANGE' : 'SET IT',
                    primary: !cal.isCalibrated,
                    onTap: () => _editIncome(context, game),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Text(
                cal.isCalibrated
                    ? 'The whole season pays ${_fmtCredits(game.seasonCreditBudget)} '
                        'credits — exactly what ${cal.fundPercent(game).toStringAsFixed(0)}% of this '
                        'income puts in the reserve over three months. Clearing the '
                        'pass and funding the reserve are the same thing.'
                    : 'Until you set this, the ladder runs on a deliberately low '
                        'guess. Set it and every payout is rebuilt around what you '
                        'genuinely earn.',
                style: Kind.body(context, size: 12.5),
              ),
              if (cal.fromStatement) ...[
                const SizedBox(height: Gap.sm),
                Tag('MEASURED FROM STATEMENTS', color: tk.cool, filled: true),
              ],
            ],
          ),
        ),

        // ----------------------------------------------------- honesty check
        if (unbacked > 0) ...[
          const SizedBox(height: Gap.sm),
          Panel(
            color: tk.alertSoft,
            borderColor: tk.alert.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Lbl('CREDITS AHEAD OF THE RESERVE', color: tk.alert),
                const SizedBox(height: 7),
                CreditAmount(unbacked, size: 20, color: tk.alert),
                const SizedBox(height: Gap.sm),
                Text(
                  'You hold more credits than the reserve can currently back. '
                  'Nothing is broken — you simply earned faster than you logged '
                  'income. Log what came in, or claim something smaller.',
                  style: Kind.body(context, size: 12),
                ),
              ],
            ),
          ),
        ],

        // -------------------------------------------------------- difficulty
        const SizedBox(height: Gap.lg),
        const SectionHead('DIFFICULTY'),
        const SizedBox(height: Gap.sm),
        Text(
          'Scales the XP each tier costs. It never changes what a tier pays — '
          'the money is yours either way.',
          style: Kind.body(context, size: 12),
        ),
        const SizedBox(height: Gap.md),
        for (final d in Difficulty.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Panel(
              elevated: false,
              color: cal.difficulty == d ? tk.accentSoft : tk.surfaceAlt,
              borderColor: cal.difficulty == d ? tk.accent : tk.hairline,
              onTap: () => game.setDifficulty(d),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(d.label,
                                style: Kind.label(context,
                                    size: 10,
                                    color: cal.difficulty == d
                                        ? tk.accent
                                        : tk.ink)),
                            const SizedBox(width: Gap.sm),
                            Text('×${d.xpMultiplier}',
                                style: Kind.figure(context,
                                    size: 11, color: tk.inkDim)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(d.blurb, style: Kind.body(context, size: 12)),
                      ],
                    ),
                  ),
                  if (cal.difficulty == d)
                    Icon(Icons.check_rounded, size: 18, color: tk.accent),
                ],
              ),
            ),
          ),

        // -------------------------------------------------------- statements
        const SizedBox(height: Gap.lg),
        SectionHead(
          'STATEMENTS',
          trailing: GestureDetector(
            onTap: () => _addStatement(context, game),
            behavior: HitTestBehavior.opaque,
            child: Lbl('+ ADD', color: tk.accent),
          ),
        ),
        const SizedBox(height: Gap.md),
        Panel(
          elevated: false,
          color: tk.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (game.statements.isEmpty)
                Text(
                  'Enter what actually landed each month and the ladder '
                  're-calibrates from measured income instead of a guess. '
                  'A bank connection would fill this in automatically — the app '
                  'would never see a login, only the figures.',
                  style: Kind.body(context, size: 12.5),
                )
              else
                for (final s in game.statements.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Lbl('${s.month.year}-'
                            '${s.month.month.toString().padLeft(2, '0')}'),
                        const SizedBox(width: Gap.md),
                        Expanded(
                            child: Container(height: 1, color: tk.hairline)),
                        const SizedBox(width: Gap.md),
                        Text(euro(s.incomeEuro),
                            style: Kind.figure(context, size: 12)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmtCredits(int n) => fmt(n);

  Future<void> _editIncome(BuildContext context, GameState game) async {
    final controller = TextEditingController(
      text: game.calibration.isCalibrated
          ? game.calibration.expectedMonthlyIncomeEuro.toStringAsFixed(0)
          : '',
    );
    final value = await showOverseerSheet<double>(
      context,
      child: _IncomeSheet(controller: controller),
    );
    if (value != null && value > 0) await game.setExpectedIncome(value);
  }

  Future<void> _addStatement(BuildContext context, GameState game) async {
    final controller = TextEditingController();
    final now = DateTime.now();
    final value = await showOverseerSheet<double>(
      context,
      child: _IncomeSheet(
        controller: controller,
        title: 'What landed last month',
        blurb: 'The real figure for '
            '${now.year}-${(now.month - 1).clamp(1, 12).toString().padLeft(2, '0')}. '
            'The ladder re-calibrates from the average of everything entered.',
      ),
    );
    if (value != null && value > 0) {
      await game.addStatement(
        month: DateTime(now.year, now.month - 1),
        incomeEuro: value,
      );
    }
  }
}

/// Extension so the section can read the fund share without importing Fund.
extension on Calibration {
  double fundPercent(GameState game) => game.fund.percent;
}

class _IncomeSheet extends StatelessWidget {
  const _IncomeSheet({
    required this.controller,
    this.title = 'What do you earn?',
    this.blurb = 'Roughly, per month, before anything is set aside. This is the '
        'single number the whole ladder is built from — a rough figure beats no '
        'figure, and you can change it whenever it changes.',
  });

  final TextEditingController controller;
  final String title;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Kind.display(context, size: 26)),
        const SizedBox(height: Gap.sm),
        Text(blurb, style: Kind.body(context, size: 13)),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Kind.figure(context, size: 22),
          cursorColor: tk.accent,
          decoration: const InputDecoration(hintText: '0', prefixText: '€ '),
          onSubmitted: (v) => Navigator.pop(
              context, double.tryParse(v.trim().replaceAll(',', '.'))),
        ),
        const SizedBox(height: Gap.lg),
        SoftButton(
          label: 'SET',
          primary: true,
          expand: true,
          onTap: () => Navigator.pop(context,
              double.tryParse(controller.text.trim().replaceAll(',', '.'))),
        ),
      ],
    );
  }
}
