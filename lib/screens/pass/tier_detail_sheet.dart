import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/economy.dart';
import '../../core/emblem.dart';
import '../../core/lexicon.dart';
import '../../models/cosmetic.dart';
import '../../models/season.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/emblem.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sheet.dart';

Future<void> showTierDetail(BuildContext context, PassTier tier) =>
    showOverseerSheet(context, child: _TierDetail(tier: tier));

/// What a single rung hands over, stated plainly.
///
/// Rungs carrying a real item route to that item's own page instead of here —
/// this sheet is for credit payouts and in-app unlocks, where there is no
/// photography to justify a full spread.
class _TierDetail extends StatelessWidget {
  const _TierDetail({required this.tier});
  final PassTier tier;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final level = game.wallet.level;
    final reached = level >= tier.tier;
    final xpAway = (tier.xpThreshold - game.wallet.seasonXp).clamp(0, 1 << 40);

    final cosmetic = tier.cosmeticId == null
        ? null
        : game.cosmetics.where((c) => c.id == tier.cosmeticId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Lbl('${Lex.tier} ${tier.tier.toString().padLeft(3, '0')}',
                color: reached ? tk.cool : tk.inkDim),
            const Spacer(),
            Tag(
              reached ? 'REACHED' : 'AHEAD',
              color: reached ? tk.cool : tk.inkDim,
              filled: reached,
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            EmblemMark(
              emblem: tier.kind == RungKind.cosmetic ? Emblem.cipher : Emblem.mark,
              size: 44,
              color: reached ? tk.accent : tk.inkDim,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                cosmetic?.name ??
                    (tier.kind == RungKind.cosmetic
                        ? 'In-app unlock'
                        : 'Credit payout'),
                style: Kind.display(context, size: 26),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        const SectionHead('HANDS OVER'),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            CreditAmount(tier.coinPayout, size: 26, weight: FontWeight.w400),
            const Spacer(),
            if (tier.isMajor)
              Tag('MAJOR MILESTONE', color: tk.accent, filled: true)
            else if (tier.isMilestone)
              Tag('MILESTONE', color: tk.accent),
          ],
        ),
        if (cosmetic != null) ...[
          const SizedBox(height: Gap.md),
          Text(
            '${cosmetic.type.label} · ${cosmetic.unlockDescription}',
            style: Kind.body(context, size: 13),
          ),
        ],
        const SizedBox(height: Gap.xl),
        const SectionHead('TO REACH IT'),
        const SizedBox(height: Gap.md),
        _Row(label: 'SEASON XP REQUIRED', value: fmt(tier.xpThreshold)),
        _Row(
          label: 'YOUR SEASON XP',
          value: fmt(game.wallet.seasonXp),
          color: tk.ink,
        ),
        if (!reached)
          _Row(label: 'STILL OWED', value: '${fmt(xpAway)} XP', color: tk.accent),
        _Row(
          label: 'THIS RUNG COSTS',
          value: '${fmt(game.plan.xpFor(tier.tier))} XP',
        ),
        const SizedBox(height: Gap.lg),
        if (!reached)
          Text(
            'Nothing here can be bought. It arrives when the bar does.',
            style: Kind.body(context, size: 12.5),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Lbl(label),
            const SizedBox(width: Gap.md),
            Expanded(child: Container(height: 1, color: context.tk.hairline)),
            const SizedBox(width: Gap.md),
            Text(value,
                style: Kind.figure(context,
                    size: 12, color: color ?? context.tk.inkMid)),
          ],
        ),
      );
}
