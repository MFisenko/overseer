import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/economy.dart';
import '../../core/lexicon.dart';
import '../../models/upkeep.dart';
import '../../services/ai/overseer_ai.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';
import 'calibration_section.dart';
import 'demo_seed.dart';
import 'log_income_sheet.dart';
import 'obligation_sheet.dart';

/// Everything that configures the machine, plus the two things that put real
/// money into it: logging income and declaring what living costs.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
          children: [
            Text('Settings', style: Kind.display(context, size: 32)),
            const SizedBox(height: Gap.xl),

            // ------------------------------------------------------ money in
            const SectionHead('REAL MONEY'),
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
                            Lbl('${Lex.fund} BALANCE'),
                            const SizedBox(height: 6),
                            Text(euro(game.fund.balanceEuro),
                                style: Kind.numeral(context, size: 30)),
                          ],
                        ),
                      ),
                      SoftButton(
                        label: 'LOG INCOME',
                        primary: true,
                        onTap: () => showLogIncomeSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    'A reward can only be claimed when this covers its real '
                    'price. That constraint is the whole reason the credits '
                    'mean anything.',
                    style: Kind.body(context, size: 12.5),
                  ),
                  const SizedBox(height: Gap.md),
                  Rule(),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Lbl('SET ASIDE FROM INCOME'),
                            const SizedBox(height: 4),
                            Text(
                              '${game.fund.percent.toStringAsFixed(0)}% of every '
                              'euro you log goes to rewards.',
                              style: Kind.body(context, size: 12),
                            ),
                          ],
                        ),
                      ),
                      Text('${game.fund.percent.toStringAsFixed(0)}%',
                          style: Kind.figure(context, size: 18, color: tk.accent)),
                    ],
                  ),
                  Slider(
                    value: game.fund.percent.clamp(0, 50),
                    max: 50,
                    divisions: 50,
                    activeColor: tk.accent,
                    inactiveColor: tk.hairline,
                    onChanged: (v) => game.setFundPercent(v),
                  ),
                  Text('Lifetime into reserve: ${euro(game.fund.lifetimeEuro)}',
                      style: Kind.body(context, size: 11.5, color: tk.inkDim)),
                ],
              ),
            ),

            // ------------------------------------------------ the ladder
            const SizedBox(height: Gap.xl),
            const CalibrationSection(),

            // ----------------------------------------------------- upkeep
            const SizedBox(height: Gap.xl),
            SectionHead(
              Lex.obligations,
              trailing: GestureDetector(
                onTap: () => showObligationSheet(context),
                behavior: HitTestBehavior.opaque,
                child: Lbl('+ ADD', color: tk.accent),
              ),
            ),
            const SizedBox(height: Gap.md),
            if (game.obligations.isEmpty)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nothing declared.', style: Kind.serif(context, size: 17)),
                    const SizedBox(height: 6),
                    Text(
                      'Rent, food, transport, subscriptions. Declaring them '
                      'makes the game count down as well as up — life bills you '
                      'daily whether or not you produced anything.',
                      style: Kind.body(context, size: 12.5),
                    ),
                    const SizedBox(height: Gap.md),
                    SoftButton(
                      label: 'DECLARE AN ${Lex.obligation}',
                      onTap: () => showObligationSheet(context),
                    ),
                  ],
                ),
              )
            else ...[
              Panel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Lbl(game.upkeep.inArrears
                                  ? Lex.deficit
                                  : '${Lex.upkeep} BALANCE'),
                              const SizedBox(height: 6),
                              CreditAmount(
                                game.upkeep.inArrears
                                    ? -game.upkeep.arrearsCredits
                                    : game.upkeep.balanceCredits,
                                size: 24,
                                signed: game.upkeep.inArrears,
                                color: game.upkeep.inArrears ? tk.alert : tk.ink,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Lbl('DAILY BURN'),
                            const SizedBox(height: 6),
                            CreditAmount(-game.dailyBurnCredits,
                                size: 14, signed: true, color: tk.inkMid),
                            const SizedBox(height: 3),
                            Text(euro(game.dailyBurnEuro),
                                style: Kind.body(context, size: 11, color: tk.inkDim)),
                          ],
                        ),
                      ],
                    ),
                    if (game.upkeep.inArrears) ...[
                      const SizedBox(height: Gap.md),
                      Rule(),
                      const SizedBox(height: Gap.md),
                      Text(
                        'While in deficit, '
                        '${(game.upkeep.garnishRate * 100).round()}% of every tier '
                        'payout is withheld to pay it down, and a '
                        '${(game.upkeep.arrearsDailyRate * 100).toStringAsFixed(3)}% '
                        'daily levy accrues.',
                        style: Kind.body(context, size: 12, color: tk.alert),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Gap.sm),
              for (final o in game.obligations)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: Panel(
                    elevated: false,
                    color: tk.surfaceAlt,
                    onTap: () => showObligationSheet(context, existing: o),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.name, style: Kind.title(context, size: 14)),
                              const SizedBox(height: 3),
                              Text('${euro(o.amountEuro)} · ${o.cadence.label}',
                                  style: Kind.body(context, size: 11.5)),
                            ],
                          ),
                        ),
                        CreditAmount(-o.dailyCredits,
                            size: 12, signed: true, color: tk.inkDim),
                        const SizedBox(width: 4),
                        Text('/day',
                            style: Kind.body(context, size: 10, color: tk.inkDim)),
                      ],
                    ),
                  ),
                ),
            ],

            // --------------------------------------------------- appearance
            const SizedBox(height: Gap.xl),
            const SectionHead('APPEARANCE'),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                for (final (mode, label) in const [
                  ('system', 'SYSTEM'),
                  ('light', 'LIGHT'),
                  ('dark', 'DARK'),
                ]) ...[
                  Expanded(
                    child: SoftButton(
                      label: label,
                      expand: true,
                      dense: true,
                      primary: game.profile.themeMode == mode,
                      onTap: () => game.setThemeMode(mode),
                    ),
                  ),
                  if (label != 'DARK') const SizedBox(width: Gap.sm),
                ],
              ],
            ),

            // ---------------------------------------------------- the model
            const SizedBox(height: Gap.xl),
            const SectionHead('THE MODEL'),
            const SizedBox(height: Gap.md),
            Panel(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: OverseerAI().isAvailable ? tk.cool : tk.inkDim,
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      OverseerAI().isAvailable
                          ? 'Connected. Wishes are priced by live search.'
                          : 'Not configured. Wishes take a manual price; '
                              'everything else works.',
                      style: Kind.body(context, size: 12.5),
                    ),
                  ),
                ],
              ),
            ),

            // -------------------------------------------------------- taste
            const SizedBox(height: Gap.xl),
            const SectionHead('TASTE PROFILE'),
            const SizedBox(height: Gap.md),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.taste.profileText.isEmpty
                        ? 'Nothing written yet. This fills itself in from what '
                            'you add, star, claim and dismiss — it is never '
                            'edited by hand, including by you.'
                        : game.taste.profileText,
                    style: Kind.body(context, size: 13),
                  ),
                  if (game.taste.claimed.isNotEmpty ||
                      game.taste.dismissed.isNotEmpty) ...[
                    const SizedBox(height: Gap.md),
                    Row(
                      children: [
                        Tag('${game.taste.claimed.length} WANTED', color: tk.cool),
                        const SizedBox(width: Gap.sm),
                        Tag('${game.taste.dismissed.length} REJECTED',
                            color: tk.inkDim),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ------------------------------------------------------- record
            const SizedBox(height: Gap.xl),
            const SectionHead('RECORD'),
            const SizedBox(height: Gap.md),
            _Stat(label: 'LIFETIME XP', value: fmt(game.wallet.totalXp)),
            _Stat(label: 'DIRECTIVES COLLECTED', value: fmt(game.profile.questsCollected)),
            _Stat(label: 'REWARDS CLAIMED', value: fmt(game.profile.rewardsClaimed)),
            _Stat(label: 'BEST STREAK', value: '${game.profile.bestStreak} DAYS'),
            _Stat(
                label: 'CREDITS PER EURO', value: '${Economy.coinsPerEuro}'),

            // ------------------------------------------------------ danger
            const SizedBox(height: Gap.xl),
            if (kDebugMode) ...[
              const SectionHead('DEVELOPMENT'),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: 'SEED DEMO DATA',
                      expand: true,
                      onTap: () => seedDemoData(context.read<GameState>()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xl),
            ],
            SoftButton(
              label: 'RESET EVERYTHING',
              danger: true,
              expand: true,
              onTap: () => _confirmReset(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final game = context.read<GameState>();
    final tk = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tk.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
        title: Text('Wipe everything?', style: Kind.serif(ctx, size: 20)),
        content: Text(
          'Every directive, wish, credit, tier and logged hour. This cannot be '
          'undone.',
          style: Kind.body(ctx, size: 13.5),
        ),
        actions: [
          SoftButton(label: 'KEEP', dense: true, onTap: () => Navigator.pop(ctx, false)),
          SoftButton(
              label: 'WIPE',
              dense: true,
              danger: true,
              onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) await game.resetEverything();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Lbl(label),
            const SizedBox(width: Gap.md),
            Expanded(child: Container(height: 1, color: context.tk.hairline)),
            const SizedBox(width: Gap.md),
            Text(value, style: Kind.figure(context, size: 12)),
          ],
        ),
      );
}
