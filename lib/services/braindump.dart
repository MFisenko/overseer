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

  // A bare number is money often enough that requiring a currency symbol
  // loses the most consequential line people write: "rent is 850 a month".
  static final _currencyMoney = RegExp(
      r'(?:€|eur\s?)\s?(\d[\d.,]*)|(\d[\d.,]*)\s?(?:€|eur\b)',
      caseSensitive: false);
  static final _bareNumber = RegExp(r'\b(\d{2,6}(?:[.,]\d{1,2})?)\b');

  static final _perMonth = RegExp(
      r'\b(a|per|every|each)\s+month|\bmonthly\b', caseSensitive: false);
  static final _perWeek = RegExp(
      r'\b(a|per|every|each)\s+week|\bweekly\b', caseSensitive: false);
  static final _perDay = RegExp(
      r'\b(a|per|every|each)\s+day|\bdaily\b|\bevery morning\b|'
      r'\bevery evening\b|\beach night\b|\bevery night\b',
      caseSensitive: false);
  static final _times = RegExp(r'\b(\d+)\s*(?:x|times)\b', caseSensitive: false);

  /// Things that are *wanted*. Checked after costs and chores, because "buy"
  /// appears in both "buy a synth" and "buy groceries".
  static const _wishWords = [
    'want', 'wish', 'would love', 'dreaming of', 'save for', 'saving for',
    'one day', 'someday', 'looking at', 'dream of',
  ];
  static const _doneWords = [
    'did ', 'done', 'finished', 'completed', 'sorted', 'already ', 'wrote ',
    'sent ', 'cleaned', 'paid ', 'submitted', 'delivered',
  ];

  /// Recurring costs of being alive.
  static const _costWords = [
    'rent', 'mortgage', 'bill', 'bills', 'subscription', 'insurance',
    'transport', 'utilities', 'electricity', 'internet', 'phone plan',
    'gym membership', 'council tax', 'childcare', 'loan', 'car payment',
  ];

  /// Chores that *sound* like purchases. Without these, "buy groceries" lands
  /// on the wishlist, which is both wrong and quietly insulting.
  static const _choreWords = [
    'groceries', 'shopping', 'milk', 'bread', 'food shop', 'washing',
    'laundry', 'dishes', 'bins', 'rubbish', 'tidy', 'clean', 'hoover',
    'vacuum', 'cook', 'dinner', 'lunch',
  ];

  List<DumpItem> parse(String input) {
    final lines = input
        .split(RegExp(r'[\n;]|(?<=[.!?])\s+'))
        .map((l) => l.trim())
        .where((l) => l.length > 1)
        .toList();

    return [for (final line in lines) _classify(line)];
  }

  /// Order matters more than cleverness here.
  ///
  /// Costs are tested before wishes because a misfiled cost is the expensive
  /// mistake: rent landing on the wishlist means the upkeep ledger silently
  /// under-reports what living actually costs, and the whole arrears mechanic
  /// stops meaning anything.
  DumpItem _classify(String raw) {
    final line = raw.replaceAll(RegExp(r'^[-*•\d.)\s]+'), '').trim();
    final lower = line.toLowerCase();

    final repeatsDaily = _perDay.hasMatch(lower);
    final repeatsWeekly = _perWeek.hasMatch(lower);
    final repeatsMonthly = _perMonth.hasMatch(lower);
    final repeats = repeatsDaily || repeatsWeekly || repeatsMonthly;
    final count = int.tryParse(_times.firstMatch(lower)?.group(1) ?? '') ?? 1;

    final isCost = _costWords.any(lower.contains);
    final isChore = _choreWords.any(lower.contains);

    // A bare figure only counts as money when the line is already about a cost
    // or a recurring amount — otherwise "gym 3 times a week" reads as €3.
    final money = _readMoney(lower, allowBare: isCost || (repeats && !isChore));

    // 1. A recurring cost, with or without a symbol on the number.
    if (isCost && (money != null || repeats)) {
      return DumpItem(
        text: _sentence(line),
        kind: DumpKind.obligation,
        amountEuro: money,
        obligationCadence:
            repeatsWeekly ? ObligationCadence.weekly : ObligationCadence.monthly,
      );
    }

    // 2. Something already finished. Checked early so "paid the rent" is a
    //    completed task rather than a new standing cost.
    if (_doneWords.any(lower.startsWith) ||
        _doneWords.any((w) => lower.contains(' $w'))) {
      return DumpItem(
          text: _sentence(line), kind: DumpKind.done, xp: Economy.xpSmall);
    }

    // 3. Housework is never a wish, whatever verb it is phrased with.
    if (isChore) {
      return DumpItem(
        text: _sentence(line),
        kind: repeats ? DumpKind.habit : DumpKind.task,
        cadence: _cadenceFrom(repeatsDaily, repeatsWeekly, repeatsMonthly),
        xp: repeats ? Economy.xpTrivial : Economy.xpSmall,
        targetCount: count.clamp(1, 20),
      );
    }

    // 4. Something wanted.
    if (_wishWords.any(lower.contains) ||
        RegExp(r'\b(buy|get)\s+(a|an|the|some|new)\b').hasMatch(lower)) {
      return DumpItem(
          text: _sentence(line), kind: DumpKind.wish, amountEuro: money);
    }

    // 5. Anything recurring is a habit.
    if (repeats) {
      return DumpItem(
        text: _sentence(line),
        kind: DumpKind.habit,
        cadence: _cadenceFrom(repeatsDaily, repeatsWeekly, repeatsMonthly),
        xp: Economy.xpTrivial,
        targetCount: count.clamp(1, 20),
      );
    }

    return DumpItem(
      text: _sentence(line),
      kind: DumpKind.task,
      xp: Economy.xpSmall,
      targetCount: count.clamp(1, 20),
    );
  }

  Cadence _cadenceFrom(bool daily, bool weekly, bool monthly) => daily
      ? Cadence.daily
      : weekly
          ? Cadence.weekly
          : monthly
              ? Cadence.monthly
              : Cadence.once;

  double? _readMoney(String lower, {required bool allowBare}) {
    final m = _currencyMoney.firstMatch(lower);
    final raw = m?.group(1) ?? m?.group(2);
    if (raw != null) return _num(raw);
    if (!allowBare) return null;
    return _num(_bareNumber.firstMatch(lower)?.group(1));
  }

  /// Handles both "1,250" and "1.250,50" loosely — a wrong-by-a-decimal figure
  /// the user can correct beats refusing the line.
  static double? _num(String? raw) {
    if (raw == null) return null;
    var s = raw;
    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll(',', '');
    } else {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s);
  }

  /// Capitalises the first letter and leaves the rest alone — the user's own
  /// phrasing is what makes a directive recognisable to them later.
  String _sentence(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
