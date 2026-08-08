import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/rarity.dart';
import '../../models/appearance.dart';
import '../../models/companion.dart';
import '../../models/unlockable.dart';
import '../../state/game_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/companion/overseer_eye.dart';
import '../../widgets/primitives.dart';
import '../../widgets/shard_mark.dart';
import '../../widgets/sheet.dart';

Future<void> showAppearanceSheet(BuildContext context) =>
    showOverseerSheet(context, child: const _AppearanceSheet());

/// The wardrobe.
///
/// Six independent axes that combine into thousands of looks. Everything you do
/// not own is shown rather than hidden, greyed out with its price — a locked
/// thing you can see is a goal, a locked thing you cannot see is nothing.
class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final a = game.companion.appearance;
    final offer = game.monthlyOffer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            OverseerEye(
              mood: game.companion.mood,
              appearance: a,
              size: 84,
              flat: true,
              streakDays: game.currentStreak,
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wardrobe', style: Kind.display(context, size: 26)),
                  const SizedBox(height: 6),
                  ShardAmount(game.wallet.shards, size: 15),
                  const SizedBox(height: 3),
                  Text('${game.ownedCount} of ${UnlockCatalogue.all.length} owned',
                      style: Kind.body(context, size: 11.5)),
                ],
              ),
            ),
          ],
        ),

        // ------------------------------------------------------ this month
        if (offer != null) ...[
          const SizedBox(height: Gap.xl),
          const SectionHead('THIS MONTH ONLY'),
          const SizedBox(height: Gap.md),
          _MonthlyOffer(offer: offer),
        ],

        // ---------------------------------------------------------- the box
        const SizedBox(height: Gap.xl),
        const SectionHead('SEALED BOX'),
        const SizedBox(height: Gap.md),
        _BoxCard(),

        // ------------------------------------------------------- the axes
        for (final slot in UnlockSlot.values) ...[
          const SizedBox(height: Gap.xl),
          SectionHead(
            slot.label,
            trailing: Lbl(
              '${UnlockCatalogue.inSlot(slot).where(game.owns).length}'
              '/${UnlockCatalogue.inSlot(slot).length}',
              color: tk.inkDim,
            ),
          ),
          const SizedBox(height: Gap.md),
          _SlotGrid(slot: slot),
        ],

        const SizedBox(height: Gap.lg),
        Text(
          'Shards come from collecting directives, holding streaks and crossing '
          'milestone tiers. They cannot be bought with money, and neither can '
          'anything here.',
          style: Kind.body(context, size: 11.5, color: tk.inkDim),
        ),
      ],
    );
  }
}

class _MonthlyOffer extends StatelessWidget {
  const _MonthlyOffer({required this.offer});
  final Unlockable offer;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final owned = game.owns(offer);
    final afford = game.wallet.shards >= offer.shardPrice;

    return Panel(
      borderColor: owned ? tk.cool : tk.accent,
      child: Row(
        children: [
          _Preview(unlockable: offer, size: 52),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.name, style: Kind.serif(context, size: 18)),
                const SizedBox(height: 4),
                Row(children: [
                  Tag(offer.rarity.label,
                      color: rarityColour(context, offer.rarity), filled: true),
                  const SizedBox(width: Gap.sm),
                  Lbl(offer.slot.label),
                ]),
                const SizedBox(height: 6),
                Text(
                  owned
                      ? 'Yours.'
                      : 'Gone at the end of the month. One rotates in at a time.',
                  style: Kind.body(context, size: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          if (owned)
            Icon(Icons.check_rounded, size: 20, color: tk.cool)
          else
            SoftButton(
              label: '${offer.shardPrice}',
              primary: afford,
              dense: true,
              onTap: afford ? () => game.buyUnlock(offer) : null,
              icon: ShardMark(
                  size: 12, color: afford ? tk.onAccent : tk.inkDim),
            ),
        ],
      ),
    );
  }
}

class _BoxCard extends StatefulWidget {
  @override
  State<_BoxCard> createState() => _BoxCardState();
}

