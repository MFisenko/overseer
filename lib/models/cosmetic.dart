/// Free, earned wins. These cost nothing real and can only be achieved, never
/// bought — their job is to keep the loop satisfying on the many ordinary days
/// when no real purchase is anywhere in reach.
enum CosmeticType { title, avatar, badge, skin, companionSkin }

extension CosmeticTypeLabel on CosmeticType {
  String get label => switch (this) {
        CosmeticType.title => 'TITLE',
        CosmeticType.avatar => 'AVATAR',
        CosmeticType.badge => 'BADGE',
        CosmeticType.skin => 'SKIN',
        CosmeticType.companionSkin => 'OVERSEER',
      };

  /// Only one of each type can be worn at a time.
  String get slot => name;
}

/// What has to happen for a cosmetic to unlock. Evaluated against live state,
/// so nothing is ever granted by hand.
enum UnlockKind {
  /// Reach a battle-pass tier.
  tier,

  /// Keep a daily streak alive for N days.
  streak,

  /// Log N hours on any single mastery track.
  masteryHours,

  /// Reach a mastery level on any track.
  masteryLevel,

  /// Accumulate N lifetime XP.
  lifetimeXp,

  /// Collect N quests, ever.
  questsCollected,

  /// Claim N real-life rewards.
  rewardsClaimed,
}

class Cosmetic {
  final String id;
  final String name;
  final CosmeticType type;
  final UnlockKind unlockKind;
  final int unlockThreshold;

  /// Human-readable condition, shown while still locked.
  final String unlockDescription;

  final bool unlocked;
  final bool equipped;
  final DateTime? unlockedAt;

  /// Rendering hint — a glyph for badges/avatars, a palette key for skins.
  final String? glyph;

  const Cosmetic({
    required this.id,
    required this.name,
    required this.type,
    required this.unlockKind,
    required this.unlockThreshold,
    required this.unlockDescription,
    this.unlocked = false,
    this.equipped = false,
    this.unlockedAt,
    this.glyph,
  });

  Cosmetic copyWith({bool? unlocked, bool? equipped, DateTime? unlockedAt}) => Cosmetic(
        id: id,
        name: name,
        type: type,
        unlockKind: unlockKind,
        unlockThreshold: unlockThreshold,
        unlockDescription: unlockDescription,
        unlocked: unlocked ?? this.unlocked,
        equipped: equipped ?? this.equipped,
        unlockedAt: unlockedAt ?? this.unlockedAt,
        glyph: glyph,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'unlock_kind': unlockKind.name,
        'unlock_threshold': unlockThreshold,
        'unlock_description': unlockDescription,
        'unlocked': unlocked,
        'equipped': equipped,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'glyph': glyph,
      };

  factory Cosmetic.fromJson(Map<String, dynamic> json) => Cosmetic(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        type: CosmeticType.values.byName(json['type'] as String? ?? 'badge'),
        unlockKind: UnlockKind.values.byName(json['unlock_kind'] as String? ?? 'tier'),
        unlockThreshold: (json['unlock_threshold'] as num?)?.toInt() ?? 0,
        unlockDescription: json['unlock_description'] as String? ?? '',
        unlocked: json['unlocked'] as bool? ?? false,
        equipped: json['equipped'] as bool? ?? false,
        unlockedAt: json['unlocked_at'] == null
            ? null
            : DateTime.parse(json['unlocked_at'] as String).toLocal(),
        glyph: json['glyph'] as String?,
      );
}
