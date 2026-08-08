/// How far away a goal is, in the only unit that matters: time at the user's
/// actual rate of saving.
///
/// A seasonal pass runs thirteen weeks. A car or a deposit does not fit inside
/// one, and pretending otherwise produces a ladder whose top rung is a fantasy.
/// Banding by horizon lets the near things drive the pass while the far things
/// stay visible, tracked, and honestly dated.
enum Horizon {
  /// The reserve already covers it.
  inReach,

  /// Reachable inside the current season. These are what the ladder pins.
  thisSeason,

  /// Within a year. Queued for a future season's ladder.
  onDeck,

  /// One to ten years. Lives in the vault with its own pot and a projected date.
  longRange,

  /// Beyond ten years at the current rate. Still kept, still shown — but the
  /// app says plainly what it would take rather than quietly implying it is
  /// coming.
  beyondHorizon,
}

extension HorizonInfo on Horizon {
  String get label => switch (this) {
        Horizon.inReach => 'IN REACH',
        Horizon.thisSeason => 'THIS SEASON',
        Horizon.onDeck => 'ON DECK',
        Horizon.longRange => 'LONG RANGE',
        Horizon.beyondHorizon => 'BEYOND HORIZON',
      };

  /// Whether the seasonal ladder is allowed to pin this. Long goals are
  /// deliberately excluded: a rung that cannot be reached inside the season is
  /// worse than an empty one.
  bool get eligibleForSeason =>
      this == Horizon.inReach || this == Horizon.thisSeason;

  /// Whether it belongs in the vault rather than the ordinary store shelf.
  bool get isLongRange =>
      this == Horizon.longRange || this == Horizon.beyondHorizon;
}

/// The furthest out the app will plan. Past this a goal is not a plan, it is a
/// wish, and the interface says so.
const horizonYears = 10.0;

/// Bands a price against the rate money actually reaches the reserve.
///
/// [annualReserveEuro] is the whole reserve inflow for a year — the yardstick
/// is "if every euro set aside went to this one thing", which keeps the bands
/// stable regardless of how many goals are competing.
Horizon bandFor({
  required double priceEuro,
  required double annualReserveEuro,
  required double alreadySavedEuro,
  required bool covered,
}) {
  if (covered) return Horizon.inReach;

  final outstanding = (priceEuro - alreadySavedEuro).clamp(0.0, double.infinity);
  if (outstanding <= 0) return Horizon.inReach;

  // With no income declared, everything that is not already covered is beyond
  // planning. Saying so is more useful than dividing by zero.
  if (annualReserveEuro <= 0) return Horizon.beyondHorizon;

  final years = outstanding / annualReserveEuro;
  if (years <= 0.25) return Horizon.thisSeason;
  if (years <= 1.0) return Horizon.onDeck;
  if (years <= horizonYears) return Horizon.longRange;
  return Horizon.beyondHorizon;
}

/// Years until a goal is funded, given what is already put by for it and the
/// rate its earmark accumulates. Returns null when it will never arrive at the
/// current rate.
double? yearsRemaining({
  required double priceEuro,
  required double alreadySavedEuro,
  required double annualRateEuro,
}) {
  final outstanding = (priceEuro - alreadySavedEuro).clamp(0.0, double.infinity);
  if (outstanding <= 0) return 0;
  if (annualRateEuro <= 0) return null;
  return outstanding / annualRateEuro;
}

/// The monthly income that would pull a goal inside [targetYears].
///
/// This is the number that makes a distant goal actionable instead of
/// discouraging: not "seventeen years", but "seventeen years at what you earn
/// now, eight at €3,500".
double incomeNeededFor({
  required double priceEuro,
  required double alreadySavedEuro,
  required double fundPercent,
  required double earmarkPercent,
  double targetYears = 5,
}) {
  final outstanding = (priceEuro - alreadySavedEuro).clamp(0.0, double.infinity);
  final share = (fundPercent / 100) * (earmarkPercent / 100);
  if (share <= 0 || targetYears <= 0) return double.infinity;
  return outstanding / (targetYears * 12 * share);
}
