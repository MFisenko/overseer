/// Per-user counters that cosmetics unlock against and the companion reads for
/// context. Everything here is derived from real activity — nothing is granted.
class Profile {
  final String displayName;

  /// Consecutive days with at least one collected directive.
  final int streak;
  final int bestStreak;

  /// Local date (midnight) of the last day the user did anything at all.
  final DateTime? lastActiveDay;

  final int questsCollected;
  final int rewardsClaimed;

  /// Equipped cosmetic ids by slot name — see [CosmeticType.slot].
  final Map<String, String> equipped;

  /// Appearance unlocks this account owns, by [Unlockable] id.
  ///
  /// Free options are not stored — they are implied by the catalogue, so a new
  /// free item added later is immediately available to everyone rather than
  /// only to accounts created afterwards.
  final Set<String> ownedUnlocks;

  /// 'system', 'light' or 'dark'. Both modes are first-class; neither is a
  /// tinted afterthought of the other.
  final String themeMode;

  final DateTime createdAt;

  const Profile({
    this.displayName = 'SUBJECT',
    this.streak = 0,
    this.bestStreak = 0,
    this.lastActiveDay,
    this.questsCollected = 0,
    this.rewardsClaimed = 0,
    this.equipped = const {},
    this.ownedUnlocks = const {},
    this.themeMode = 'system',
    required this.createdAt,
  });

  String? equippedIn(String slot) => equipped[slot];

  /// Rolls the streak forward for activity happening [now].
  ///
  /// Same day: unchanged. Next day: +1. Any longer gap: the streak is broken
  /// and restarts at 1, which the companion will have something to say about.
  (Profile, bool broken) touch(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (lastActiveDay == null) {
      return (copyWith(streak: 1, bestStreak: bestStreak < 1 ? 1 : bestStreak, lastActiveDay: today), false);
    }
    final last = lastActiveDay!;
    final gap = today.difference(last).inDays;
    if (gap == 0) return (this, false);
    final next = gap == 1 ? streak + 1 : 1;
    return (
      copyWith(
        streak: next,
        bestStreak: next > bestStreak ? next : bestStreak,
        lastActiveDay: today,
      ),
      gap > 1 && streak > 1
    );
  }

  /// A streak that has already lapsed but has not been recomputed yet — the
  /// dashboard shows 0 rather than a stale number.
  int streakAsOf(DateTime now) {
    if (lastActiveDay == null) return 0;
    final today = DateTime(now.year, now.month, now.day);
    final gap = today.difference(lastActiveDay!).inDays;
    return gap <= 1 ? streak : 0;
  }

  Profile copyWith({
    String? displayName,
    int? streak,
    int? bestStreak,
    DateTime? lastActiveDay,
    int? questsCollected,
    int? rewardsClaimed,
    Map<String, String>? equipped,
    Set<String>? ownedUnlocks,
    String? themeMode,
  }) =>
      Profile(
        displayName: displayName ?? this.displayName,
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        lastActiveDay: lastActiveDay ?? this.lastActiveDay,
        questsCollected: questsCollected ?? this.questsCollected,
        rewardsClaimed: rewardsClaimed ?? this.rewardsClaimed,
        equipped: equipped ?? this.equipped,
        ownedUnlocks: ownedUnlocks ?? this.ownedUnlocks,
        themeMode: themeMode ?? this.themeMode,
        createdAt: createdAt,
      );

  Profile equip(String slot, String? id) {
    final next = Map<String, String>.from(equipped);
    if (id == null) {
      next.remove(slot);
    } else {
      next[slot] = id;
    }
    return copyWith(equipped: next);
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'streak': streak,
        'best_streak': bestStreak,
        'last_active_day': lastActiveDay?.toIso8601String(),
        'quests_collected': questsCollected,
        'rewards_claimed': rewardsClaimed,
        'equipped': equipped,
        'owned_unlocks': ownedUnlocks.toList(),
        'theme_mode': themeMode,
        'created_at': createdAt.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        displayName: json['display_name'] as String? ?? 'SUBJECT',
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        bestStreak: (json['best_streak'] as num?)?.toInt() ?? 0,
        lastActiveDay: json['last_active_day'] == null
            ? null
            : DateTime.parse(json['last_active_day'] as String).toLocal(),
        questsCollected: (json['quests_collected'] as num?)?.toInt() ?? 0,
        rewardsClaimed: (json['rewards_claimed'] as num?)?.toInt() ?? 0,
        equipped: Map<String, String>.from(json['equipped'] as Map? ?? const {}),
        ownedUnlocks:
            ((json['owned_unlocks'] as List?) ?? const []).cast<String>().toSet(),
        themeMode: json['theme_mode'] as String? ?? 'system',
        createdAt: json['created_at'] == null
            ? DateTime.now()
            : DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
