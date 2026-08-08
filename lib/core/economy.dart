import '../models/calibration.dart';

/// What a rung of the ladder hands over.
enum RungKind {
  /// Advancement only. Most of the ladder — with a fixed credit budget,
  /// paying on fewer rungs makes each payout bigger and worth remembering.
  nothing,

  /// A small credit payout.
  credits,

  /// A cosmetic unlock, no credits.
  cosmetic,

  /// A real-world reward from the manifest, plus credits.
  real,

  /// A quarter-marker: the best real-world reward and the largest payout.
  major,
}

/// Every tunable number in the game, in one place.
///
/// Three rules the rest of the codebase depends on and must never break:
///
///  1. Tasks grant **XP only**. XP is unspendable and exists solely to push the
///     ladder. Progress is therefore constant, including on days that earn
///     nothing at all.
///  2. Credits are paid **only on crossing a tier**, which is what makes the
///     payout a burst rather than a trickle.
///  3. A season's **entire credit issuance is derived from the user's real
///     income**. See [LadderPlan] — this is what keeps credits and euros in
///     lockstep instead of letting effort mint money that does not exist.
class Economy {
  const Economy._();

  // ---------------------------------------------------------------- the peg
  /// One euro is one hundred credits. Inflated figures read as more addictive —
  /// a €5 coffee is 500 credits — but underneath, a credit is always a real
  /// cent.
  ///
  /// The peg is internal plumbing. The interface shows the credit mark, never a
  /// euro sign, except in the reserve readout where the figure genuinely *is*
  /// real money.
  static const coinsPerEuro = 100;

  static int euroToCoins(double euro) => (euro * coinsPerEuro).round();
  static double coinsToEuro(int coins) => coins / coinsPerEuro;

  // ------------------------------------------------------------- the ladder
  static const seasonTiers = 150;

  /// A season runs three months, then resets. The reset is the point: the
  /// expiry is what creates the pressure to come back.
  static const seasonDays = 91;

  // The base XP curve, before difficulty. Quadratic, so the opening tiers fall
  // fast enough to hook and the late ones are a genuine grind.
  static const _xpBase = 60;
  static const _xpLinear = 3.0;
  static const _xpQuadratic = 0.045;

  /// XP to move from [tier] to the next, at the given difficulty.
  ///
  /// Landing zones for a committed season of roughly 350 XP a day:
  /// BASIC ~tier 90, CHALLENGING ~tier 62, EXTREME ~tier 42, HELL ~tier 28.
  static int xpForTier(int tier, Difficulty difficulty) {
    final n = (tier - 1).toDouble();
    final base = _xpBase + _xpLinear * n + _xpQuadratic * n * n;
    return (base * difficulty.xpMultiplier).round();
  }

  static int cumulativeXpToTier(int tier, Difficulty difficulty) {
    var total = 0;
    for (var t = 1; t < tier; t++) {
      total += xpForTier(t, difficulty);
    }
    return total;
  }

  /// The rhythm of the ladder.
  ///
  /// Deliberately sparse: roughly eighty of the hundred and fifty rungs hand
  /// over nothing but advancement. That is what lets the ones that *do* pay
  /// land as an event rather than as background noise.
  static RungKind rungKind(int tier) {
    if (tier % 25 == 0) return RungKind.major;
    if (tier % 10 == 0) return RungKind.real;
    if (tier % 5 == 0) return RungKind.cosmetic;
    if (tier % 3 == 0) return RungKind.credits;
    return RungKind.nothing;
  }

  // ----------------------------------------------------- the second currency
  /// Shards buy everything inside the app: shapes, finishes, paints, eyes,
  /// accessories.
  ///
  /// They are deliberately kept off the euro peg. Credits are real money and
  /// must stay scarce for that reason; shards are scarce for a different one —
  /// they are the only thing that cannot be reached by earning more, which is
  /// what makes a rare skin mean something a rich user cannot simply buy.
  ///
  /// They arrive only from sustained behaviour: collecting directives, holding
  /// streaks, crossing milestone tiers, and levelling a craft.
  static const shardsPerCollect = 1;
  static const shardsPerMasteryLevel = 8;

  /// Milestone tiers hand over shards as well as credits. Ordinary rungs do not.
  static int shardsForTier(int tier) {
    if (tier % 25 == 0) return 40;
    if (tier % 10 == 0) return 15;
    if (tier % 5 == 0) return 6;
    return 0;
  }

  /// Streak milestones, in days, and what each pays. Holding a streak is by far
  /// the most productive way to earn shards, which is the intended lesson.
  static const streakShardMilestones = <int, int>{
    3: 5,
    7: 15,
    14: 30,
    30: 75,
    60: 150,
    100: 300,
    365: 1500,
  };

  // ------------------------------------------------------ rewarding capture
  /// Using the app is itself worth something.
  ///
  /// Writing a thing down is the step people actually skip, and an unrecorded
  /// intention cannot be completed later. These are deliberately tiny — enough
  /// to acknowledge the act, never enough to make logging noise a strategy.
  static const xpForCapture = 1; // issuing a directive
  static const xpForDumpItem = 2; // one line filed from a braindump
  static const xpForWish = 3; // adding something to the manifest
  static const creditsForCapture = 1;
  static const creditsForWish = 2;

