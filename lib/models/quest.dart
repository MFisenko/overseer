/// How often a quest comes back, and therefore when it expires.
enum Cadence { once, daily, weekly, monthly, quarterly }

extension CadenceLabel on Cadence {
  String get label => switch (this) {
        Cadence.once => 'ONE-OFF',
        Cadence.daily => 'DAILY',
        Cadence.weekly => 'WEEKLY',
        Cadence.monthly => 'MONTHLY',
        Cadence.quarterly => 'SEASONAL',
      };

  String get short => switch (this) {
        Cadence.once => 'ONE',
        Cadence.daily => 'D',
        Cadence.weekly => 'W',
        Cadence.monthly => 'M',
        Cadence.quarterly => 'Q',
      };
}

/// Earning and claiming are two separate steps, copied straight from games:
/// a finished quest sits there until the user deliberately taps to collect it.
/// That tap is what makes claiming feel active, and the expiry is what makes it
/// urgent — an uncollected quest that runs out of time is simply gone.
enum QuestStatus { open, done, collected }

class Quest {
  final String id;
  final String title;
  final String? notes;

  /// Always granted on completion, without exception — this is the instant hit.
  final int xpValue;

  /// A deliberately small trickle, paid on *collect*, not on done. The bulk of
  /// a user's coins must come from crossing tiers, or the peg to real money
  /// stops meaning anything.
  final int coinValue;

  final Cadence cadence;

  /// Whether finishing this is expected to bring in real money, which prompts
  /// the log-income flow.
  final bool earnsIncome;

  /// Habit-style targets: "clean up three times" is target 3.
  final int targetCount;
  final int progressCount;

  final QuestStatus status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? collectedAt;

  /// Optional link to a mastery track, so finishing it can also log hours.
  final String? masteryTrackId;

  const Quest({
    required this.id,
    required this.title,
    this.notes,
    required this.xpValue,
    this.coinValue = 0,
    this.cadence = Cadence.once,
    this.earnsIncome = false,
    this.targetCount = 1,
    this.progressCount = 0,
    this.status = QuestStatus.open,
    this.expiresAt,
    required this.createdAt,
    this.completedAt,
    this.collectedAt,
    this.masteryTrackId,
  });

  bool get isComplete => progressCount >= targetCount;
  bool get isCollectable => status == QuestStatus.done;
  bool get isRepeating => targetCount > 1;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!) && status != QuestStatus.collected;

  Duration? get timeLeft {
    if (expiresAt == null) return null;
    final d = expiresAt!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  /// Under six hours a daily quest starts to bite; the companion escalates here.
  bool get isUrgent {
    final left = timeLeft;
    if (left == null || status == QuestStatus.collected) return false;
    return left.inHours < 6;
  }

  Quest copyWith({
    String? title,
    String? notes,
    int? xpValue,
    int? coinValue,
    Cadence? cadence,
    bool? earnsIncome,
    int? targetCount,
    int? progressCount,
    QuestStatus? status,
    DateTime? expiresAt,
    DateTime? completedAt,
    DateTime? collectedAt,
    String? masteryTrackId,
    bool clearExpiry = false,
  }) =>
      Quest(
        id: id,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        xpValue: xpValue ?? this.xpValue,
        coinValue: coinValue ?? this.coinValue,
        cadence: cadence ?? this.cadence,
        earnsIncome: earnsIncome ?? this.earnsIncome,
        targetCount: targetCount ?? this.targetCount,
        progressCount: progressCount ?? this.progressCount,
        status: status ?? this.status,
        expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
        collectedAt: collectedAt ?? this.collectedAt,
        masteryTrackId: masteryTrackId ?? this.masteryTrackId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'xp_value': xpValue,
        'coin_value': coinValue,
        'cadence': cadence.name,
        'earns_income': earnsIncome,
        'target_count': targetCount,
        'progress_count': progressCount,
        'status': status.name,
        'expires_at': expiresAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'collected_at': collectedAt?.toIso8601String(),
        'mastery_track_id': masteryTrackId,
      };

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        notes: json['notes'] as String?,
        xpValue: (json['xp_value'] as num?)?.toInt() ?? 0,
        coinValue: (json['coin_value'] as num?)?.toInt() ?? 0,
        cadence: Cadence.values.byName(json['cadence'] as String? ?? 'once'),
        earnsIncome: json['earns_income'] as bool? ?? false,
        targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
        progressCount: (json['progress_count'] as num?)?.toInt() ?? 0,
        status: QuestStatus.values.byName(json['status'] as String? ?? 'open'),
        expiresAt: _dt(json['expires_at']),
        createdAt: _dt(json['created_at']) ?? DateTime.now(),
        completedAt: _dt(json['completed_at']),
        collectedAt: _dt(json['collected_at']),
        masteryTrackId: json['mastery_track_id'] as String?,
      );

  static DateTime? _dt(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();
}
