/// How hard a cosmetic is to come by.
///
/// Rarity does three jobs at once: it sets the shard price, it sets the odds
/// inside a lootbox, and it tells the user at a glance whether what they just
/// pulled was worth anything. Those three must agree, or the economy reads as
/// arbitrary — so all of it is derived from this one enum.
enum Rarity { common, uncommon, rare, epic, legendary }

extension RarityInfo on Rarity {
  String get label => switch (this) {
        Rarity.common => 'COMMON',
        Rarity.uncommon => 'UNCOMMON',
        Rarity.rare => 'RARE',
        Rarity.epic => 'EPIC',
        Rarity.legendary => 'LEGENDARY',
      };

  /// Shard price when bought outright.
  ///
  /// Deliberately steep. A whole season of milestone tiers pays a few hundred
  /// shards, so a legendary is genuinely several seasons of sustained streaks —
  /// which is the point: it has to be unreachable by spending money.
  int get shardPrice => switch (this) {
        Rarity.common => 40,
        Rarity.uncommon => 120,
        Rarity.rare => 350,
        Rarity.epic => 900,
        Rarity.legendary => 2500,
      };

  /// Relative weight inside a lootbox roll.
  double get weight => switch (this) {
        Rarity.common => 58,
        Rarity.uncommon => 27,
        Rarity.rare => 11,
        Rarity.epic => 3.4,
        Rarity.legendary => 0.6,
      };

  /// What a duplicate refunds. Never nothing — a repeat pull that pays zero is
  /// the fastest way to make a box feel like a swindle.
  int get dustValue => (shardPrice * 0.35).round();
}

/// What a lootbox costs.
///
/// Priced so a box is a worse expected value than saving for the thing you
/// actually want — the gamble should be a choice, not the efficient path.
const lootboxShardPrice = 250;