  /// Capture XP is deliberately *not* multiplied by the streak: writing things
  /// down should never become the efficient way to farm the bar.
  ///
  /// Completion XP is. The curve is punishing cold and merely demanding once a
  /// habit is real — which is the shape a motivation app wants, because the
  /// first week is where people quit.
  static double streakMultiplier(int streakDays) {
    if (streakDays >= 30) return 2.0;
    if (streakDays >= 14) return 1.6;
    if (streakDays >= 7) return 1.35;
    if (streakDays >= 3) return 1.15;
    return 1.0;
  }

  /// The next streak length that changes the multiplier, for the readout.
  static int? nextStreakStep(int streakDays) {
    for (final step in const [3, 7, 14, 30]) {
      if (streakDays < step) return step;
    }
    return null;
  }

  // ------------------------------------------------------- starting task XP
  /// Presets, all editable.
  ///
  /// Work that brings in no money is worth deliberately little — but never
  /// zero, and never so little that the bar fails to move. A person who gets
  /// no acknowledgement for the dishes stops logging the dishes, and then
  /// stops opening the app.
  static const xpTrivial = 3; // dishes, a walk, a glass of water
  static const xpSmall = 8; // an errand, a tidy-up
  static const xpSession = 25; // a focused session that pays nothing

  /// Work that actually brings money in is worth several times more, because
  /// it is the only thing that refills the reserve the rewards come out of.
  static const xpPaidSession = 75;
  static const xpBigWin = 250;

  /// XP per hour logged against a mastery track.
  static const xpPerMasteryHour = 25;

  // ------------------------------------------------------------- the fund
  static const defaultFundPercent = 10.0;

  // ------------------------------------------------------------ money tiers
  static const smallTierMaxEuro = 100.0;
  static const midTierMaxEuro = 1000.0;

  // ------------------------------------------------------------- upkeep
  /// Daily levy charged on a negative upkeep balance. Near-symbolic by design:
  /// the pressure comes from watching the number tick, not from being buried.
  static const defaultArrearsDailyRate = 0.00005; // 0.005%

  /// Share of each tier payout diverted to arrears while in the red.
  static const defaultGarnishRate = 0.25;

  static const weekDays = 7.0;
  static const monthDays = 30.44;

  // ----------------------------------------------------------- mastery
  static double hoursForMasteryLevel(int level) => 5 + (level - 1) * 2.5;

  static double cumulativeHoursToMasteryLevel(int level) {
    var total = 0.0;
    for (var l = 1; l < level; l++) {
      total += hoursForMasteryLevel(l);
    }
    return total;
  }
}

/// Distributes a season's credit budget across the ladder.
///
/// This is the mechanism that answers "what if the user's money does not match
/// their credits". The budget is not invented — it is
/// `expected income × fund %`, the euros that will genuinely reach the reserve
/// over the season. Spreading exactly that across the rungs means clearing the
/// whole pass pays out precisely what the user will have set aside.
///
/// Payouts escalate toward the end, so the late tiers are worth the climb.
class LadderPlan {
  LadderPlan._(this._payouts, this.budget, this.difficulty);

  final List<int> _payouts; // index 0 == tier 1
  final int budget;
  final Difficulty difficulty;

  int payoutFor(int tier) =>
      (tier < 1 || tier > _payouts.length) ? 0 : _payouts[tier - 1];

  int xpFor(int tier) => Economy.xpForTier(tier, difficulty);

  /// Total credits the ladder will ever pay. Equals [budget] up to rounding.
  int get totalPayout => _payouts.fold(0, (a, b) => a + b);

  factory LadderPlan.from({
    required Calibration calibration,
    required double fundPercent,
  }) {
    final budget = calibration.seasonCreditBudget(fundPercent);

    // Relative worth of each paying rung. Later rungs are worth more, so the
    // ladder gets better as it climbs rather than front-loading.
    double weightOf(int tier) {
      final ramp = 1 + tier / Economy.seasonTiers;
      return switch (Economy.rungKind(tier)) {
        RungKind.major => 12.0 * ramp,
        RungKind.real => 5.0 * ramp,
        RungKind.credits => 1.0 * ramp,
        RungKind.cosmetic => 0,
        RungKind.nothing => 0,
      };
    }

    var totalWeight = 0.0;
    for (var t = 1; t <= Economy.seasonTiers; t++) {
      totalWeight += weightOf(t);
    }

    final payouts = <int>[];
    for (var t = 1; t <= Economy.seasonTiers; t++) {
      final w = weightOf(t);
      if (w == 0 || totalWeight == 0) {
        payouts.add(0);
        continue;
      }
      final raw = budget * (w / totalWeight);
      // Round to something that reads as a deliberate figure rather than as
      // the output of a spreadsheet.
      payouts.add((raw / 10).round() * 10);
    }

    return LadderPlan._(payouts, budget, calibration.difficulty);
  }
}

/// Result of applying XP to a wallet.
class LevelUpResult {
  final int startLevel;
  final int endLevel;
  final int coinsAwarded;
  final int shardsAwarded;
  final int xpAwarded;

  /// Tiers crossed, in order, so the ceremony can name each one.
  final List<int> tiersCrossed;

  const LevelUpResult({
    required this.startLevel,
    required this.endLevel,
    required this.coinsAwarded,
    this.shardsAwarded = 0,
    required this.xpAwarded,
    required this.tiersCrossed,
  });

  bool get leveledUp => endLevel > startLevel;
}
