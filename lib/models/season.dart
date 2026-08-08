import '../core/economy.dart';

/// A quarterly season resets every three months and its expiry is what creates
/// the pressure to come back. A lifetime pass never resets and holds the
/// ultimate goals, unlocked by cumulative milestones rather than simply bought.
enum PassType { quarterly, lifetime }

extension RungKindLabel on RungKind {
  String get label => switch (this) {
        RungKind.nothing => 'ADVANCEMENT',
        RungKind.credits => 'CREDITS',
        RungKind.cosmetic => 'UNLOCK',
        RungKind.real => 'REAL',
        RungKind.major => 'MAJOR',
      };

  /// Whether this rung carries an item from the manifest.
  bool get carriesReward => this == RungKind.real || this == RungKind.major;
}

/// One rung: the XP that gets you there, the credits it pays, and whatever is
/// pinned to it.
class PassTier {
  final int tier;

  /// Cumulative season XP required to be standing on this tier.
  final int xpThreshold;

  final int coinPayout;
  final RungKind kind;

  /// A real-world reward pinned to this rung, by id into the manifest.
  final String? rewardId;
  final String? rewardName;

  /// A cosmetic pinned to this rung.
  final String? cosmeticId;
  final String? cosmeticName;

  final bool collected;

  const PassTier({
    required this.tier,
    required this.xpThreshold,
    required this.coinPayout,
    this.kind = RungKind.credits,
    this.rewardId,
    this.rewardName,
    this.cosmeticId,
    this.cosmeticName,
    this.collected = false,
  });

  bool get isMilestone => tier % 5 == 0;
  bool get isMajor => tier % 25 == 0;

  /// Whether this rung has something named attached, or is credits alone.
  bool get hasNamedPrize => rewardName != null || cosmeticName != null;

  String get prizeName =>
      rewardName ?? cosmeticName ?? '${_group(coinPayout)} credits';

  static String _group(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  PassTier copyWith({
    bool? collected,
    String? rewardId,
    String? rewardName,
    String? cosmeticId,
    String? cosmeticName,
  }) =>
      PassTier(
        tier: tier,
        xpThreshold: xpThreshold,
        coinPayout: coinPayout,
        kind: kind,
        rewardId: rewardId ?? this.rewardId,
        rewardName: rewardName ?? this.rewardName,
        cosmeticId: cosmeticId ?? this.cosmeticId,
        cosmeticName: cosmeticName ?? this.cosmeticName,
        collected: collected ?? this.collected,
      );

  Map<String, dynamic> toJson() => {
        'tier': tier,
        'xp_threshold': xpThreshold,
        'coin_payout': coinPayout,
        'kind': kind.name,
        'reward_id': rewardId,
        'reward_name': rewardName,
        'cosmetic_id': cosmeticId,
        'cosmetic_name': cosmeticName,
        'collected': collected,
      };

  factory PassTier.fromJson(Map<String, dynamic> json) => PassTier(
        tier: (json['tier'] as num).toInt(),
        xpThreshold: (json['xp_threshold'] as num?)?.toInt() ?? 0,
        coinPayout: (json['coin_payout'] as num?)?.toInt() ?? 0,
        kind: RungKind.values.byName(json['kind'] as String? ?? 'credits'),
        rewardId: json['reward_id'] as String?,
        rewardName: json['reward_name'] as String?,
        cosmeticId: json['cosmetic_id'] as String?,
        cosmeticName: json['cosmetic_name'] as String?,
        collected: json['collected'] as bool? ?? false,
      );
}

class Season {
  final String id;
  final PassType type;
  final String name;
  final DateTime startsAt;

  /// Null for the lifetime pass, which never ends.
  final DateTime? endsAt;

  final List<PassTier> tiers;

  const Season({
    required this.id,
    required this.type,
    required this.name,
    required this.startsAt,
    this.endsAt,
    required this.tiers,
  });

  Duration? get timeLeft {
    if (endsAt == null) return null;
    final d = endsAt!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get hasExpired => endsAt != null && DateTime.now().isAfter(endsAt!);

  int get daysLeft => timeLeft?.inDays ?? -1;

  /// 0..1 through the season, for the countdown bar.
  double get elapsedFraction {
    if (endsAt == null) return 0;
    final total = endsAt!.difference(startsAt).inSeconds;
    if (total <= 0) return 1;
    final gone = DateTime.now().difference(startsAt).inSeconds;
    return (gone / total).clamp(0.0, 1.0);
  }

  PassTier? tierAt(int t) {
    if (t < 1 || t > tiers.length) return null;
    // Tiers are generated in order, so index arithmetic beats a linear scan —
    // this is called per row while scrolling a 150-row ladder.
    final candidate = tiers[t - 1];
    if (candidate.tier == t) return candidate;
    for (final tier in tiers) {
      if (tier.tier == t) return tier;
    }
    return null;
  }

  /// Rungs that hand over something from the real world, in ladder order.
  List<PassTier> get realWorldTiers =>
      tiers.where((t) => t.kind.carriesReward).toList();

  /// Total credits this ladder will ever pay. Should equal the season's
  /// reserve budget — that equality is the whole point of the calibration.
  int get totalPayout => tiers.fold(0, (a, t) => a + t.coinPayout);

  /// Builds the ladder for one season from a [LadderPlan].
  ///
  /// Both the XP costs and the payouts come from the plan, which derives them
  /// from the user's real income and chosen difficulty. Two people's ladders
  /// are therefore genuinely different — which is the point, and the thing a
  /// one-size-fits-all battle pass cannot do.
  factory Season.quarterly({
    required String id,
    required DateTime startsAt,
    required LadderPlan plan,
    String? name,
  }) {
    final tiers = <PassTier>[];
    var cumulative = 0;
    for (var t = 1; t <= Economy.seasonTiers; t++) {
      tiers.add(PassTier(
        tier: t,
        xpThreshold: cumulative,
        coinPayout: plan.payoutFor(t),
        kind: Economy.rungKind(t),
      ));
      cumulative += plan.xpFor(t);
    }
    final quarter = ((startsAt.month - 1) ~/ 3) + 1;
    return Season(
      id: id,
      type: PassType.quarterly,
      name: name ?? 'SEASON ${startsAt.year}.Q$quarter',
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(days: Economy.seasonDays)),
      tiers: tiers,
    );
  }

  Season copyWith({List<PassTier>? tiers, String? name, DateTime? endsAt}) => Season(
        id: id,
        type: type,
        name: name ?? this.name,
        startsAt: startsAt,
        endsAt: endsAt ?? this.endsAt,
        tiers: tiers ?? this.tiers,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'tiers': tiers.map((t) => t.toJson()).toList(),
      };

  factory Season.fromJson(Map<String, dynamic> json) => Season(
        id: json['id'] as String,
        type: PassType.values.byName(json['type'] as String? ?? 'quarterly'),
        name: json['name'] as String? ?? 'SEASON',
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: json['ends_at'] == null
            ? null
            : DateTime.parse(json['ends_at'] as String).toLocal(),
        tiers: ((json['tiers'] as List?) ?? const [])
            .map((t) => PassTier.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
      );
}
