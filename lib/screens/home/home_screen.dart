import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/economy.dart';
import '../../core/lexicon.dart';
import '../../models/quest.dart';
import '../../models/reward.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/primitives.dart';
import '../../widgets/quest_tile.dart';
import '../../widgets/reward_image.dart';
import '../reward/reward_detail_screen.dart';
import 'add_quest_sheet.dart';

/// The screen the app is for.
///
/// Credits are king and sit at the very top as the single largest element,
/// because that is the number that has to be in front of the user constantly.
/// Under it: the tier bar, then what the climb is actually for, then today's
/// directives grouped by cadence — daily, weekly, monthly — because those are
/// where all the XP comes from and they are the thing a person opens the app to
/// deal with.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();

    // Daily, weekly and monthly are the engine. One-offs come last because they
    // do not recur and so cannot carry a habit.
    const cadences = [
      Cadence.daily,
      Cadence.weekly,
      Cadence.monthly,
      Cadence.quarterly,
      Cadence.once,
    ];
    final groups = {
      for (final c in cadences) c: game.questsOf(c),
    }..removeWhere((_, v) => v.isEmpty);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Gap.huge),
          children: [
            const _CreditHeader(),
            const _UpkeepStrip(),
            const _TierBlock(),
            const _NextUpBlock(),
            const SizedBox(height: Gap.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: SectionHead(
                'DIRECTIVES',
                trailing: GestureDetector(
                  onTap: () => showAddQuestSheet(context),
                  behavior: HitTestBehavior.opaque,
                  child: Lbl('+ NEW', color: context.tk.accent),
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            if (groups.isEmpty)
              VoidState(
                line: 'Nothing is being tracked.',
                sub: 'That is not the same as nothing needing doing. '
                    'Every directive grants XP the moment it is done — even the '
                    'ones that earn nothing.',
                action: SoftButton(
                  label: 'ISSUE A DIRECTIVE',
                  primary: true,
                  onTap: () => showAddQuestSheet(context),
                ),
              )
            else
              for (final entry in groups.entries)
                _CadenceGroup(cadence: entry.key, quests: entry.value),
          ],
        ),
      ),
    );
  }
}

/// The single largest element in the product.
class _CreditHeader extends StatelessWidget {
  const _CreditHeader();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final w = game.wallet;
    final streak = game.profile.streakAsOf(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Lbl(Lex.currency, color: tk.accent),
              const Spacer(),
              if (streak > 0)
                Tag('$streak DAY STREAK', color: tk.cool, filled: true),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CreditMark(size: 34, color: tk.accent, weight: 3),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: NumericFlow(
                    w.coins,
                    style: Kind.numeral(context, size: 58, w: FontWeight.w300),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.md,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Lbl('${Lex.fund} ${euro(game.fund.balanceEuro)}'),
              Container(width: 1, height: 10, color: tk.hairlineStrong),
              Lbl('${fmt(w.totalXp)} XP LIFETIME'),
            ],
          ),
        ],
      ),
    );
  }
}

/// The cost of simply being alive, stated plainly. Hidden entirely until the
/// user defines an obligation, so a new account is not greeted by a bill it has
/// no reason to show.
class _UpkeepStrip extends StatelessWidget {
  const _UpkeepStrip();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    if (game.obligations.isEmpty && !game.upkeep.inArrears) {
      return const SizedBox.shrink();
    }
    final tk = context.tk;
    final up = game.upkeep;
    final red = up.inArrears;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Panel(
        color: red ? tk.alertSoft : tk.surface,
        borderColor: red ? tk.alert.withValues(alpha: 0.4) : tk.hairline,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Lbl(red ? Lex.deficit : '${Lex.upkeep} BALANCE',
                      color: red ? tk.alert : tk.inkDim),
                  const SizedBox(height: 7),
                  CreditAmount(
                    red ? -up.arrearsCredits : up.balanceCredits,
                    size: 22,
                    signed: red,
                    weight: FontWeight.w400,
                    color: red ? tk.alert : tk.ink,
                  ),
                ],
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lbl('DAILY BURN'),
                  const SizedBox(height: 7),
                  CreditAmount(-game.dailyBurnCredits,
                      size: 13, signed: true, color: tk.inkMid),
                  if (red) ...[
                    const SizedBox(height: 5),
                    Lbl('LEVY ${fmt1(up.todaysLevyCredits)}/DAY',
                        color: tk.alert),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tier and the bar toward the next one.
class _TierBlock extends StatelessWidget {
  const _TierBlock();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final w = game.wallet;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpreadRow(
            left: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Lbl(Lex.tier),
                const SizedBox(width: Gap.sm),
                Text(w.level.toString().padLeft(3, '0'),
                    style: Kind.figure(context,
                        size: 18, color: tk.ink, w: FontWeight.w700)),
                Text(' / ${Economy.seasonTiers}',
                    style: Kind.figure(context, size: 12, color: tk.inkDim)),
              ],
            ),
            right: Text('${fmt(w.xpIntoLevel)} / ${fmt(w.xpForNextLevel(game.plan))} XP',
                style: Kind.figure(context, size: 12, color: tk.inkMid)),
          ),
          const SizedBox(height: 12),
          ProgressBar(progress: w.levelProgress(game.plan), height: 7),
          const SizedBox(height: Gap.sm),
          SpreadRow(
            left: Lbl('${fmt(w.xpRemaining(game.plan))} XP TO ${Lex.tier} ${w.level + 1}'),
            right: Lbl('${game.season.daysLeft}D LEFT IN SEASON',
                color: game.season.daysLeft <= 7 ? tk.alert : tk.inkDim),
          ),
        ],
      ),
    );
  }
}

