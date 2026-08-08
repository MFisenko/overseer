import '../core/economy.dart';

/// Not every kind of progress should be measured in money.
///
/// A mastery track fills purely from time invested — never from euros — so a
/// user can watch themselves visibly get better at something that pays nothing
/// at all. Users define their own tracks; no hobby is hardcoded anywhere.
class MasteryTrack {
  final String id;

  /// Whatever the user named it: DJing, guitar, writing, training, anything.
  final String name;

  final double totalHours;
  final int level;

  /// Titles this track has handed over, in unlock order.
  final List<String> titles;

  final DateTime createdAt;
  final DateTime? lastLoggedAt;

  const MasteryTrack({
    required this.id,
    required this.name,
    this.totalHours = 0,
    this.level = 1,
    this.titles = const [],
    required this.createdAt,
    this.lastLoggedAt,
  });

  double get hoursForNextLevel => Economy.hoursForMasteryLevel(level);

  double get hoursIntoLevel =>
      totalHours - Economy.cumulativeHoursToMasteryLevel(level);

  double get progress => hoursForNextLevel == 0
      ? 0
      : (hoursIntoLevel / hoursForNextLevel).clamp(0.0, 1.0);

  double get hoursRemaining =>
      (hoursForNextLevel - hoursIntoLevel).clamp(0, double.infinity);

  /// Adds hours and rolls the level as far as they carry. Returns the new track
  /// and how many levels were crossed, so the UI can mark the milestone.
  (MasteryTrack, int) logHours(double hours) {
    if (hours <= 0) return (this, 0);
    final newTotal = totalHours + hours;
    var newLevel = level;
    while (newTotal >=
        Economy.cumulativeHoursToMasteryLevel(newLevel) +
            Economy.hoursForMasteryLevel(newLevel)) {
      newLevel += 1;
    }
    return (
      copyWith(
        totalHours: newTotal,
        level: newLevel,
        lastLoggedAt: DateTime.now(),
      ),
      newLevel - level,
    );
  }

  MasteryTrack copyWith({
    String? name,
    double? totalHours,
    int? level,
    List<String>? titles,
    DateTime? lastLoggedAt,
  }) =>
      MasteryTrack(
        id: id,
        name: name ?? this.name,
        totalHours: totalHours ?? this.totalHours,
        level: level ?? this.level,
        titles: titles ?? this.titles,
        createdAt: createdAt,
        lastLoggedAt: lastLoggedAt ?? this.lastLoggedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'total_hours': totalHours,
        'level': level,
        'titles': titles,
        'created_at': createdAt.toIso8601String(),
        'last_logged_at': lastLoggedAt?.toIso8601String(),
      };

  factory MasteryTrack.fromJson(Map<String, dynamic> json) => MasteryTrack(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 1,
        titles: (json['titles'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        lastLoggedAt: json['last_logged_at'] == null
            ? null
            : DateTime.parse(json['last_logged_at'] as String).toLocal(),
      );
}

/// One logged practice session against a track.
class HourLog {
  final String id;
  final String trackId;
  final double hours;
  final String? note;
  final DateTime loggedAt;

  const HourLog({
    required this.id,
    required this.trackId,
    required this.hours,
    this.note,
    required this.loggedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'track_id': trackId,
        'hours': hours,
        'note': note,
        'logged_at': loggedAt.toIso8601String(),
      };

  factory HourLog.fromJson(Map<String, dynamic> json) => HourLog(
        id: json['id'] as String,
        trackId: json['track_id'] as String,
        hours: (json['hours'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String?,
        loggedAt: DateTime.parse(json['logged_at'] as String).toLocal(),
      );
}
