/// How hard the ladder is to climb.
///
/// Difficulty scales the **XP required per tier** and nothing else. It never
/// changes what a tier pays, because payouts are backed by real money — making
/// hell mode pay less would just be taking money off the user for choosing to
/// work harder. The knob is effort, not reward.
enum Difficulty { basic, challenging, extreme, hell }

extension DifficultyInfo on Difficulty {
  String get label => switch (this) {
        Difficulty.basic => 'BASIC',
        Difficulty.challenging => 'CHALLENGING',
        Difficulty.extreme => 'EXTREME',
        Difficulty.hell => 'HELL',
      };

  /// Multiplier on the XP each tier costs.
  double get xpMultiplier => switch (this) {
        Difficulty.basic => 1.0,
        Difficulty.challenging => 2.0,
        Difficulty.extreme => 3.5,
        Difficulty.hell => 6.0,
      };

  String get blurb => switch (this) {
        Difficulty.basic =>
          'The pass clears comfortably in a season. Best if you are rebuilding '
              'a habit from nothing.',
        Difficulty.challenging =>
          'A committed season reaches the high tiers. The default.',
        Difficulty.extreme =>
          'Most seasons end short of the top. Clearing it means something.',
        Difficulty.hell =>
          'Clearing this is close to a full-time commitment. You have been told.',
      };
}

/// Ties the game economy to the user's actual finances.
///
/// This is the answer to the problem that credits are minted by *effort* but
/// denominated in *money*. Without calibration the two drift apart: a person
/// who grinds a lot but earns little accrues credits their reserve can never
/// back, and the claim gate turns into a wall.
///
/// Instead, the season's entire credit issuance is derived from what the user
/// will realistically set aside over that season. Clearing the whole pass pays
/// out exactly what the reserve accumulates, so the two stay in lockstep by
/// construction rather than by coincidence.
class Calibration {
  /// What the user expects to earn in a month, before anything is set aside.
  /// Declared by hand until a statement measures it.
  final double expectedMonthlyIncomeEuro;

  /// Where the figure came from. A measured one is trusted over a declared one.
  final bool fromStatement;

  final Difficulty difficulty;

  /// Set once the user has told us anything at all. Until then the ladder runs
  /// on a conservative default and the app says so rather than pretending.
  final bool isCalibrated;

  final DateTime? calibratedAt;

  const Calibration({
    this.expectedMonthlyIncomeEuro = 0,
    this.fromStatement = false,
    this.difficulty = Difficulty.challenging,
    this.isCalibrated = false,
    this.calibratedAt,
  });

  /// Used before the user has declared anything. Deliberately modest: issuing
  /// too few credits is recoverable, issuing too many is a broken promise.
  static const fallbackMonthlyIncome = 800.0;

  double get monthlyIncome =>
      isCalibrated && expectedMonthlyIncomeEuro > 0
          ? expectedMonthlyIncomeEuro
          : fallbackMonthlyIncome;

  /// Euros expected to reach the reserve over one season.
  double seasonReserveEuro(double fundPercent) =>
      monthlyIncome * 3 * (fundPercent / 100);

  /// The entire credit budget for a season, at the standard peg.
  ///
  /// This is the number the whole ladder is distributed from.
  int seasonCreditBudget(double fundPercent) =>
      (seasonReserveEuro(fundPercent) * 100).round();

  Calibration copyWith({
    double? expectedMonthlyIncomeEuro,
    bool? fromStatement,
    Difficulty? difficulty,
    bool? isCalibrated,
    DateTime? calibratedAt,
  }) =>
      Calibration(
        expectedMonthlyIncomeEuro:
            expectedMonthlyIncomeEuro ?? this.expectedMonthlyIncomeEuro,
        fromStatement: fromStatement ?? this.fromStatement,
        difficulty: difficulty ?? this.difficulty,
        isCalibrated: isCalibrated ?? this.isCalibrated,
        calibratedAt: calibratedAt ?? this.calibratedAt,
      );

  Map<String, dynamic> toJson() => {
        'expected_monthly_income_eur': expectedMonthlyIncomeEuro,
        'from_statement': fromStatement,
        'difficulty': difficulty.name,
        'is_calibrated': isCalibrated,
        'calibrated_at': calibratedAt?.toIso8601String(),
      };

  factory Calibration.fromJson(Map<String, dynamic> json) => Calibration(
        expectedMonthlyIncomeEuro:
            (json['expected_monthly_income_eur'] as num?)?.toDouble() ?? 0,
        fromStatement: json['from_statement'] as bool? ?? false,
        difficulty:
            Difficulty.values.byName(json['difficulty'] as String? ?? 'challenging'),
        isCalibrated: json['is_calibrated'] as bool? ?? false,
        calibratedAt: json['calibrated_at'] == null
            ? null
            : DateTime.parse(json['calibrated_at'] as String).toLocal(),
      );
}

/// One income figure taken from a bank statement.
///
/// The seam for an Open Banking or Revolut integration sits exactly here: a
/// provider implementation produces these, and nothing downstream needs to know
/// whether a human typed it or an API returned it.
///
/// No banking credential is ever handled inside this app. A future integration
/// hands off to the provider's own consent flow and receives read-only figures
/// back — the app never sees a login.
class StatementEntry {
  final String id;

  /// Which month this covers, normalised to the first of the month.
  final DateTime month;

  final double incomeEuro;

  /// Total outgoings that month, when the source reports them. Used to sanity
  /// check the declared obligations against reality.
  final double? outgoingsEuro;

  /// 'manual' today; a provider id once an integration exists.
  final String source;

  final DateTime recordedAt;

  const StatementEntry({
    required this.id,
    required this.month,
    required this.incomeEuro,
    this.outgoingsEuro,
    this.source = 'manual',
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'month': month.toIso8601String(),
        'income_euro': incomeEuro,
        'outgoings_euro': outgoingsEuro,
        'source': source,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory StatementEntry.fromJson(Map<String, dynamic> json) => StatementEntry(
        id: json['id'] as String,
        month: DateTime.parse(json['month'] as String).toLocal(),
        incomeEuro: (json['income_euro'] as num?)?.toDouble() ?? 0,
        outgoingsEuro: (json['outgoings_euro'] as num?)?.toDouble(),
        source: json['source'] as String? ?? 'manual',
        recordedAt: DateTime.parse(json['recorded_at'] as String).toLocal(),
      );
}

/// Reads a set of statements back as a single expected monthly income.
///
/// Kept as a free function rather than a method so a future banking provider
/// can feed it entries without owning the averaging policy.
double averageMonthlyIncome(List<StatementEntry> entries, {int months = 6}) {
  if (entries.isEmpty) return 0;
  final sorted = [...entries]..sort((a, b) => b.month.compareTo(a.month));
  final window = sorted.take(months).toList();
  final total = window.fold(0.0, (sum, e) => sum + e.incomeEuro);
  return total / window.length;
}
