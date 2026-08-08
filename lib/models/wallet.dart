import '../core/economy.dart';

/// The two numbers the whole product revolves around, plus the level they feed.
///
/// [coins] is spendable. [totalXp] is not, ever — it exists only to push the
/// bar. They are kept strictly separate on purpose: see [Economy].
class Wallet {
  /// Spendable currency. Backed by real euros at [Economy.coinsPerEuro].
  final int coins;

  /// Lifetime XP, across every season. Never resets — the lifetime pass reads it.
  final int totalXp;

  /// XP earned inside the current season. Resets when the season does.
  final int seasonXp;

  /// Current battle-pass tier, 1-based.
  final int level;

  /// XP banked toward the *next* tier.
  final int xpIntoLevel;

  /// The in-app currency. Off the euro peg entirely — shards cannot be reached
  /// by earning more money, only by sustained behaviour, which is what makes a
  /// rare cosmetic mean something.
  final int shards;

  /// Lifetime shards, so spending them does not erase the achievement.
  final int lifetimeShards;

  const Wallet({
    this.coins = 0,
    this.totalXp = 0,
    this.seasonXp = 0,
    this.level = 1,
    this.xpIntoLevel = 0,
    this.shards = 0,
    this.lifetimeShards = 0,
  });

  /// XP still required to cross into the next tier, under [plan].
  int xpForNextLevel(LadderPlan plan) => plan.xpFor(level);

  int xpRemaining(LadderPlan plan) {
    final need = xpForNextLevel(plan);
    return (need - xpIntoLevel).clamp(0, need);
  }

  /// 0..1 fill of the level bar.
  double levelProgress(LadderPlan plan) {
    final need = xpForNextLevel(plan);
    return need == 0 ? 0 : (xpIntoLevel / need).clamp(0.0, 1.0);
  }

  double get euroValue => Economy.coinsToEuro(coins);

  /// Grants XP and rolls the level forward as many times as it carries, paying
  /// each crossed tier's credits.
  ///
  /// The payouts come from [plan] rather than a constant, because a season's
  /// whole issuance is derived from the user's real income — see [LadderPlan].
  /// Kept pure so the core loop is trivially testable.
  (Wallet, LevelUpResult) grantXp(int xp, LadderPlan plan) {
    if (xp <= 0) {
      return (
        this,
        LevelUpResult(
          startLevel: level,
          endLevel: level,
          coinsAwarded: 0,
          shardsAwarded: 0,
          xpAwarded: 0,
          tiersCrossed: const [],
        )
      );
    }

    var newLevel = level;
    var into = xpIntoLevel + xp;
    var coinsAwarded = 0;
    var shardsAwarded = 0;
    final crossed = <int>[];

    // Carry across as many tiers as the XP covers. A single big win early on
    // can legitimately pop two or three tiers, and it should.
    while (newLevel < Economy.seasonTiers && into >= plan.xpFor(newLevel)) {
      into -= plan.xpFor(newLevel);
      newLevel += 1;
      crossed.add(newLevel);
      coinsAwarded += plan.payoutFor(newLevel);
      shardsAwarded += Economy.shardsForTier(newLevel);
    }

    // At the season cap the bar pins full; XP still banks toward lifetime.
    if (newLevel >= Economy.seasonTiers) {
      into = plan.xpFor(Economy.seasonTiers);
    }

    return (
      Wallet(
        coins: coins + coinsAwarded,
        totalXp: totalXp + xp,
        seasonXp: seasonXp + xp,
        level: newLevel,
        xpIntoLevel: into,
        shards: shards + shardsAwarded,
        lifetimeShards: lifetimeShards + shardsAwarded,
      ),
      LevelUpResult(
        startLevel: level,
        endLevel: newLevel,
        coinsAwarded: coinsAwarded,
        shardsAwarded: shardsAwarded,
        xpAwarded: xp,
        tiersCrossed: crossed,
      )
    );
  }

  Wallet addCoins(int amount) => copyWith(coins: coins + amount);

  Wallet addShards(int amount) => amount <= 0
      ? this
      : copyWith(
          shards: shards + amount,
          lifetimeShards: lifetimeShards + amount,
        );

  Wallet spendShards(int amount) =>
      copyWith(shards: (shards - amount).clamp(0, 1 << 62));

  bool canAffordShards(int amount) => shards >= amount;

