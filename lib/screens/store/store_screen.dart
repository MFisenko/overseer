import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/lexicon.dart';
import '../../models/reward.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/credit_mark.dart';
import '../../widgets/emblem.dart';
import '../../widgets/primitives.dart';
import '../../widgets/reward_image.dart';
import '../reward/reward_detail_screen.dart';
import 'add_wish_sheet.dart';

/// The store. Everything spendable, real and in-app, on one shelf.
///
/// Laid out like a boutique rather than a shop: two columns, photography doing
/// the work, prices set quietly underneath. Real things and in-app things sit
/// side by side deliberately — the free wins are what carry the ordinary days
/// between the purchases, so hiding them in another tab would be a mistake.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

enum _Filter { all, real, inApp, affordable }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'EVERYTHING',
        _Filter.real => 'REAL WORLD',
        _Filter.inApp => 'IN APP',
        _Filter.affordable => 'AFFORDABLE',
      };
}

class _StoreScreenState extends State<StoreScreen> {
  _Filter _filter = _Filter.all;
  String? _bucket;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;

    var stock = game.storeStock;
    stock = switch (_filter) {
      _Filter.all => stock,
      _Filter.real => stock.where((r) => r.kind == RewardKind.realWorld).toList(),
      _Filter.inApp => stock.where((r) => r.kind == RewardKind.inGame).toList(),
      _Filter.affordable =>
        stock.where((r) => r.coinCost <= game.wallet.coins).toList(),
    };
    if (_bucket != null) {
      stock = stock.where((r) => r.bucketName == _bucket).toList();
    }

    final buckets = <String>{for (final r in game.storeStock) r.bucketName}.toList()
      ..sort();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _StoreHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, 0, Gap.sm),
                child: SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _Filter.values) ...[
                        _Pill(
                          label: f.label,
                          selected: _filter == f,
                          onTap: () => setState(() => _filter = f),
                        ),
                        const SizedBox(width: Gap.sm),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (buckets.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, 0, 0, Gap.md),
                  child: SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _Pill(
                          label: 'ALL CATEGORIES',
                          selected: _bucket == null,
                          subtle: true,
                          onTap: () => setState(() => _bucket = null),
                        ),
                        const SizedBox(width: Gap.sm),
                        for (final b in buckets) ...[
                          _Pill(
                            label: b,
                            selected: _bucket == b,
                            subtle: true,
                            onTap: () => setState(
                                () => _bucket = _bucket == b ? null : b),
                          ),
                          const SizedBox(width: Gap.sm),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (stock.isEmpty)
              SliverToBoxAdapter(
                child: VoidState(
                  line: game.rewards.isEmpty
                      ? 'The ${Lex.bucketList.toLowerCase()} is empty.'
                      : game.longRangeGoals.isNotEmpty
                          ? 'Nothing here is within a season.'
                          : 'Nothing matches that filter.',
                  sub: game.rewards.isEmpty
                      ? 'Add something you actually want. Speak it, type it, or '
                          'paste a picture of it — the overseer will price it.'
                      : game.longRangeGoals.isNotEmpty
                          ? '${game.longRangeGoals.length} goal(s) are further out '
                              'than one season. They are in the vault, with their '
                              'own pots and their own dates.'
                          : null,
                  action: game.rewards.isEmpty
                      ? SoftButton(
                          label: 'ADD A WISH',
                          primary: true,
                          onTap: () => showAddWishSheet(context),
                        )
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.huge),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: Gap.md,
                    crossAxisSpacing: Gap.md,
                    // Tall enough for a two-line item name plus the price
                    // block; 0.66 clipped by a hair on a 390pt phone.
                    childAspectRatio: 0.60,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ShelfCard(reward: stock[i]),
                    childCount: stock.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddWishSheet(context),
        backgroundColor: tk.accent,
        foregroundColor: tk.onAccent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('ADD A WISH',
            style: Kind.label(context, size: 10, color: tk.onAccent)),
      ),
    );
  }
}

/// Credits first, as everywhere. The reserve line underneath is the only place
/// in the app a euro sign is allowed, because there the figure really is money.
class _StoreHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The Store', style: Kind.display(context, size: 32)),
          const SizedBox(height: Gap.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // The balance takes whatever room it needs and shrinks rather
              // than wrapping — a six-figure balance must not push the reserve
              // readout off the row.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CreditMark(size: 24, color: tk.accent),
                      const SizedBox(width: 10),
                      NumericFlow(
                        game.wallet.coins,
                        style:
                            Kind.numeral(context, size: 34, w: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Gap.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lbl(Lex.fund),
                  const SizedBox(height: 5),
                  Text(euro(game.fund.balanceEuro),
                      style: Kind.figure(context, size: 14, color: tk.inkMid)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'A reward unlocks when both agree: enough credits earned, and '
            'enough real money set aside to actually buy it.',
            style: Kind.body(context, size: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtle = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? (subtle ? tk.accentSoft : tk.ink) : Colors.transparent,
          border: Border.all(
              color: selected
                  ? (subtle ? tk.accent : tk.ink)
                  : tk.hairlineStrong),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Kind.label(
            context,
            size: 9.5,
            color: selected
                ? (subtle ? tk.accent : tk.canvas)
                : tk.inkDim,
          ),
        ),
      ),
    );
  }
}

/// One item on the shelf. Photography, name, price — nothing else, because a
/// boutique does not explain itself on the shelf.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.reward});
  final Reward reward;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final r = reward;
    final affordable = game.canClaim(r);
    final progress =
        r.coinCost == 0 ? 1.0 : (game.wallet.coins / r.coinCost).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(RewardDetailScreen.route(r.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tk.surface,
          borderRadius: Radii.brLg,
          border: Border.all(color: affordable ? tk.accent : tk.hairline),
          boxShadow: [
            BoxShadow(color: tk.shadow, blurRadius: 20, offset: const Offset(0, 6)),
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
                  height: 150,
                  radius: const BorderRadius.vertical(top: Radii.lg),
                ),
                Positioned(
                  top: Gap.sm,
                  right: Gap.sm,
                  child: EmblemMark(
                    emblem: r.emblem,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (r.status == RewardStatus.locked)
                  Positioned(
                    top: Gap.sm,
                    left: Gap.sm,
                    child: GlassPanel(
                      radius: BorderRadius.circular(999),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tint: Colors.black.withValues(alpha: 0.4),
                      child: Text('COMMITTED',
                          style: Kind.label(context, size: 8, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: Kind.serif(context, size: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      r.bucketName,
                      style: Kind.label(context, size: 8.5),
                    ),
                    const Spacer(),
                    ProgressBar(
                      progress: progress,
                      height: 3,
                      color: affordable ? tk.cool : tk.accent,
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Expanded(
                          child: CreditAmount(
                            r.coinCost,
                            size: 13,
                            weight: FontWeight.w600,
                            color: affordable ? tk.cool : tk.ink,
                          ),
                        ),
                        if (affordable)
                          Text('READY',
                              style: Kind.label(context,
                                  size: 8.5, color: tk.cool)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
