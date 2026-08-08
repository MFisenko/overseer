import '../../core/economy.dart';
import '../../models/reward.dart';

/// What the model gives back for one wish, before it becomes a [Reward].
///
/// Kept as its own type so the parsing, the pricing and the persistence stay
/// separable — and so a draft can be shown to the user for confirmation before
/// anything is written.
class WishDraft {
  final String name;
  final String description;

  /// Category bucket. Created on demand; no taxonomy is hardcoded anywhere.
  final String bucket;

  /// Current real price in euros, as found by grounded search.
  final double priceEuro;

  /// What to search for when re-checking the price later. Long-term goals store
  /// this rather than a frozen number, so a three-year goal tracks what the
  /// thing actually costs today.
  final String searchTerm;

  final String? imageUrl;
  final String? sourceUrl;
  final RewardKind kind;

  /// True when the price is the model's rough guess rather than something it
  /// actually found. Surfaced in the UI so a guess is never passed off as fact.
  final bool priceIsEstimate;

  const WishDraft({
    required this.name,
    this.description = '',
    this.bucket = 'UNSORTED',
    this.priceEuro = 0,
    this.searchTerm = '',
    this.imageUrl,
    this.sourceUrl,
    this.kind = RewardKind.realWorld,
    this.priceIsEstimate = false,
  });

  MoneyTier get tier => MoneyTierInfo.fromEuro(priceEuro);
  int get coinCost => Economy.euroToCoins(priceEuro);

  WishDraft copyWith({
    String? name,
    String? description,
    String? bucket,
    double? priceEuro,
    String? searchTerm,
    String? imageUrl,
    String? sourceUrl,
    RewardKind? kind,
    bool? priceIsEstimate,
  }) =>
      WishDraft(
        name: name ?? this.name,
        description: description ?? this.description,
        bucket: bucket ?? this.bucket,
        priceEuro: priceEuro ?? this.priceEuro,
        searchTerm: searchTerm ?? this.searchTerm,
        imageUrl: imageUrl ?? this.imageUrl,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        kind: kind ?? this.kind,
        priceIsEstimate: priceIsEstimate ?? this.priceIsEstimate,
      );

  factory WishDraft.fromJson(Map<String, dynamic> json) => WishDraft(
        name: (json['name'] as String? ?? '').trim(),
        description: (json['description'] as String? ?? '').trim(),
        bucket: (json['bucket'] as String? ?? 'UNSORTED').trim().toUpperCase(),
        priceEuro: (json['price_eur'] as num?)?.toDouble() ?? 0,
        searchTerm: (json['search_term'] as String? ?? '').trim(),
        imageUrl: _url(json['image_url']),
        sourceUrl: _url(json['source_url']),
        kind: (json['is_in_app'] as bool? ?? false)
            ? RewardKind.inGame
            : RewardKind.realWorld,
        priceIsEstimate: json['price_is_estimate'] as bool? ?? false,
      );

  /// Models cheerfully return "N/A", "null" and bare domains for URL fields.
  /// Anything that is not a real absolute http(s) URL becomes null so the UI
  /// falls through to the generated plate instead of showing a broken image.
  static String? _url(Object? v) {
    if (v is! String) return null;
    final s = v.trim();
    if (s.isEmpty) return null;
    final uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return s;
  }
}
