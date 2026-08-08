import 'appearance.dart';

/// How the eye behaves. Drives pupil size, blink rate, drift and glow — the
/// mood is the only thing the widget needs to know about the world.
enum CompanionMood {
  /// Nothing pressing. Slow blink, wandering gaze.
  idle,

  /// Something is being tracked. Steadier, fixed.
  watching,

  /// A timer is running down. Pupil narrows, pulse quickens.
  alert,

  /// A flat, cold acknowledgement of something done well.
  pleased,

  /// A goal has been ignored for a long time. Unblinking.
  ominous,
}

extension CompanionMoodInfo on CompanionMood {
  String get label => switch (this) {
        CompanionMood.idle => 'IDLE',
        CompanionMood.watching => 'WATCHING',
        CompanionMood.alert => 'ALERT',
        CompanionMood.pleased => 'SATISFIED',
        CompanionMood.ominous => 'DISAPPOINTED',
      };
}

/// Why the overseer is speaking. Used to pick a prompt and to decide how loudly
/// to surface the line.
enum MessageKind {
  greeting,
  nudge,
  levelUp,
  collect,
  streak,
  expiryWarning,
  suggestion,
  neglectedGoal,
  observation,
}

class CompanionMessage {
  final String id;
  final String text;
  final MessageKind kind;
  final CompanionMood mood;
  final DateTime createdAt;

  /// True when Gemini wrote it, false when it came from the local fallback bank.
  final bool fromModel;

  const CompanionMessage({
    required this.id,
    required this.text,
    required this.kind,
    required this.mood,
    required this.createdAt,
    this.fromModel = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'kind': kind.name,
        'mood': mood.name,
        'created_at': createdAt.toIso8601String(),
        'from_model': fromModel,
      };

  factory CompanionMessage.fromJson(Map<String, dynamic> json) => CompanionMessage(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        kind: MessageKind.values.byName(json['kind'] as String? ?? 'observation'),
        mood: CompanionMood.values.byName(json['mood'] as String? ?? 'idle'),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        fromModel: json['from_model'] as bool? ?? false,
      );
}

class CompanionState {
  final CompanionMood mood;
  final List<CompanionMessage> recent;

  /// Normalised screen position, so the overseer stays where it was dragged.
  ///
  /// Defaults sit it low and right, clear of the primary action on every
  /// screen — it floats over the interface, and a watcher that lands on the
  /// one button you need is just an obstacle.
  final double x;
  final double y;

  /// Shape, finish, paint and persona. Four independent axes, so the look is
  /// combinatorial rather than a fixed list of skins.
  final Appearance appearance;

  const CompanionState({
    this.mood = CompanionMood.idle,
    this.recent = const [],
    this.x = 0.84,
    this.y = 0.86,
    this.appearance = const Appearance(),
  });

  CompanionMessage? get latest => recent.isEmpty ? null : recent.first;

  CompanionState copyWith({
    CompanionMood? mood,
    List<CompanionMessage>? recent,
    double? x,
    double? y,
    Appearance? appearance,
  }) =>
      CompanionState(
        mood: mood ?? this.mood,
        recent: recent ?? this.recent,
        x: x ?? this.x,
        y: y ?? this.y,
        appearance: appearance ?? this.appearance,
      );

  /// Newest first, capped — the log is context for the model, not an archive.
  CompanionState withMessage(CompanionMessage m, {int cap = 20}) =>
      copyWith(mood: m.mood, recent: [m, ...recent].take(cap).toList());

  Map<String, dynamic> toJson() => {
        'mood': mood.name,
        'x': x,
        'y': y,
        'appearance': appearance.toJson(),
        'recent': recent.map((m) => m.toJson()).toList(),
      };

  factory CompanionState.fromJson(Map<String, dynamic> json) => CompanionState(
        mood: CompanionMood.values.byName(json['mood'] as String? ?? 'idle'),
        x: (json['x'] as num?)?.toDouble() ?? 0.84,
        y: (json['y'] as num?)?.toDouble() ?? 0.86,
        appearance: Appearance.fromJson(
            Map<String, dynamic>.from(json['appearance'] as Map? ?? {})),
        recent: ((json['recent'] as List?) ?? const [])
            .map((m) => CompanionMessage.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}
