import '../core/economy.dart';
import '../models/quest.dart';
import '../models/upkeep.dart';

/// What a single braindumped line turned out to be.
enum DumpKind {
  /// Something to do once.
  task,

  /// Something to do repeatedly — becomes a recurring directive.
  habit,

  /// Something wanted — goes to the manifest to be priced.
  wish,

  /// A recurring cost of being alive.
  obligation,

  /// Something already finished. Granted its XP on the spot.
  done,
}

extension DumpKindInfo on DumpKind {
  String get label => switch (this) {
        DumpKind.task => 'TASK',
        DumpKind.habit => 'HABIT',
        DumpKind.wish => 'WISH',
        DumpKind.obligation => 'COST',
        DumpKind.done => 'DONE',
      };
}

/// One triaged line, ready to be filed. Editable before it is committed —
/// nothing is written on the user's behalf without them seeing it first.
class DumpItem {
  final String text;
  final DumpKind kind;
  final Cadence cadence;
  final int xp;

  /// For obligations and wishes: the money involved, when it could be read.
  final double? amountEuro;
  final ObligationCadence obligationCadence;

  /// How many times, for repeating habits ("dishes twice a week").
  final int targetCount;

  const DumpItem({
    required this.text,
    required this.kind,
    this.cadence = Cadence.once,
    this.xp = Economy.xpSmall,
    this.amountEuro,
    this.obligationCadence = ObligationCadence.monthly,
    this.targetCount = 1,
  });

  DumpItem copyWith({
    String? text,
    DumpKind? kind,
    Cadence? cadence,
    int? xp,
    double? amountEuro,
    ObligationCadence? obligationCadence,
    int? targetCount,
  }) =>
      DumpItem(
        text: text ?? this.text,
        kind: kind ?? this.kind,
        cadence: cadence ?? this.cadence,
        xp: xp ?? this.xp,
        amountEuro: amountEuro ?? this.amountEuro,
        obligationCadence: obligationCadence ?? this.obligationCadence,
        targetCount: targetCount ?? this.targetCount,
      );

  factory DumpItem.fromJson(Map<String, dynamic> json) {
    final kind = DumpKind.values.byName(json['kind'] as String? ?? 'task');
    return DumpItem(
      text: (json['text'] as String? ?? '').trim(),
      kind: kind,
      cadence: Cadence.values.byName(json['cadence'] as String? ?? 'once'),
      xp: (json['xp'] as num?)?.toInt() ?? Economy.xpSmall,
      amountEuro: (json['amount_eur'] as num?)?.toDouble(),
      obligationCadence: ObligationCadence.values
          .byName(json['obligation_cadence'] as String? ?? 'monthly'),
      targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Splits a braindump into typed items without a model.
///
/// This is the fallback when Gemini is unreachable, and it runs first in every
/// case so the user sees *something* instantly rather than a spinner. The
/// model's job is to improve on this, not to be required for it.
///
/// The heuristics are deliberately shallow. Getting a line slightly wrong is
/// cheap — every item is shown for confirmation and can be re-typed with one
/// tap — whereas losing the thought because parsing was too clever is not.
class BraindumpParser {
  const BraindumpParser();

  static final _money = RegExp(r'(?:€|eur\s?)\s?(\d+(?:[.,]\d{1,2})?)|(\d+(?:[.,]\d{1,2})?)\s?(?:€|eur\b)', caseSensitive: false);
  static final _perMonth = RegExp(r'\b(a|per|every|each)\s+month|\bmonthly\b', caseSensitive: false);
  static final _perWeek = RegExp(r'\b(a|per|every|each)\s+week|\bweekly\b', caseSensitive: false);
  static final _perDay = RegExp(r'\b(a|per|every|each)\s+day|\bdaily\b|\bevery morning\b|\bevery evening\b|\beach night\b', caseSensitive: false);
  static final _times = RegExp(r'\b(\d+)\s*(?:x|times)\b', caseSensitive: false);

  static const _wishWords = [
    'want', 'wish', 'buy', 'get ', 'would love', 'dreaming of', 'save for',
    'saving for', 'one day', 'someday', 'i need a', 'looking at',
  ];
  static const _doneWords = [
    'did ', 'done', 'finished', 'completed', 'sorted', 'already ', 'wrote ',
    'sent ', 'cleaned', 'paid ',
  ];
  static const _costWords = [
    'rent', 'mortgage', 'bill', 'bills', 'subscription', 'insurance',
    'groceries', 'food budget', 'transport', 'utilities', 'electricity',
    'internet', 'phone plan', 'gym membership',
  ];

  List<DumpItem> parse(String input) {
    final lines = input
        .split(RegExp(r'[\n;]|(?<=[.!?])\s+'))
        .map((l) => l.trim())
        .where((l) => l.length > 1)
        .toList();

    return [for (final line in lines) _classify(line)];
  }

  DumpItem _classify(String raw) {
    final line = raw.replaceAll(RegExp(r'^[-*•\d.)\s]+'), '').trim();
    final lower = line.toLowerCase();

    final money = _readMoney(lower);
    final repeatsDaily = _perDay.hasMatch(lower);
    final repeatsWeekly = _perWeek.hasMatch(lower);
    final repeatsMonthly = _perMonth.hasMatch(lower);
    final count = int.tryParse(_times.firstMatch(lower)?.group(1) ?? '') ?? 1;

    // A recurring cost with a figure attached is an obligation, not a wish —
    // "rent 850 a month" must never end up on the wishlist.
    final looksLikeCost = _costWords.any(lower.contains);
    if (money != null && (looksLikeCost || repeatsMonthly || repeatsWeekly)) {
      return DumpItem(
        text: _titleCase(line),
        kind: DumpKind.obligation,
        amountEuro: money,
        obligationCadence:
            repeatsWeekly ? ObligationCadence.weekly : ObligationCadence.monthly,
      );
    }

    if (_doneWords.any(lower.startsWith) ||
        _doneWords.any((w) => lower.contains(' $w'))) {
      return DumpItem(
        text: _titleCase(line),
        kind: DumpKind.done,
        xp: Economy.xpSmall,
      );
    }

    if (_wishWords.any(lower.contains)) {
      return DumpItem(
        text: _titleCase(line),
        kind: DumpKind.wish,
        amountEuro: money,
      );
    }

    if (repeatsDaily || repeatsWeekly || repeatsMonthly) {
      return DumpItem(
        text: _titleCase(line),
        kind: DumpKind.habit,
        cadence: repeatsDaily
            ? Cadence.daily
            : repeatsWeekly
                ? Cadence.weekly
                : Cadence.monthly,
        xp: Economy.xpTrivial,
        targetCount: count.clamp(1, 20),
      );
    }

    return DumpItem(
      text: _titleCase(line),
      kind: DumpKind.task,
      xp: Economy.xpSmall,
      targetCount: count.clamp(1, 20),
    );
  }

  double? _readMoney(String lower) {
    final m = _money.firstMatch(lower);
    if (m == null) return null;
    final raw = m.group(1) ?? m.group(2);
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  /// Capitalises the first letter and leaves the rest alone — the user's own
  /// phrasing is what makes a directive recognisable to them later.
  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