class _BoxCardState extends State<_BoxCard> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final afford = game.wallet.shards >= lootboxShardPrice;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A sealed box', style: Kind.serif(context, size: 18)),
                    const SizedBox(height: 4),
                    Text(
                      'One roll from everything not on sale this month. Worse '
                      'value than saving for what you actually want — that is '
                      'the trade.',
                      style: Kind.body(context, size: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              SoftButton(
                label: _opening ? '…' : '$lootboxShardPrice',
                primary: afford && !_opening,
                onTap: (!afford || _opening)
                    ? null
                    : () async {
                        setState(() => _opening = true);
                        await game.openLootbox();
                        if (mounted) setState(() => _opening = false);
                      },
                icon: ShardMark(
                    size: 13, color: afford ? tk.onAccent : tk.inkDim),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Rule(),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: 6,
            children: [
              for (final r in Rarity.values)
                Tag('${r.label} ${(r.weight).toStringAsFixed(r.weight < 1 ? 1 : 0)}%',
                    color: rarityColour(context, r)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text('A duplicate refunds dust rather than nothing.',
              style: Kind.body(context, size: 11, color: tk.inkDim)),
        ],
      ),
    );
  }
}

/// One axis of options. Owned ones are live; the rest are visibly present but
/// greyed, with what they cost.
class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.slot});
  final UnlockSlot slot;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final u in UnlockCatalogue.inSlot(slot))
          _OptionTile(unlockable: u, owned: game.owns(u)),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.unlockable, required this.owned});
  final Unlockable unlockable;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    final tk = context.tk;
    final u = unlockable;
    final selected = game.isEquipped(u);
    final buyable = game.canBuy(u);
    final afford = game.wallet.shards >= u.shardPrice;

    return GestureDetector(
      onTap: () {
        if (owned) {
          game.equipUnlock(u);
        } else if (buyable && afford) {
          game.buyUnlock(u);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        // Locked options stay visible — a locked thing you can see is a goal.
        opacity: owned ? 1 : 0.45,
        child: Container(
          width: 78,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? tk.accentSoft : Colors.transparent,
            border: Border.all(
              color: selected
                  ? tk.accent
                  : owned
                      ? tk.hairline
                      : rarityColour(context, u.rarity).withValues(alpha: 0.4),
            ),
            borderRadius: Radii.brMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 40,
                child: Center(child: _Preview(unlockable: u, size: 38)),
              ),
              const SizedBox(height: 6),
              Text(
                u.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Kind.label(context,
                    size: 8, color: selected ? tk.accent : tk.inkDim),
              ),
              const SizedBox(height: 4),
              if (owned)
                Icon(
                  selected ? Icons.check_rounded : Icons.circle_outlined,
                  size: 11,
                  color: selected ? tk.accent : tk.inkDim,
                )
              else if (!buyable)
                Icon(Icons.lock_clock_outlined, size: 11, color: tk.inkDim)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShardMark(
                        size: 9,
                        color: afford ? tk.accent : tk.inkDim),
                    const SizedBox(width: 3),
                    Text('${u.shardPrice}',
                        style: Kind.figure(context,
                            size: 9,
                            color: afford ? tk.accent : tk.inkDim)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders an option as the overseer would wear it, so choosing is done by
/// looking rather than by reading a name.
class _Preview extends StatelessWidget {
  const _Preview({required this.unlockable, this.size = 38});
  final Unlockable unlockable;
  final double size;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameState>();
    return OverseerEye(
      mood: CompanionMood.idle,
      appearance: game.appearanceWith(unlockable),
      size: size,
      flat: true,
      lookAt: Offset.zero,
    );
  }
}

/// Rarity reads as colour before it reads as a word.
Color rarityColour(BuildContext context, Rarity r) {
  final tk = context.tk;
  return switch (r) {
    Rarity.common => tk.inkDim,
    Rarity.uncommon => tk.cool,
    Rarity.rare => const Color(0xFF4A8FE0),
    Rarity.epic => const Color(0xFF9B6BD6),
    Rarity.legendary => tk.accent,
  };
}
