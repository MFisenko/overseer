import '../models/calibration.dart';
import '../models/companion.dart';
import '../models/cosmetic.dart';
import '../models/mastery.dart';
import '../models/profile.dart';
import '../models/quest.dart';
import '../models/reward.dart';
import '../core/economy.dart';
import '../models/season.dart';
import '../models/taste.dart';
import '../models/upkeep.dart';
import '../models/wallet.dart';

/// Everything one user owns, in one object.
///
/// A single account's data is small — a few hundred rows at most, even after
/// years — so the app loads it whole and keeps it in memory. That keeps the
/// repository interface narrow and the UI free of loading spinners, which
/// matters more here than it would in a product with unbounded data.
class GameSnapshot {
  final Profile profile;
  final Wallet wallet;
  final Fund fund;
  final Upkeep upkeep;

  /// Ties the whole economy to the user's real income. See [LadderPlan].
  final Calibration calibration;

  final CompanionState companion;
  final TasteProfile taste;

  final List<Quest> quests;
  final List<Reward> rewards;
  final List<Bucket> buckets;
  final List<Obligation> obligations;
  final List<MasteryTrack> tracks;
  final List<HourLog> hourLogs;
  final List<Cosmetic> cosmetics;
  final List<IncomeEntry> income;
  final List<StatementEntry> statements;

  final Season season;
  final Season lifetime;

  const GameSnapshot({
    required this.profile,
    required this.wallet,
    required this.fund,
    required this.upkeep,
    required this.calibration,
    required this.companion,
    required this.taste,
    required this.quests,
    required this.rewards,
    required this.buckets,
    required this.obligations,
    required this.tracks,
    required this.hourLogs,
    required this.cosmetics,
    required this.income,
    required this.statements,
    required this.season,
    required this.lifetime,
  });

  /// A brand-new account. Deliberately close to empty: the profile is supposed
  /// to emerge from use, not be assumed. The only things seeded are the season
  /// ladder, the lifetime pass and the cosmetic catalogue, none of which
  /// presume anything about who the user is.
  factory GameSnapshot.fresh({DateTime? now, List<Cosmetic> cosmetics = const []}) {
    final n = now ?? DateTime.now();
    return GameSnapshot(
      profile: Profile(createdAt: n),
      wallet: const Wallet(),
      fund: const Fund(),
      upkeep: Upkeep(lastAccruedAt: n),
      calibration: const Calibration(),
      companion: const CompanionState(),
      taste: TasteProfile(updatedAt: n),
      quests: const [],
      rewards: const [],
      buckets: const [],
      obligations: const [],
      tracks: const [],
      hourLogs: const [],
      cosmetics: cosmetics,
      income: const [],
      statements: const [],
      season: Season.quarterly(
        id: 'season-current',
        startsAt: _quarterStart(n),
        plan: LadderPlan.from(
          calibration: const Calibration(),
          fundPercent: Economy.defaultFundPercent,
        ),
      ),
      lifetime: Season(
        id: 'lifetime',
        type: PassType.lifetime,
        name: 'LIFETIME',
        startsAt: n,
        tiers: const [],
      ),
    );
  }

  static DateTime _quarterStart(DateTime n) {
    final month = ((n.month - 1) ~/ 3) * 3 + 1;
    return DateTime(n.year, month, 1);
  }

  GameSnapshot copyWith({
    Profile? profile,
    Wallet? wallet,
    Fund? fund,
    Upkeep? upkeep,
    Calibration? calibration,
    CompanionState? companion,
    TasteProfile? taste,
    List<Quest>? quests,
    List<Reward>? rewards,
    List<Bucket>? buckets,
    List<Obligation>? obligations,
    List<MasteryTrack>? tracks,
    List<HourLog>? hourLogs,
    List<Cosmetic>? cosmetics,
    List<IncomeEntry>? income,
    List<StatementEntry>? statements,
    Season? season,
    Season? lifetime,
  }) =>
      GameSnapshot(
        profile: profile ?? this.profile,
        wallet: wallet ?? this.wallet,
        fund: fund ?? this.fund,
        upkeep: upkeep ?? this.upkeep,
        calibration: calibration ?? this.calibration,
        companion: companion ?? this.companion,
        taste: taste ?? this.taste,
        quests: quests ?? this.quests,
        rewards: rewards ?? this.rewards,
        buckets: buckets ?? this.buckets,
        obligations: obligations ?? this.obligations,
        tracks: tracks ?? this.tracks,
        hourLogs: hourLogs ?? this.hourLogs,
        cosmetics: cosmetics ?? this.cosmetics,
        income: income ?? this.income,
        statements: statements ?? this.statements,
        season: season ?? this.season,
        lifetime: lifetime ?? this.lifetime,
      );

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'wallet': wallet.toJson(),
        'fund': fund.toJson(),
        'upkeep': upkeep.toJson(),
        'calibration': calibration.toJson(),
        'companion': companion.toJson(),
        'taste': taste.toJson(),
        'quests': quests.map((q) => q.toJson()).toList(),
        'rewards': rewards.map((r) => r.toJson()).toList(),
        'buckets': buckets.map((b) => b.toJson()).toList(),
        'obligations': obligations.map((o) => o.toJson()).toList(),
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'hour_logs': hourLogs.map((h) => h.toJson()).toList(),
        'cosmetics': cosmetics.map((c) => c.toJson()).toList(),
        'income': income.map((i) => i.toJson()).toList(),
        'statements': statements.map((e) => e.toJson()).toList(),
        'season': season.toJson(),
        'lifetime': lifetime.toJson(),
      };

  factory GameSnapshot.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        ((json[key] as List?) ?? const [])
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList();

    final now = DateTime.now();
    return GameSnapshot(
      profile: Profile.fromJson(Map<String, dynamic>.from(json['profile'] as Map? ?? {})),
      wallet: Wallet.fromJson(Map<String, dynamic>.from(json['wallet'] as Map? ?? {})),
      fund: Fund.fromJson(Map<String, dynamic>.from(json['fund'] as Map? ?? {})),
      upkeep: Upkeep.fromJson(Map<String, dynamic>.from(json['upkeep'] as Map? ?? {})),
      calibration: Calibration.fromJson(
          Map<String, dynamic>.from(json['calibration'] as Map? ?? {})),
      companion:
          CompanionState.fromJson(Map<String, dynamic>.from(json['companion'] as Map? ?? {})),
      taste: TasteProfile.fromJson(Map<String, dynamic>.from(json['taste'] as Map? ?? {})),
      quests: list('quests', Quest.fromJson),
      rewards: list('rewards', Reward.fromJson),
      buckets: list('buckets', Bucket.fromJson),
      obligations: list('obligations', Obligation.fromJson),
      tracks: list('tracks', MasteryTrack.fromJson),
      hourLogs: list('hour_logs', HourLog.fromJson),
      cosmetics: list('cosmetics', Cosmetic.fromJson),
      income: list('income', IncomeEntry.fromJson),
      statements: list('statements', StatementEntry.fromJson),
      season: json['season'] == null
          ? Season.quarterly(
              id: 'season-current',
              startsAt: _quarterStart(now),
              plan: LadderPlan.from(
                calibration: const Calibration(),
                fundPercent: Economy.defaultFundPercent,
              ))
          : Season.fromJson(Map<String, dynamic>.from(json['season'] as Map)),
      lifetime: json['lifetime'] == null
          ? Season(
              id: 'lifetime',
              type: PassType.lifetime,
              name: 'LIFETIME',
              startsAt: now,
              tiers: const [])
          : Season.fromJson(Map<String, dynamic>.from(json['lifetime'] as Map)),
    );
  }
}
