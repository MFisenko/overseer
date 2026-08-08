import '../core/economy.dart';

/// How often an obligation comes due.
enum ObligationCadence { weekly, monthly }

extension ObligationCadenceInfo on ObligationCadence {
  String get label => switch (this) {
        ObligationCadence.weekly => 'WEEKLY',
        ObligationCadence.monthly => 'MONTHLY',
      };

  double get days => switch (this) {
        ObligationCadence.weekly => Economy.weekDays,
        ObligationCadence.monthly => Economy.monthDays,
      };
}

/// A recurring cost of staying alive: rent, food, transport, subscriptions.
///
/// Obligations are the counterweight to the reward economy. Without them the
/// game only ever counts up, which is a lie — life bills you every day whether
/// or not you produced anything, and the overseer is not going to pretend
/// otherwise.
class Obligation {
  final String id;
  final String name;
  final double amountEuro;
  final ObligationCadence cadence;
  final bool active;
  final DateTime createdAt;

  const Obligation({
    required this.id,
    required this.name,
    required this.amountEuro,
    required this.cadence,
    this.active = true,
    required this.createdAt,
  });

  /// What this obligation costs per day, in euros.
  double get dailyEuro => amountEuro / cadence.days;

  /// The same, in credits.
  double get dailyCredits => dailyEuro * Economy.coinsPerEuro;

  int get creditCost => Economy.euroToCoins(amountEuro);

  Obligation copyWith({
    String? name,
    double? amountEuro,
    ObligationCadence? cadence,
    bool? active,
  }) =>
      Obligation(
        id: id,
        name: name ?? this.name,
        amountEuro: amountEuro ?? this.amountEuro,
        cadence: cadence ?? this.cadence,
        active: active ?? this.active,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount_euro': amountEuro,
        'cadence': cadence.name,
        'active': active,
        'created_at': createdAt.toIso8601String(),
      };

  factory Obligation.fromJson(Map<String, dynamic> json) => Obligation(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        amountEuro: (json['amount_euro'] as num?)?.toDouble() ?? 0,
        cadence: ObligationCadence.values.byName(json['cadence'] as String? ?? 'monthly'),
        active: json['active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

/// The running ledger that obligations draw down and income tops up.
///
/// Kept deliberately separate from both the credit balance and the rewards
/// reserve: credits are what you *earn*, the reserve is what you may *spend*,
/// and this is what you *owe* simply for existing.
class Upkeep {
  /// Balance in credits. Negative means arrears.
  final double balanceCredits;

  /// Daily levy on arrears, as a fraction. Default 0.005%.
  final double arrearsDailyRate;

  /// Share of each tier payout diverted to arrears while in the red.
  final double garnishRate;

  /// Last time the daily burn and levy were applied, so a cold start can
  /// settle up for every day that was missed.
  final DateTime? lastAccruedAt;

  /// Lifetime credits taken by the levy, for the settings readout.
  final double lifetimeLevyCredits;

  /// Lifetime credits diverted from payouts by the garnish.
  final double lifetimeGarnishedCredits;

  const Upkeep({
    this.balanceCredits = 0,
    this.arrearsDailyRate = Economy.defaultArrearsDailyRate,
    this.garnishRate = Economy.defaultGarnishRate,
    this.lastAccruedAt,
    this.lifetimeLevyCredits = 0,
    this.lifetimeGarnishedCredits = 0,
  });

  bool get inArrears => balanceCredits < 0;

  /// Positive magnitude of the debt, for display.
  double get arrearsCredits => inArrears ? -balanceCredits : 0;

  double get arrearsEuro => Economy.coinsToEuro(arrearsCredits.round());

  /// What today's levy will cost, given the current debt.
  double get todaysLevyCredits => arrearsCredits * arrearsDailyRate;

  Upkeep credit(double credits) =>
      copyWith(balanceCredits: balanceCredits + credits);

  Upkeep debit(double credits) =>
      copyWith(balanceCredits: balanceCredits - credits);

  Upkeep copyWith({
    double? balanceCredits,
    double? arrearsDailyRate,
    double? garnishRate,
    DateTime? lastAccruedAt,
    double? lifetimeLevyCredits,
    double? lifetimeGarnishedCredits,
  }) =>
      Upkeep(
        balanceCredits: balanceCredits ?? this.balanceCredits,
        arrearsDailyRate: arrearsDailyRate ?? this.arrearsDailyRate,
        garnishRate: garnishRate ?? this.garnishRate,
        lastAccruedAt: lastAccruedAt ?? this.lastAccruedAt,
        lifetimeLevyCredits: lifetimeLevyCredits ?? this.lifetimeLevyCredits,
        lifetimeGarnishedCredits:
            lifetimeGarnishedCredits ?? this.lifetimeGarnishedCredits,
      );

  Map<String, dynamic> toJson() => {
        'balance_credits': balanceCredits,
        'arrears_daily_rate': arrearsDailyRate,
        'garnish_rate': garnishRate,
        'last_accrued_at': lastAccruedAt?.toIso8601String(),
        'lifetime_levy_credits': lifetimeLevyCredits,
        'lifetime_garnished_credits': lifetimeGarnishedCredits,
      };

  factory Upkeep.fromJson(Map<String, dynamic> json) => Upkeep(
        balanceCredits: (json['balance_credits'] as num?)?.toDouble() ?? 0,
        arrearsDailyRate: (json['arrears_daily_rate'] as num?)?.toDouble() ??
            Economy.defaultArrearsDailyRate,
        garnishRate:
            (json['garnish_rate'] as num?)?.toDouble() ?? Economy.defaultGarnishRate,
        lastAccruedAt: json['last_accrued_at'] == null
            ? null
            : DateTime.parse(json['last_accrued_at'] as String).toLocal(),
        lifetimeLevyCredits: (json['lifetime_levy_credits'] as num?)?.toDouble() ?? 0,
        lifetimeGarnishedCredits:
            (json['lifetime_garnished_credits'] as num?)?.toDouble() ?? 0,
      );
}

/// Outcome of settling the ledger for one or more elapsed days. The UI reports
/// this so a burn is never silent — the user should see what was taken.
class AccrualResult {
  final int days;
  final double burnedCredits;
  final double levyCredits;
  final bool enteredArrears;

  const AccrualResult({
    this.days = 0,
    this.burnedCredits = 0,
    this.levyCredits = 0,
    this.enteredArrears = false,
  });

  bool get isEmpty => days == 0;
}
