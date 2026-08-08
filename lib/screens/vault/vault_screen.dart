import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/horizon.dart';
import '../../models/reward.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/primitives.dart';
import '../../widgets/reward_image.dart';
import '../../widgets/sheet.dart';
import '../reward/reward_detail_screen.dart';

/// The long game.
///
/// A car or a deposit will never fit on a thirteen-week ladder, and putting one
/// there produces a top rung that is a lie. Instead they live here, each with
/// its own pot, its own share of every euro set aside, and a date derived from
/// what the user actually earns.
///
/// The important property is that nothing here is hidden or softened. If a goal
/// is seventeen years away the app says seventeen years — and then says what
/// income would make it five, which is the number that turns a discouraging
/// figure into an actionable one.
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final goals = game.longRangeGoals;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
          children: [
            Text('The Vault', style: Kind.display(context, size: 32)),
            const SizedBox(height: Gap.sm),
            Text(
              'Goals bigger than one season. Each takes a share of everything '
              'you set aside, into a pot nothing else can spend.',
              style: Kind.body(context, size: 13),
            ),

            const SizedBox(height: Gap.lg),
            _ReserveSplit(),

            const SizedBox(height: Gap.xl),
            if (goals.isEmpty)
              VoidState(
                line: 'Nothing long-range yet.',
                sub: 'Add something genuinely out of reach — a car, a deposit, '
                    'a year off. Anything the app works out is more than a '
                    'season away lands here automatically.',
              )
            else
              for (final g in goals) ...[
                _GoalCard(reward: g),
                const SizedBox(height: Gap.md),
              ],
          ],
        ),
      ),
    );
  }
}

