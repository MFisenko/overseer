/// The user's profile, written entirely by their own behaviour.
///
/// Nothing in here is ever seeded by hand. A new account starts empty and the
/// profile emerges from what gets added, starred, claimed and dismissed. The
/// suggestion generator reads it on every run, so the list sharpens over time.
class TasteProfile {
  /// A system-prompt-style block the model both reads and rewrites. Machine
  /// written, human viewable, never human edited.
  final String profileText;

  /// Names of things the user claimed or starred — the "more like this" signal.
  final List<String> claimed;

  /// Names of things the user dismissed — the "never again" signal, which is
  /// the more useful of the two.
  final List<String> dismissed;

  final DateTime? lastGeneratedAt;
  final DateTime updatedAt;

  const TasteProfile({
    this.profileText = '',
    this.claimed = const [],
    this.dismissed = const [],
    this.lastGeneratedAt,
    required this.updatedAt,
  });

  bool get isEmpty => profileText.trim().isEmpty && claimed.isEmpty && dismissed.isEmpty;

  /// Enough signal to be worth asking the model for suggestions at all.
  bool get hasSignal => claimed.length + dismissed.length >= 3 || profileText.length > 40;

  TasteProfile copyWith({
    String? profileText,
    List<String>? claimed,
    List<String>? dismissed,
    DateTime? lastGeneratedAt,
    DateTime? updatedAt,
  }) =>
      TasteProfile(
        profileText: profileText ?? this.profileText,
        claimed: claimed ?? this.claimed,
        dismissed: dismissed ?? this.dismissed,
        lastGeneratedAt: lastGeneratedAt ?? this.lastGeneratedAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  /// Histories stay capped — they are prompt context, and an unbounded list
  /// would quietly bloat every call.
  TasteProfile withClaim(String name, {int cap = 60}) =>
      copyWith(claimed: [name, ...claimed.where((c) => c != name)].take(cap).toList());

  TasteProfile withDismissal(String name, {int cap = 60}) =>
      copyWith(dismissed: [name, ...dismissed.where((d) => d != name)].take(cap).toList());

  Map<String, dynamic> toJson() => {
        'profile_text': profileText,
        'claimed': claimed,
        'dismissed': dismissed,
        'last_generated_at': lastGeneratedAt?.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory TasteProfile.fromJson(Map<String, dynamic> json) => TasteProfile(
        profileText: json['profile_text'] as String? ?? '',
        claimed: (json['claimed'] as List?)?.cast<String>() ?? const [],
        dismissed: (json['dismissed'] as List?)?.cast<String>() ?? const [],
        lastGeneratedAt: json['last_generated_at'] == null
            ? null
            : DateTime.parse(json['last_generated_at'] as String).toLocal(),
        updatedAt: json['updated_at'] == null
            ? DateTime.now()
            : DateTime.parse(json['updated_at'] as String).toLocal(),
      );
}