/// What the climb is actually for. The thing being worked toward stays on the
/// home screen at all times — that is the entire premise of the product.
class _NextUpBlock extends StatelessWidget {
  const _NextUpBlock();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final tier = game.nextTier;
    final reward = game.nextAffordableReward;

    if (tier == null && reward == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHead('NEXT UP'),
          const SizedBox(height: Gap.md),
          if (reward != null)
            _RewardPreview(reward: reward, coins: game.wallet.coins)
          else if (tier != null)
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier.hasNamedPrize
                              ? tier.prizeName
                              : '${Lex.tier} ${tier.tier.toString().padLeft(3, '0')}',
                          style: Kind.serif(context, size: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Lbl(game.tiersToNextPrize <= 1
                            ? 'NEXT TIER'
                            : '${game.tiersToNextPrize} TIERS AWAY'),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  CreditAmount(tier.coinPayout, size: 16, color: tk.accent),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardPreview extends StatelessWidget {
  const _RewardPreview({required this.reward, required this.coins});
  final Reward reward;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final p =
        reward.coinCost == 0 ? 1.0 : (coins / reward.coinCost).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(RewardDetailScreen.route(reward.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tk.surface,
          borderRadius: Radii.brLg,
          border: Border.all(color: tk.hairline),
          boxShadow: [
            BoxShadow(color: tk.shadow, blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                RewardImage(
                  imageUrl: reward.imageUrl,
                  emblem: reward.emblem,
                  seed: reward.id,
                  height: 158,
                  radius: const BorderRadius.vertical(top: Radii.lg),
                ),
                Positioned(
                  left: Gap.md,
                  right: Gap.md,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          reward.name,
                          style: Kind.serif(context, size: 20, color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      CreditAmount(reward.coinCost,
                          size: 14, color: Colors.white, weight: FontWeight.w700),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 12, Gap.md, 12),
              child: Column(
                children: [
                  ProgressBar(progress: p, height: 4),
                  const SizedBox(height: Gap.sm),
                  SpreadRow(
                    left: Lbl('${(p * 100).floor()}% FUNDED'),
                    right: Lbl('${fmt(reward.coinCost - coins)} TO GO',
                        color: tk.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One cadence's directives, under a header carrying its own reset countdown.
class _CadenceGroup extends StatelessWidget {
  const _CadenceGroup({required this.cadence, required this.quests});
  final Cadence cadence;
  final List<Quest> quests;

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final tk = context.tk;
    final collectable = quests.where((q) => q.isCollectable).length;

    // Every quest in a cadence shares a reset, so the group carries one clock.
    final soonest = quests
        .map((q) => q.timeLeft)
        .whereType<Duration>()
        .fold<Duration?>(null, (a, b) => a == null || b < a ? b : a);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpreadRow(
            left: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cadence.label,
                    style: Kind.label(context, size: 10, color: tk.ink)),
                if (collectable > 0) ...[
                  const SizedBox(width: Gap.sm),
                  Tag('$collectable READY', color: tk.cool, filled: true),
                ],
              ],
            ),
            right: soonest == null
                ? const SizedBox.shrink()
                : Lbl('RESETS IN ${countdown(soonest)}',
                    color: soonest.inHours < 6 ? tk.alert : tk.inkDim),
          ),
          const SizedBox(height: 10),
          for (final q in quests)
            QuestTile(
              quest: q,
              onComplete: () => game.completeQuest(q.id),
              onCollect: () => game.collectQuest(q.id),
              onLongPress: () => showAddQuestSheet(context, existing: q),
            ),
        ],
      ),
    );
  }
}
