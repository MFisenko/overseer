import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/economy.dart';
import '../../core/emblem.dart';
import '../../core/lexicon.dart';
import '../../models/reward.dart';
import '../../models/season.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/emblem.dart';
import '../../widgets/primitives.dart';
import '../../widgets/reward_image.dart';
import '../reward/reward_detail_screen.dart';
import 'tier_detail_sheet.dart';

/// The full ladder, all 150 rungs, scrollable end to end.
///
/// Every rung states exactly what it hands over, and the rhythm is deliberate:
/// something from the real world every tenth tier, something inside the app on
/// the fives between them, credits on the rest. A named prize is therefore
/// never more than five rungs away, which is what keeps a climb this long
/// legible instead of numbing.
class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  final _controller = ScrollController();
  Timer? _tick;
  var _jumped = false;

  static const _rungHeight = 78.0;
  // Image + the price row + the rung's own vertical padding. Tuned to the
  // content so a feature card does not sit in a pool of dead space.
  static const _featureHeight = 198.0;

  @override
  void initState() {
    super.initState();
    // The season countdown has to actually move.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _heightOf(int tier) =>
      Economy.rungKind(tier).carriesReward ? _featureHeight : _rungHeight;

  /// Sum of every rung below [tier], so the ladder can open at where the user
  /// actually is rather than at tier one.
  double _offsetTo(int tier) {
    var total = 0.0;
    for (var t = 1; t < tier; t++) {
      total += _heightOf(t);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();

    final season = game.season;
    final level = game.wallet.level;

    if (!_jumped) {
      _jumped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        final target = (_offsetTo(level) - 120).clamp(
          0.0,
          _controller.position.maxScrollExtent,
        );
        _controller.jumpTo(target);
      });
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SeasonHeader(season: season),
            Expanded(
              child: ListView.builder(
                controller: _controller,
                padding: const EdgeInsets.only(bottom: Gap.huge),
                itemCount: season.tiers.length,
                itemExtentBuilder: (i, __) => _heightOf(i + 1),
                itemBuilder: (context, i) {
                  final tier = season.tiers[i];
                  final state = tier.tier < level
                      ? _RungState.passed
                      : tier.tier == level
                          ? _RungState.current
                          : _RungState.ahead;
                  return _Rung(
                    tier: tier,
                    state: state,
                    reward: tier.rewardId == null
                        ? null
                        : game.rewardById(tier.rewardId!),
                    isFirst: i == 0,
                    isLast: i == season.tiers.length - 1,
                    onTap: () => _openTier(context, tier),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTier(BuildContext context, PassTier tier) {
    final game = context.read<GameState>();
    // A rung carrying a real item goes straight to that item's page; the item
    // is the point, not the rung.
    if (tier.rewardId != null && game.rewardById(tier.rewardId!) != null) {
      Navigator.of(context).push(RewardDetailScreen.route(tier.rewardId!));
      return;
    }
    showTierDetail(context, tier);
  }
}

enum _RungState { passed, current, ahead }

/// The season banner: name, countdown, and where the climb currently stands.
class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final game = context.watch<GameState>();

    final w = game.wallet;
    final left = season.timeLeft;

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
      decoration: BoxDecoration(
        color: tk.canvas,
        border: Border(bottom: BorderSide(color: tk.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(season.name, style: Kind.display(context, size: 26)),
              ),
              if (left != null)
                Tag(
                  '${left.inDays}D LEFT',
                  color: left.inDays <= 7 ? tk.alert : tk.inkDim,
                  filled: left.inDays <= 7,
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          SpreadRow(
            crossAxisAlignment: CrossAxisAlignment.end,
            left: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${Lex.tier} ', style: Kind.label(context, size: 10)),
                Text(w.level.toString().padLeft(3, '0'),
                    style: Kind.numeral(context, size: 30, color: tk.accent)),
                Text(' / ${Economy.seasonTiers}',
                    style: Kind.figure(context, size: 13, color: tk.inkDim)),
              ],
            ),
            right: Text('${fmt(w.xpIntoLevel)} / ${fmt(w.xpForNextLevel(game.plan))} XP',
                style: Kind.figure(context, size: 12, color: tk.inkMid)),
          ),
          const SizedBox(height: Gap.sm),
          ProgressBar(progress: w.levelProgress(game.plan)),
          const SizedBox(height: Gap.sm),
          SpreadRow(
            left: Lbl('${fmt(w.xpRemaining(game.plan))} XP TO ${Lex.tier} ${w.level + 1}'),
            // The season clock runs whether or not the climb does.
            right: Lbl('SEASON ${(season.elapsedFraction * 100).floor()}% ELAPSED',
                color: tk.inkDim),
          ),
        ],
      ),
    );
  }
}

/// One rung. Credit-only rungs are a compact row; real-world rungs open out
/// into a feature card with the item's photography, because those are the ones
/// worth climbing toward.
class _Rung extends StatelessWidget {
  const _Rung({
    required this.tier,
    required this.state,
    required this.reward,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final PassTier tier;
  final _RungState state;
  final Reward? reward;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;

    final feature = tier.kind == RungKind.real;

    final nodeColor = switch (state) {
      _RungState.passed => tk.cool,
      _RungState.current => tk.accent,
      _RungState.ahead => tk.hairlineStrong,
    };
    // Rungs still ahead recede so the eye lands on where the user actually is.
    final dim = state == _RungState.ahead;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(nodeColor: nodeColor, state: state, isFirst: isFirst, isLast: isLast),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.lg, Gap.sm),
              child: feature
                  ? _FeatureCard(tier: tier, reward: reward, state: state, dim: dim)
                  : _CompactRung(tier: tier, state: state, dim: dim),
            ),
          ),
        ],
      ),
    );
  }
}

