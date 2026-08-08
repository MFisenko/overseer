import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';


import '../../core/lexicon.dart';
import '../../models/reward.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/emblem.dart';
import '../../widgets/primitives.dart';
import '../../widgets/reward_image.dart';

/// A single reward, given a full page.
///
/// Laid out like a magazine feature rather than a product listing: the image
/// runs to the edges and carries the top third of the page, the name is set
/// large in the editorial serif over it, and the price sits below in its own
/// quiet block. The point is that a thing worth months of effort should look
/// like it is worth months of effort.
class RewardDetailScreen extends StatelessWidget {
  const RewardDetailScreen({super.key, required this.rewardId});
  final String rewardId;

  static Route<void> route(String rewardId) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => RewardDetailScreen(rewardId: rewardId),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.035), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;

    Reward? reward;
    for (final r in game.rewards) {
      if (r.id == rewardId) reward = r;
    }

    if (reward == null) {
      // The item was dismissed while this page was open. Say so plainly rather
      // than showing an empty shell.
      return Scaffold(
        appBar: AppBar(leading: const _BackChip()),
        body: const VoidState(
          line: 'No longer on the manifest.',
          sub: 'This item was removed.',
        ),
      );
    }

    final r = reward;
    final media = MediaQuery.sizeOf(context);
    final heroHeight = (media.height * 0.46).clamp(260.0, 460.0);
    final blocked = game.claimBlockReason(r);
    final affordability =
        r.coinCost == 0 ? 1.0 : (game.wallet.coins / r.coinCost).clamp(0.0, 1.0);

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: heroHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RewardImage(
                        imageUrl: r.imageUrl,
                        emblem: r.emblem,
                        seed: r.id,
                        radius: BorderRadius.zero,
                        height: heroHeight,
                      ),
                      Positioned(
                        left: Gap.lg,
                        right: Gap.lg,
                        bottom: Gap.lg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Tag(r.tier.label,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    filled: true),
                                const SizedBox(width: Gap.sm),
                                Tag(r.kind.label,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    filled: true),
                              ],
                            ),
                            const SizedBox(height: Gap.md),
                            Text(
                              r.name,
                              style: Kind.display(context,
                                  size: r.name.length > 26 ? 30 : 40,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, Gap.huge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------------------------------------------- price
                      SectionHead(r.status == RewardStatus.locked
                          ? 'COMMITTED GOAL'
                          : 'COST'),
                      const SizedBox(height: Gap.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: CreditAmount(r.coinCost,
                                size: 40, weight: FontWeight.w300),
                          ),
                          const SizedBox(width: Gap.md),
                          EmblemMark(emblem: r.emblem, size: 34),
                        ],
                      ),
                      const SizedBox(height: Gap.sm),
                      Text(
                        r.kind == RewardKind.inGame
                            ? 'Earned, not bought.'
                            : 'Backed by ${euro(r.priceEuro)} of real money.',
                        style: Kind.body(context, size: 13),
                      ),
                      const SizedBox(height: Gap.lg),
                      ProgressBar(
                        progress: affordability,
                        color: affordability >= 1 ? tk.cool : tk.accent,
                      ),
                      const SizedBox(height: Gap.sm),
                      SpreadRow(
                        left: Lbl('${(affordability * 100).floor()}% FUNDED'),
                        right: blocked != null
                            ? Lbl(blocked, color: tk.alert)
                            : Lbl('READY', color: tk.cool),
                      ),

                      // ---------------------------------------- description
                      if (r.description != null && r.description!.isNotEmpty) ...[
                        const SizedBox(height: Gap.xl),
                        const SectionHead('THE ITEM'),
                        const SizedBox(height: Gap.md),
                        Text(r.description!,
                            style: Kind.serif(context, size: 17, w: FontWeight.w400)
                                .copyWith(height: 1.5, color: tk.inkMid)),
                      ],

                      // --------------------------------------------- detail
                      const SizedBox(height: Gap.xl),
                      const SectionHead('RECORD'),
                      const SizedBox(height: Gap.md),
                      _Row(label: 'CATEGORY', value: r.bucketName),
                      _Row(label: 'TIER', value: r.tier.label),
                      _Row(
                          label: 'ORIGIN',
                          value: r.origin == RewardOrigin.ai
                              ? 'SURFACED BY OVERSEER'
                              : 'ADDED BY YOU'),
                      if (r.kind == RewardKind.realWorld)
                        _Row(label: 'REAL PRICE', value: euro(r.priceEuro)),
                      if (r.priceDelta != null && r.priceDelta!.abs() > 0.5)
                        _Row(
                          label: 'PRICE MOVED',
                          value:
                              '${r.priceDelta! > 0 ? '+' : '−'}${euro(r.priceDelta!.abs())}',
                          color: r.priceDelta! > 0 ? tk.alert : tk.cool,
                        ),
                      if (r.priceCheckedAt != null)
                        _Row(
                            label: 'CHECKED',
                            value: _ago(r.priceCheckedAt!)),
                      _Row(label: 'ADDED', value: _ago(r.createdAt)),

                      if (r.sourceUrl != null && r.sourceUrl!.isNotEmpty) ...[
                        const SizedBox(height: Gap.md),
                        SoftButton(
                          label: 'VIEW SOURCE',
                          dense: true,
                          onTap: () => launchUrl(Uri.parse(r.sourceUrl!),
                              mode: LaunchMode.externalApplication),
                        ),
                      ],

                      // -------------------------------------------- actions
                      const SizedBox(height: Gap.xl),
                      _Actions(reward: r),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, child: SafeArea(child: _BackChip())),
        ],
      ),
    );
  }

  static String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return 'TODAY';
    if (days == 1) return 'YESTERDAY';
    if (days < 30) return '$days DAYS AGO';
    final months = (days / 30.44).floor();
    if (months < 12) return '$months MONTH${months == 1 ? '' : 'S'} AGO';
    final years = (days / 365.25).floor();
    return '$years YEAR${years == 1 ? '' : 'S'} AGO';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Lbl(label),
            const SizedBox(width: Gap.md),
            Expanded(child: Container(height: 1, color: context.tk.hairline)),
            const SizedBox(width: Gap.md),
            Text(value,
                style: Kind.figure(context,
                    size: 12, color: color ?? context.tk.ink)),
          ],
        ),
      );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.reward});
  final Reward reward;

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameState>();
    final r = reward;

    if (r.status == RewardStatus.bought) {
      return Row(children: [
        Tag('ACQUIRED', color: context.tk.cool, filled: true),
        const SizedBox(width: Gap.sm),
        Text('This one is yours.', style: Kind.body(context, size: 13)),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.status == RewardStatus.claimed) ...[
          SoftButton(
            label: 'I BOUGHT THIS',
            primary: true,
            expand: true,
            onTap: () => game.markBought(r.id),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Marks it acquired and takes ${euro(r.priceEuro)} out of the '
            '${Lex.fund.toLowerCase()}. No card is ever connected — you press '
            'this when you actually went and got it.',
            style: Kind.body(context, size: 12),
          ),
        ] else ...[
          SoftButton(
            label: 'CLAIM',
            primary: true,
            expand: true,
            onTap: game.canClaim(r) ? () => game.claimReward(r.id) : null,
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: r.starred ? 'STARRED' : 'STAR',
                  expand: true,
                  onTap: () => game.starReward(r.id, !r.starred),
                ),
              ),
              const SizedBox(width: Gap.sm),
              if (r.status != RewardStatus.locked)
                Expanded(
                  child: SoftButton(
                    label: 'LOCK IN',
                    expand: true,
                    onTap: () => _confirmLock(context, game, r),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          SoftButton(
            label: 'REMOVE FROM MANIFEST',
            danger: true,
            expand: true,
            dense: true,
            onTap: () {
              game.dismissReward(r.id);
              Navigator.of(context).maybePop();
            },
          ),
        ],
      ],
    );
  }

  Future<void> _confirmLock(BuildContext context, GameState game, Reward r) async {
    final tk = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tk.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
        title: Text('Lock this in?', style: Kind.serif(ctx, size: 20)),
        content: Text(
          'Its price and details stop being editable. That is the point — a '
          'goal you committed to on a good day should not be quietly shrunk on '
          'a bad one.',
          style: Kind.body(ctx, size: 13.5),
        ),
        actions: [
          SoftButton(label: 'CANCEL', dense: true, onTap: () => Navigator.pop(ctx, false)),
          SoftButton(
              label: 'LOCK IN',
              dense: true,
              primary: true,
              onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) await game.lockReward(r.id);
  }
}

/// A frosted back affordance that works over photography in both modes.
class _BackChip extends StatelessWidget {
  const _BackChip();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: GlassPanel(
            radius: BorderRadius.circular(999),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            tint: Colors.black.withValues(alpha: 0.32),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text('BACK',
                    style: Kind.label(context, size: 9.5, color: Colors.white)),
              ],
            ),
          ),
        ),
      );
}