  /// Burns coins. Callers must check affordability *and* fund cover first —
  /// see `GameState.claimReward`.
  Wallet spendCoins(int amount) => copyWith(coins: (coins - amount).clamp(0, 1 << 62));

  /// Wipes season progress but keeps coins and lifetime XP. Called on rollover.
  Wallet resetSeason() => copyWith(seasonXp: 0, level: 1, xpIntoLevel: 0);

  Wallet copyWith({
    int? coins,
    int? totalXp,
    int? seasonXp,
    int? level,
    int? xpIntoLevel,
    int? shards,
    int? lifetimeShards,
  }) =>
      Wallet(
        coins: coins ?? this.coins,
        totalXp: totalXp ?? this.totalXp,
        seasonXp: seasonXp ?? this.seasonXp,
        level: level ?? this.level,
        xpIntoLevel: xpIntoLevel ?? this.xpIntoLevel,
        shards: shards ?? this.shards,
        lifetimeShards: lifetimeShards ?? this.lifetimeShards,
      );

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'total_xp': totalXp,
        'season_xp': seasonXp,
        'level': level,
        'xp_into_level': xpIntoLevel,
        'shards': shards,
        'lifetime_shards': lifetimeShards,
      };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
        seasonXp: (json['season_xp'] as num?)?.toInt() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 1,
        xpIntoLevel: (json['xp_into_level'] as num?)?.toInt() ?? 0,
        shards: (json['shards'] as num?)?.toInt() ?? 0,
        lifetimeShards: (json['lifetime_shards'] as num?)?.toInt() ?? 0,
      );
}

/// The honesty anchor. Real money, set aside from real income, that a reward
/// must genuinely be covered by before it can be claimed. Coins are the game;
/// this is reality, and the two stay tied together.
class Fund {
  /// Real euros available.
  final double balanceEuro;

  /// Share of logged income that flows into the fund.
  final double percent;

  /// Lifetime euros that have ever entered the fund — for the settings readout.
  final double lifetimeEuro;

  const Fund({
    this.balanceEuro = 0,
    this.percent = Economy.defaultFundPercent,
    this.lifetimeEuro = 0,
  });

  int get balanceCoins => Economy.euroToCoins(balanceEuro);

  bool covers(double priceEuro) => balanceEuro + 1e-9 >= priceEuro;

  Fund deposit(double euro) => copyWith(
        balanceEuro: balanceEuro + euro,
        lifetimeEuro: lifetimeEuro + euro,
      );

  Fund withdraw(double euro) =>
      copyWith(balanceEuro: (balanceEuro - euro).clamp(0, double.infinity));

  Fund copyWith({double? balanceEuro, double? percent, double? lifetimeEuro}) => Fund(
        balanceEuro: balanceEuro ?? this.balanceEuro,
        percent: percent ?? this.percent,
        lifetimeEuro: lifetimeEuro ?? this.lifetimeEuro,
      );

  Map<String, dynamic> toJson() => {
        'balance_euro': balanceEuro,
        'percent': percent,
        'lifetime_euro': lifetimeEuro,
      };

  factory Fund.fromJson(Map<String, dynamic> json) => Fund(
        balanceEuro: (json['balance_euro'] as num?)?.toDouble() ?? 0,
        percent: (json['percent'] as num?)?.toDouble() ?? Economy.defaultFundPercent,
        lifetimeEuro: (json['lifetime_euro'] as num?)?.toDouble() ?? 0,
      );
}

/// A real income entry the user logged. Feeds the fund and grants the XP for
/// the work behind it.
class IncomeEntry {
  final String id;
  final String source;
  final double amountEuro;
  final double toFundEuro;
  final DateTime loggedAt;

  const IncomeEntry({
    required this.id,
    required this.source,
    required this.amountEuro,
    required this.toFundEuro,
    required this.loggedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'amount_euro': amountEuro,
        'to_fund_euro': toFundEuro,
        'logged_at': loggedAt.toIso8601String(),
      };

  factory IncomeEntry.fromJson(Map<String, dynamic> json) => IncomeEntry(
        id: json['id'] as String,
        source: json['source'] as String? ?? '',
        amountEuro: (json['amount_euro'] as num?)?.toDouble() ?? 0,
        toFundEuro: (json['to_fund_euro'] as num?)?.toDouble() ?? 0,
        loggedAt: DateTime.parse(json['logged_at'] as String).toLocal(),
      );
}
