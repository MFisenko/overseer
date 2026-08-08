import '../core/economy.dart';
import '../core/emblem.dart';

/// Where a wish sits on the money ladder. The entire bucket list is sorted by
/// cost on purpose: the user should always be able to see what a day's effort
/// buys against what a year's effort buys.
enum MoneyTier { small, mid, ultimate }

extension MoneyTierInfo on MoneyTier {
  String get label => switch (this) {
        MoneyTier.small => 'SMALL',
        MoneyTier.mid => 'MID',
        MoneyTier.ultimate => 'ULTIMATE',
      };

  static MoneyTier fromEuro(double euro) {
    if (euro <= Economy.smallTierMaxEuro) return MoneyTier.small;
    if (euro <= Economy.midTierMaxEuro) return MoneyTier.mid;
    return MoneyTier.ultimate;
  }
}

/// `locked` is a long-term goal the user deliberately committed to: its price
/// and details stop being editable, which is a motivated past-self protecting
/// itself from a lazy future-self.
///
/// `available` is an ordinary wish. `claimed` means the coins have been burned
/// and it is theirs to go and get. `bought` means they actually went and got it
/// and the euros left the fund.
enum RewardStatus { locked, available, claimed, bought }

/// Manual entries and the ones the overseer surfaces on its own are kept apart
/// so taste learning can tell which of its own suggestions actually landed.
enum RewardOrigin { manual, ai }

/// Real things cost real money and are gated by the reserve. In-app things cost
/// credits alone and are pure achievement. Both live in the same store, because
/// a steady drip of free wins is what carries the ordinary days between
/// purchases.
enum RewardKind { realWorld, inGame }

extension RewardKindLabel on RewardKind {
  String get label => switch (this) {
        RewardKind.realWorld => 'REAL WORLD',
        RewardKind.inGame => 'IN APP',
      };
}

class Reward {
  final String id;
  final String name;
  final String? description;

  /// Category bucket — travel, gear, music, home, whatever emerges. Buckets are
  /// created as needed; none are hardcoded.
  final String bucketId;
  final String bucketName;

  final MoneyTier tier;

  /// Real current price in euros, as estimated by grounded search.
  final double priceEuro;

  /// Always [priceEuro] × 100. Stored rather than derived so a re-price can be
  /// shown as a delta against what it used to cost.
  final int coinCost;

  /// What to search for when re-checking the price later. Big long-term goals
  /// store this rather than a frozen number, so a three-year goal tracks what
  /// the thing actually costs today instead of a stale figure.
  final String? searchTerm;

  final String? imageQuery;
  final String? sourceUrl;

  /// The resolved hero image. A real product photo found by grounded search
  /// where one exists, otherwise a generated editorial still. Either way the
  /// detail page frames it identically, so a mixed manifest still reads as one
  /// magazine.
  final String? imageUrl;

  final RewardKind kind;
  final RewardOrigin origin;
  final RewardStatus status;

  /// A user's explicit "yes, more like this" — the strongest taste signal there is.
  final bool starred;

  /// Share of every reserve deposit diverted into this goal's own pot, 0–100.
  ///
  /// Without this a ten-year goal never moves: any small purchase drains the
  /// shared reserve and the long climb restarts. An earmark gives the goal a
  /// pot nothing else can spend.
  final double earmarkPercent;

  /// Euros put by specifically for this goal.
  final double savedEuro;

  final DateTime createdAt;
  final DateTime? claimedAt;
  final DateTime? boughtAt;
  final DateTime? priceCheckedAt;

  /// What it cost the last time the price was checked, for the delta readout.
  final double? previousPriceEuro;

  const Reward({
    required this.id,
    required this.name,
    this.description,
    required this.bucketId,
    required this.bucketName,
    required this.tier,
    required this.priceEuro,
    required this.coinCost,
    this.searchTerm,
    this.imageQuery,
    this.sourceUrl,
    this.imageUrl,
    this.kind = RewardKind.realWorld,
    this.origin = RewardOrigin.manual,
    this.status = RewardStatus.available,
    this.starred = false,
    this.earmarkPercent = 0,
    this.savedEuro = 0,
    required this.createdAt,
    this.claimedAt,
    this.boughtAt,
    this.priceCheckedAt,
    this.previousPriceEuro,
  });

  /// Locked goals stay locked. No editing, no re-pricing downward by hand,
  /// no quietly making the mountain smaller on a bad day.
  bool get isEditable => status != RewardStatus.locked;

  bool get isOwned => status == RewardStatus.claimed || status == RewardStatus.bought;

  double? get priceDelta =>
      previousPriceEuro == null ? null : priceEuro - previousPriceEuro!;

  bool get isEarmarked => earmarkPercent > 0;

  /// Euros still outstanding after whatever is already put by.
  double get outstandingEuro =>
      (priceEuro - savedEuro).clamp(0.0, double.infinity);

  /// 0..1 of the goal's own pot against its price.
  double get savedProgress =>
      priceEuro <= 0 ? 1 : (savedEuro / priceEuro).clamp(0.0, 1.0);