/// The vertical ladder rail with a node per rung.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.nodeColor,
    required this.state,
    required this.isFirst,
    required this.isLast,
  });

  final Color nodeColor;
  final _RungState state;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;

    final passed = state == _RungState.passed;
    return SizedBox(
      width: 52,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: isFirst ? 26 : 0,
            bottom: isLast ? null : 0,
            height: isLast ? 26 : null,
            child: Container(
              width: 1.5,
              color: passed ? tk.cool.withValues(alpha: 0.4) : tk.hairline,
            ),
          ),
          Positioned(
            top: 18,
            child: Container(
              width: state == _RungState.current ? 16 : 10,
              height: state == _RungState.current ? 16 : 10,
              decoration: BoxDecoration(
                color: state == _RungState.ahead ? tk.canvas : nodeColor,
                shape: BoxShape.circle,
                border: Border.all(color: nodeColor, width: 2),
                boxShadow: state == _RungState.current
                    ? [BoxShadow(color: nodeColor.withValues(alpha: 0.4), blurRadius: 12)]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRung extends StatelessWidget {
  const _CompactRung({required this.tier, required this.state, required this.dim});
  final PassTier tier;
  final _RungState state;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;

    final cosmetic = tier.kind == RungKind.cosmetic;
    final ink = dim ? tk.inkDim : tk.ink;

    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            tier.tier.toString().padLeft(3, '0'),
            style: Kind.figure(context,
                size: 13,
                color: state == _RungState.current ? tk.accent : tk.inkDim,
                w: FontWeight.w600),
          ),
        ),
        const SizedBox(width: Gap.sm),
        if (cosmetic)
          EmblemMark(
            emblem: Emblem.cipher,
            size: 22,
            color: dim ? tk.inkDim : tk.cool,
          )
        else
          CreditMark(size: 18, color: dim ? tk.inkDim : tk.accent),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The payout *is* what this rung hands over, so it leads. A
              // column of identical "CREDIT PAYOUT" labels told the user
              // nothing and made 150 rungs read as one.
              if (cosmetic)
                Text(
                  tier.cosmeticName ?? 'IN-APP UNLOCK',
                  style: Kind.title(context, size: 13.5, color: ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                CreditAmount(
                  tier.coinPayout,
                  size: 15,
                  color: dim ? tk.inkMid : tk.accent,
                  weight: FontWeight.w700,
                ),
              const SizedBox(height: 3),
              Text(
                cosmetic
                    ? 'In-app unlock'
                    : '${fmt(tier.xpThreshold)} XP to reach',
                style: Kind.body(context, size: 11.5, color: tk.inkDim),
              ),
            ],
          ),
        ),
        if (cosmetic)
          CreditAmount(tier.coinPayout,
              size: 13,
              color: dim ? tk.inkDim : tk.accent,
              weight: FontWeight.w600)
        else if (tier.isMajor)
          Tag('MAJOR', color: dim ? tk.inkDim : tk.accent, filled: !dim)
        else if (tier.isMilestone)
          Tag('MILESTONE', color: dim ? tk.inkDim : tk.accent),
      ],
    );
  }
}

/// Every tenth rung: a real thing from the manifest, given photography.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.tier,
    required this.reward,
    required this.state,
    required this.dim,
  });

  final PassTier tier;
  final Reward? reward;
  final _RungState state;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;

    final r = reward;

    return Opacity(
      opacity: dim ? 0.72 : 1,
      child: Panel(
        padding: EdgeInsets.zero,
        borderColor: state == _RungState.current ? tk.accent : tk.hairline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RewardImage(
                  imageUrl: r?.imageUrl,
                  emblem: r?.emblem ?? Emblem.apex,
                  seed: r?.id ?? 'tier-${tier.tier}',
                  height: 126,
                  radius: const BorderRadius.vertical(top: Radii.lg),
                ),
                Positioned(
                  top: Gap.sm,
                  left: Gap.sm,
                  child: GlassPanel(
                    radius: BorderRadius.circular(999),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    tint: Colors.black.withValues(alpha: 0.35),
                    child: Text(
                      '${Lex.tier} ${tier.tier.toString().padLeft(3, '0')}',
                      style: Kind.label(context, size: 9, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  bottom: Gap.sm,
                  left: Gap.sm,
                  right: Gap.sm,
                  child: Text(
                    r?.name ?? 'REAL-WORLD REWARD',
                    style: Kind.serif(context, size: 17, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 10, Gap.md, 10),
              child: SpreadRow(
                left: Tag(
                  r == null ? 'AWAITING A WISH' : r.tier.label,
                  color: r == null ? tk.inkDim : tk.accent,
                  filled: r != null,
                ),
                right: CreditAmount(
                  r?.coinCost ?? tier.coinPayout,
                  size: 13,
                  color: tk.ink,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