/// How the reserve is carved up. Sums to 100% by construction — the earmark
/// setter refuses to allocate more than exists.
class _ReserveSplit extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final committed = game.earmarkedPercent;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpreadRow(
            left: Lbl('RESERVE COMMITTED'),
            right: Text('${committed.toStringAsFixed(0)}%',
                style: Kind.figure(context, size: 15, color: tk.accent)),
          ),
          const SizedBox(height: Gap.md),
          ProgressBar(progress: committed / 100, height: 6),
          const SizedBox(height: Gap.sm),
          Text(
            committed <= 0
                ? 'Every euro set aside is currently free for near-term rewards. '
                    'Commit a share below to start a long climb.'
                : '${game.unearmarkedPercent.toStringAsFixed(0)}% stays free for '
                    'ordinary rewards. ${euro(game.annualReserveEuro)} reaches the '
                    'reserve each year at your current income.',
            style: Kind.body(context, size: 12),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.reward});
  final Reward reward;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final r = reward;
    final horizon = game.horizonOf(r);
    final years = game.yearsAwayFor(r);
    final beyond = horizon == Horizon.beyondHorizon;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(RewardDetailScreen.route(r.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tk.surface,
          borderRadius: Radii.brLg,
          border: Border.all(color: beyond ? tk.hairline : tk.accent),
          boxShadow: [
            BoxShadow(color: tk.shadow, blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RewardImage(
                  imageUrl: r.imageUrl,
                  emblem: r.emblem,
                  seed: r.id,
                  height: 130,
                  radius: const BorderRadius.vertical(top: Radii.lg),
                ),
                Positioned(
                  top: Gap.sm,
                  left: Gap.sm,
                  child: GlassPanel(
                    radius: BorderRadius.circular(999),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    tint: Colors.black.withValues(alpha: 0.42),
                    child: Text(horizon.label,
                        style:
                            Kind.label(context, size: 8.5, color: Colors.white)),
                  ),
                ),
                Positioned(
                  left: Gap.md,
                  right: Gap.md,
                  bottom: 10,
                  child: Text(
                    r.name,
                    style: Kind.serif(context, size: 19, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------- its own pot
                  ProgressBar(
                    progress: r.savedProgress,
                    height: 5,
                    color: beyond ? tk.inkDim : tk.cool,
                  ),
                  const SizedBox(height: Gap.sm),
                  SpreadRow(
                    left: Text('${euro(r.savedEuro)} of ${euro(r.priceEuro)}',
                        style: Kind.figure(context, size: 12, color: tk.inkMid)),
                    right: Lbl('${(r.savedProgress * 100).floor()}% PUT BY',
                        color: tk.cool),
                  ),

                  const SizedBox(height: Gap.md),
                  Rule(),
                  const SizedBox(height: Gap.md),

                  // --------------------------------------------- the date
                  SpreadRow(
                    left: Lbl(r.isEarmarked ? 'AT YOUR CURRENT SHARE' : 'IF IT TOOK EVERYTHING'),
                    right: Text(
                      _yearsLabel(years),
                      style: Kind.figure(context,
                          size: 14,
                          color: beyond ? tk.alert : tk.ink,
                          w: FontWeight.w700),
                    ),
                  ),

                  if (beyond) ...[
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Past the ten-year horizon at what you earn now. '
                      '${euro(game.incomeToReach(r, years: 5))} a month would '
                      'make it five.',
                      style: Kind.body(context, size: 12, color: tk.alert),
                    ),
                  ],

                  // ------------------------------------------- the earmark
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Lbl('SHARE OF THE RESERVE'),
                            const SizedBox(height: 4),
                            Text(
                              r.isEarmarked
                                  ? '${r.earmarkPercent.toStringAsFixed(0)}% of every euro '
                                      'set aside · ${euro(game.annualReserveEuro * r.earmarkPercent / 100)}/yr'
                                  : 'Not committed. This goal is not growing.',
                              style: Kind.body(context, size: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      SoftButton(
                        label: r.isEarmarked ? 'ADJUST' : 'COMMIT',
                        dense: true,
                        primary: !r.isEarmarked,
                        onTap: () => _editEarmark(context, game, r),
                      ),
                    ],
                  ),

                  const SizedBox(height: Gap.md),
                  SpreadRow(
                    left: CreditAmount(r.coinCost, size: 13, color: tk.inkMid),
                    right: Lbl(r.bucketName),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _yearsLabel(double? years) {
    if (years == null) return 'NEVER';
    if (years <= 0) return 'NOW';
    if (years < 1) return '${(years * 12).ceil()} MONTHS';
    return '${years.toStringAsFixed(1)} YEARS';
  }

  Future<void> _editEarmark(
      BuildContext context, GameState game, Reward r) async {
    await showOverseerSheet<void>(
      context,
      child: _EarmarkSheet(rewardId: r.id),
    );
  }
}

/// Commits a share of the reserve to one goal, previewing what that does to
/// the date before anything is saved.
class _EarmarkSheet extends StatefulWidget {
  const _EarmarkSheet({required this.rewardId});
  final String rewardId;

  @override
  State<_EarmarkSheet> createState() => _EarmarkSheetState();
}

class _EarmarkSheetState extends State<_EarmarkSheet> {
  double? _value;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final r = game.rewardById(widget.rewardId);
    if (r == null) return const SizedBox.shrink();

    // Whatever is not already committed elsewhere, plus this goal's own share.
    final ceiling =
        (100 - (game.earmarkedPercent - r.earmarkPercent)).clamp(0.0, 100.0);
    final value = (_value ?? r.earmarkPercent).clamp(0.0, ceiling);

    final annual = game.annualReserveEuro * value / 100;
    final years = annual <= 0 ? null : r.outstandingEuro / annual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(r.name, style: Kind.display(context, size: 24)),
        const SizedBox(height: Gap.sm),
        Text(
          'How much of every euro you set aside should go here? It accumulates '
          'in this goal\'s own pot and nothing else can spend it.',
          style: Kind.body(context, size: 13),
        ),
        const SizedBox(height: Gap.lg),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${value.toStringAsFixed(0)}%',
                style: Kind.numeral(context, size: 44, color: tk.accent)),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${euro(annual)} a year',
                  style: Kind.figure(context, size: 13, color: tk.inkMid),
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          max: ceiling == 0 ? 1 : ceiling,
          divisions: ceiling <= 0 ? 1 : ceiling.round(),
          activeColor: tk.accent,
          inactiveColor: tk.hairline,
          onChanged: ceiling <= 0 ? null : (v) => setState(() => _value = v),
        ),
        if (ceiling < 100)
          Text(
            'Capped at ${ceiling.toStringAsFixed(0)}% — the rest of the reserve '
            'is already committed to other goals.',
            style: Kind.body(context, size: 11.5, color: tk.inkDim),
          ),

        const SizedBox(height: Gap.lg),
        Panel(
          elevated: false,
          color: tk.surfaceAlt,
          child: SpreadRow(
            left: Lbl('AT THIS SHARE, IT ARRIVES IN'),
            right: Text(
              years == null
                  ? 'NEVER'
                  : years < 1
                      ? '${(years * 12).ceil()} MONTHS'
                      : '${years.toStringAsFixed(1)} YEARS',
              style: Kind.figure(context,
                  size: 15,
                  color: years == null || years > horizonYears
                      ? tk.alert
                      : tk.cool,
                  w: FontWeight.w700),
            ),
          ),
        ),

        const SizedBox(height: Gap.lg),
        SoftButton(
          label: 'COMMIT',
          primary: true,
          expand: true,
          onTap: () async {
            await game.setEarmark(r.id, value);
            if (context.mounted) Navigator.pop(context);
          },
        ),
        if (r.isEarmarked) ...[
          const SizedBox(height: Gap.sm),
          SoftButton(
            label: 'RELEASE',
            danger: true,
            expand: true,
            dense: true,
            onTap: () async {
              await game.setEarmark(r.id, 0);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Releasing stops future deposits. What is already put by stays with '
            'the goal.',
            style: Kind.body(context, size: 11.5, color: tk.inkDim),
          ),
        ],
      ],
    );
  }
}