  /// Which insignia this wears in the store and on the ladder. Rank is legible
  /// before a single word is read.
  Emblem get emblem {
    if (status == RewardStatus.locked) return Emblem.sealed_;
    if (kind == RewardKind.inGame) return Emblem.cipher;
    return switch (tier) {
      MoneyTier.small => Emblem.mark,
      MoneyTier.mid => Emblem.crest,
      MoneyTier.ultimate => Emblem.apex,
    };
  }

  Reward copyWith({
    String? name,
    String? description,
    String? bucketId,
    String? bucketName,
    MoneyTier? tier,
    double? priceEuro,
    int? coinCost,
    String? searchTerm,
    String? imageQuery,
    String? sourceUrl,
    String? imageUrl,
    RewardKind? kind,
    RewardOrigin? origin,
    RewardStatus? status,
    bool? starred,
    double? earmarkPercent,
    double? savedEuro,
    DateTime? claimedAt,
    DateTime? boughtAt,
    DateTime? priceCheckedAt,
    double? previousPriceEuro,
  }) =>
      Reward(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        bucketId: bucketId ?? this.bucketId,
        bucketName: bucketName ?? this.bucketName,
        tier: tier ?? this.tier,
        priceEuro: priceEuro ?? this.priceEuro,
        coinCost: coinCost ?? this.coinCost,
        searchTerm: searchTerm ?? this.searchTerm,
        imageQuery: imageQuery ?? this.imageQuery,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        imageUrl: imageUrl ?? this.imageUrl,
        kind: kind ?? this.kind,
        origin: origin ?? this.origin,
        status: status ?? this.status,
        starred: starred ?? this.starred,
        earmarkPercent: earmarkPercent ?? this.earmarkPercent,
        savedEuro: savedEuro ?? this.savedEuro,
        createdAt: createdAt,
        claimedAt: claimedAt ?? this.claimedAt,
        boughtAt: boughtAt ?? this.boughtAt,
        priceCheckedAt: priceCheckedAt ?? this.priceCheckedAt,
        previousPriceEuro: previousPriceEuro ?? this.previousPriceEuro,
      );

  /// Re-derives the coin cost from a freshly-searched real price. This is what
  /// keeps the economy honest against inflation over a multi-year goal.
  Reward reprice(double newPriceEuro) => copyWith(
        previousPriceEuro: priceEuro,
        priceEuro: newPriceEuro,
        coinCost: Economy.euroToCoins(newPriceEuro),
        tier: MoneyTierInfo.fromEuro(newPriceEuro),
        priceCheckedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'bucket_id': bucketId,
        'bucket_name': bucketName,
        'tier': tier.name,
        'price_euro': priceEuro,
        'coin_cost': coinCost,
        'search_term': searchTerm,
        'image_query': imageQuery,
        'source_url': sourceUrl,
        'image_url': imageUrl,
        'kind': kind.name,
        'origin': origin.name,
        'status': status.name,
        'starred': starred,
        'earmark_percent': earmarkPercent,
        'saved_euro': savedEuro,
        'created_at': createdAt.toIso8601String(),
        'claimed_at': claimedAt?.toIso8601String(),
        'bought_at': boughtAt?.toIso8601String(),
        'price_checked_at': priceCheckedAt?.toIso8601String(),
        'previous_price_euro': previousPriceEuro,
      };

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        bucketId: json['bucket_id'] as String? ?? '',
        bucketName: json['bucket_name'] as String? ?? 'UNSORTED',
        tier: MoneyTier.values.byName(json['tier'] as String? ?? 'small'),
        priceEuro: (json['price_euro'] as num?)?.toDouble() ?? 0,
        coinCost: (json['coin_cost'] as num?)?.toInt() ?? 0,
        searchTerm: json['search_term'] as String?,
        imageQuery: json['image_query'] as String?,
        sourceUrl: json['source_url'] as String?,
        imageUrl: json['image_url'] as String?,
        kind: RewardKind.values.byName(json['kind'] as String? ?? 'realWorld'),
        origin: RewardOrigin.values.byName(json['origin'] as String? ?? 'manual'),
        status: RewardStatus.values.byName(json['status'] as String? ?? 'available'),
        starred: json['starred'] as bool? ?? false,
        earmarkPercent: (json['earmark_percent'] as num?)?.toDouble() ?? 0,
        savedEuro: (json['saved_euro'] as num?)?.toDouble() ?? 0,
        createdAt: _dt(json['created_at']) ?? DateTime.now(),
        claimedAt: _dt(json['claimed_at']),
        boughtAt: _dt(json['bought_at']),
        priceCheckedAt: _dt(json['price_checked_at']),
        previousPriceEuro: (json['previous_price_euro'] as num?)?.toDouble(),
      );

  static DateTime? _dt(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();
}

/// A category the wishlist sorts itself into. Created on demand by the model —
/// never a fixed list, because the taxonomy has to fit the person.
class Bucket {
  final String id;
  final String name;
  final String? notes;
  final DateTime createdAt;

  const Bucket({
    required this.id,
    required this.name,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Bucket.fromJson(Map<String, dynamic> json) => Bucket(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
